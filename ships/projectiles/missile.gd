class_name Missile
extends Projectile

# The CIWS has started on it (heard, not yet seen)
signal engaged

const FIRE_SOUND := preload("res://audio/missile.wav")
const INTERCEPT_SOUND := preload("res://audio/ciws.wav")
const MAX_SPEED := 500.0
# CIWS opens fire this many seconds before the kill and keeps firing this
# long after it. It's heard a little before the tracers show (they're fired
# from the cruiser, out of sight) and for a little after, then fades out.
const FIRE_LEAD := 0.35
const FIRE_AFTER := 0.15
const SOUND_LEAD := 0.3
const SOUND_AFTER := 0.5
const SOUND_FADE := 0.4
# A missile released past no-man's-land (by an F-35) is killed this far past
# the release point, with the tracers showing for the last stretch before it
const RELEASE_KILL := 180.0
const RELEASE_TRACERS := 60.0
const TRACER_SPEED := 700.0
# The CIWS recording is much louder than the other effects
const CIWS_VOLUME_DB := -8.0

var rotate_sound: AudioStream = preload("res://audio/missile_rotate.wav")
var enroute := false
var exhaust: CPUParticles2D
# Set by the firing ship: shot down by the defender's CIWS on the way in
var intercepted := false
# Set by the firing ship: where the cruiser shooting it down is, and whether to
# show its fire all the way (to the defender, watching live or in the replay)
var ciws_at := Vector2.INF
var ciws_shown := false
var launched_from: Vector2
var kill_at: Vector2
var gun_at: Vector2
var tracers: CPUParticles2D
var ciws_sound: AudioStreamPlayer2D


func _process(delta: float) -> void:
	super(delta)
	if enroute and speed < MAX_SPEED:
		speed += 500 * delta
	if intercepted and moving:
		var to_go := launched_from.distance_to(kill_at) - launched_from.distance_to(position)
		# Early enough for the first tracers to reach the missile, too
		var lead := FIRE_LEAD + gun_at.distance_to(kill_at) / TRACER_SPEED
		if ciws_sound == null and to_go < maxf(speed, 1.0) * (lead + SOUND_LEAD):
			ciws_sound = Sfx.play(get_parent(), INTERCEPT_SOUND)
			ciws_sound.position = gun_at
			ciws_sound.volume_db = CIWS_VOLUME_DB
			engaged.emit()
		if tracers == null and to_go < maxf(speed, 1.0) * lead:
			_open_fire()
		if to_go <= 0:
			_shoot_down()


# Turns toward the target (unless instafire) before accelerating
func launch(
	origin: Vector2, target: Vector2i, start_degrees: float = 0.0, instafire: bool = false
) -> void:
	super(origin, target)
	if intercepted:
		_plan_shootdown()
	global_rotation_degrees = start_degrees
	speed = 0.0
	exhaust = CPUParticles2D.new()
	exhaust.local_coords = true
	exhaust.gravity = Vector2.ZERO
	exhaust.initial_velocity_min = 15.0
	exhaust.initial_velocity_max = 15.0
	exhaust.damping_min = 10.0
	exhaust.damping_max = 10.0
	exhaust.color = Color.DARK_SALMON
	exhaust.scale_amount_min = 0.005
	exhaust.scale_amount_max = 0.005
	exhaust.texture = FIRE_TEXTURE
	exhaust.amount = 100
	exhaust.lifetime = 0.2
	exhaust.position.x += 1.5
	add_child(exhaust)

	var sound := Sfx.new_player()
	add_child(sound)
	var heading := (position - dest).angle()
	if instafire:
		global_rotation = heading
		speed = MAX_SPEED
	else:
		sound.stream = rotate_sound
		sound.play()
		await get_tree().create_timer(0.5, false).timeout
		var tween := create_tween()
		(
			tween
			. tween_property(
				self,
				"global_rotation",
				global_rotation + wrapf(heading - global_rotation, -PI, PI),
				0.5
			)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
		await tween.finished
	sound.stream = FIRE_SOUND
	sound.play()
	enroute = true
	await sound.finished
	sound.queue_free()


# Where the missile dies: over the middle of no-man's-land, or just after
# release when already past it. The tracers come from the cruiser's bearing,
# but only show from where they cross into no-man's-land (or for the last
# stretch, past it), unless the defender is watching.
func _plan_shootdown() -> void:
	launched_from = position
	var defender := grid.side_of(dest_hex)
	var nml_x := grid.get_hex_center(Vector2i(Grid.NO_MANS_LAND, 0)).x
	var cruiser: Vector2 = get_parent().to_local(ciws_at)
	if grid.side_of(grid.get_hex_from_coords(position)) != 1 - defender:
		var run := minf(RELEASE_KILL, position.distance_to(dest) / 2)
		kill_at = position + position.direction_to(dest) * run
		gun_at = kill_at.move_toward(cruiser, RELEASE_TRACERS)
	else:
		kill_at = position.lerp(dest, (nml_x - position.x) / (dest.x - position.x))
		var edge := Vector2i(Grid.NO_MANS_LAND + (1 if defender == 1 else -1), 0)
		var edge_x := (grid.get_hex_center(edge).x + nml_x) / 2
		gun_at = kill_at.lerp(cruiser, (edge_x - kill_at.x) / (cruiser.x - kill_at.x))
	if ciws_shown:
		gun_at = cruiser


func _open_fire() -> void:
	tracers = CPUParticles2D.new()
	tracers.position = gun_at
	tracers.direction = gun_at.direction_to(kill_at) if gun_at != kill_at else Vector2.LEFT
	tracers.spread = 3.0
	tracers.gravity = Vector2.ZERO
	tracers.initial_velocity_min = TRACER_SPEED
	tracers.initial_velocity_max = TRACER_SPEED
	# Long enough to fly on past the missile
	tracers.lifetime = (gun_at.distance_to(kill_at) + 80) / TRACER_SPEED
	tracers.amount = 24
	tracers.color = Color(1.0, 0.85, 0.4)
	tracers.scale_amount_min = 2.0
	tracers.scale_amount_max = 2.0
	add_sibling(tracers)


func _shoot_down() -> void:
	moving = false
	enroute = false
	position = kill_at
	done.emit()
	texture = null
	exhaust.queue_free()
	_cease_fire(tracers, ciws_sound)
	await boom(kill_at, true)
	queue_free()


# A short burst past the kill, then the sound fades. Not tied to the missile,
# which is freed first. A skipped replay may free either at any point, and
# the sound frees itself if it runs out.
static func _cease_fire(gun: CPUParticles2D, sound: AudioStreamPlayer2D) -> void:
	var tree := gun.get_tree()
	await tree.create_timer(FIRE_AFTER, false).timeout
	if is_instance_valid(gun):
		gun.emitting = false
		# Let the last tracers fly out
		var out := gun.create_tween()
		out.tween_interval(gun.lifetime)
		out.tween_callback(gun.queue_free)
	await tree.create_timer(SOUND_AFTER - FIRE_AFTER, false).timeout
	if is_instance_valid(sound):
		var fade := sound.create_tween()
		fade.tween_property(sound, "volume_db", -40.0, SOUND_FADE)
		fade.tween_callback(sound.queue_free)


func explode(pos: Vector2) -> void:
	exhaust.queue_free()
	await super(pos)
