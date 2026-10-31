class_name Missile
extends Projectile

const FIRE_SOUND := preload("res://audio/missile.wav")
const INTERCEPT_SOUND := preload("res://audio/ciws.wav")
const MAX_SPEED := 500.0
# CIWS opens fire this many seconds before the kill and keeps firing this
# long after it, then the sound fades out. A missile released on the
# defender's side (by an F-35) is killed this far past the release point.
const FIRE_LEAD := 0.35
const FIRE_AFTER := 0.15
const SOUND_FADE := 0.25
const RELEASE_KILL := 60.0
const TRACER_SPEED := 700.0

var rotate_sound: AudioStream = preload("res://audio/missile_rotate.wav")
var enroute := false
var exhaust: CPUParticles2D
# Set by the firing ship: shot down by the defender's CIWS on the way in
var intercepted := false
# Set by the firing ship: where the tracers come from, if not no-man's-land
var ciws_at := Vector2.INF
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

	var sound := AudioStreamPlayer2D.new()
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


# Where the missile dies: over the middle of no-man's-land, so the kill point
# says nothing about where the cruiser is, or just after release when already
# past it
func _plan_shootdown() -> void:
	launched_from = position
	var defender := grid.side_of(dest_hex)
	var nml_x := grid.get_hex_center(Vector2i(Grid.NO_MANS_LAND, 0)).x
	if grid.side_of(grid.get_hex_from_coords(position)) == defender:
		kill_at = position + position.direction_to(dest) * RELEASE_KILL
	else:
		kill_at = position.lerp(dest, (nml_x - position.x) / (dest.x - position.x))
	# The defender's edge of no-man's-land, level with the kill point, or the
	# cruiser itself when the defender is watching
	var edge := Vector2i(Grid.NO_MANS_LAND + (1 if defender == 1 else -1), 0)
	gun_at = Vector2((grid.get_hex_center(edge).x + nml_x) / 2, kill_at.y)
	if ciws_at.is_finite():
		gun_at = get_parent().to_local(ciws_at)


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
	ciws_sound = Sfx.play(tracers, INTERCEPT_SOUND)


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
# which is freed first. A skipped replay may free the tracers at any point.
static func _cease_fire(gun: CPUParticles2D, sound: AudioStreamPlayer2D) -> void:
	await gun.get_tree().create_timer(FIRE_AFTER, false).timeout
	if not is_instance_valid(gun):
		return
	gun.emitting = false
	var fade := gun.create_tween()
	fade.tween_property(sound, "volume_db", -40.0, SOUND_FADE)
	# Then let the last tracers fly out
	fade.tween_interval(gun.lifetime)
	fade.tween_callback(gun.queue_free)


func explode(pos: Vector2) -> void:
	exhaust.queue_free()
	await super(pos)
