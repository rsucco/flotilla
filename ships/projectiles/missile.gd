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
# Seen from above, height is drawn as a lift up the screen, a little bigger
# (this much per px of it, as if nearer), over a shadow on the water. It
# climbs this high off the deck before pitching over onto its arc.
const CLIMB := 12.0
# How long it takes to rise out of its silo, standing on end, before it
# pitches over, and how much of its length shows from above while it stands
const RISE := 0.6
const UPRIGHT := 0.25
const GROW := 1.0 / 200.0
const SHADOW := Color(0, 0, 0, 0.3)

var rotate_sound: AudioStream = preload("res://audio/missile_rotate.wav")
# How high the arc rises, for each px it flies, and at most (px)
var apex_ratio := 0.1
var apex_most := 60.0
# How high it is now (px)
var height := 0.0
# How upright it is: 1 standing on end, 0 level
var pitch := 0.0
var shadow: Sprite2D
var trail: CPUParticles2D
var enroute := false
var exhaust: CPUParticles2D
# Set by the firing ship: shot down by the defender's CIWS on the way in
var intercepted := false
# Set by the firing ship: where the cruiser shooting it down is, and whether to
# show its fire all the way (to the defender, watching live or in the replay)
var ciws_at := Vector2.INF
var ciws_shown := false
# Set by the cruiser shooting it down, when it's seen doing it: the tip of its
# CIWS barrel, which the tracers come from as it turns
var muzzle: Node2D
var launched_from: Vector2
# Where it's shot down, over the ground and up in the air, where it's seen
var kill_at: Vector2
var kill_seen: Vector2
var gun_at: Vector2
var tracers: CPUParticles2D
var ciws_sound: AudioStreamPlayer2D
# How high it starts out and the arc's top rises (px)
var _start_height := 0.0
var _apex := 0.0
# How far it flies over the ground until it's arrived (px)
var _flight := 1.0
var _scale: Vector2
var _offset: Vector2


func _process(delta: float) -> void:
	super(delta)
	if enroute and speed < MAX_SPEED:
		speed += 500 * delta
	# Until it's arrived or been shot down (the exhaust and shadow are freed a
	# frame after the texture's cleared)
	if texture != null and is_instance_valid(exhaust) and is_instance_valid(shadow):
		_fly()
	if intercepted and moving:
		_follow_muzzle()
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


# Climbs off the deck and pitches over toward the target (unless instafire,
# already in the air) before accelerating along its arc
func launch(
	origin: Vector2, target: Vector2i, start_degrees: float = 0.0, instafire: bool = false
) -> void:
	super(origin, target)
	launched_from = position
	# It arrives on entering the target's hex
	_flight = maxf(position.distance_to(dest) - grid.hex_size * 0.4, 1.0)
	_apex = minf(_flight * apex_ratio, apex_most)
	_start_height = 0.0 if instafire else CLIMB
	_scale = scale
	_offset = offset
	if intercepted:
		_plan_shootdown()
	global_rotation_degrees = start_degrees
	speed = 0.0
	shadow = Sprite2D.new()
	shadow.texture = texture
	shadow.offset = offset
	shadow.modulate = SHADOW
	shadow.show_behind_parent = true
	add_child(shadow)
	trail = CPUParticles2D.new()
	trail.texture = SMOKE_TEXTURE
	trail.emitting = false
	trail.amount = 160
	trail.lifetime = 1.4
	trail.gravity = Explosion.WIND
	trail.spread = 180.0
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 4.0
	trail.scale_amount_min = 0.024
	trail.scale_amount_max = 0.032
	trail.scale_amount_curve = Explosion.grow(0.6, 1.6)
	trail.color_ramp = Explosion.fade(Color(0.88, 0.88, 0.86, 0.6))
	add_child(trail)
	done.connect(_drop_trail)
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
	# Along the arc as it starts out (the sprite points left)
	var heading := (-_course(0.0)).angle()
	if instafire:
		global_rotation = heading
		speed = MAX_SPEED
	else:
		# Straight up out of its silo in a puff of smoke, standing on end
		pitch = 1.0
		sound.stream = rotate_sound
		sound.play()
		Explosion.puff(get_parent(), position)
		var rise := create_tween()
		rise.tween_property(self, "height", CLIMB, RISE).set_ease(Tween.EASE_OUT).set_trans(
			Tween.TRANS_QUAD
		)
		await rise.finished
		# Then over onto its heading, coming to its full length as it levels
		var over := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		over.set_ease(Tween.EASE_IN_OUT)
		over.tween_property(
			self,
			"global_rotation",
			global_rotation + wrapf(heading - global_rotation, -PI, PI),
			0.5
		)
		over.tween_property(self, "pitch", 0.0, 0.5)
		await over.finished
	sound.stream = FIRE_SOUND
	sound.play()
	enroute = true
	trail.emitting = true
	await sound.finished
	sound.queue_free()


# Where the missile dies: over the middle of no-man's-land, or just after
# release when already past it. The tracers come from the cruiser's bearing,
# but only show from where they cross into no-man's-land (or for the last
# stretch, past it), unless the defender is watching.
func _plan_shootdown() -> void:
	var defender := grid.side_of(dest_hex)
	var nml_x := grid.get_hex_center(Vector2i(Grid.NO_MANS_LAND, 0)).x
	var cruiser: Vector2 = get_parent().to_local(ciws_at)
	if grid.side_of(grid.get_hex_from_coords(position)) != 1 - defender:
		var run := minf(RELEASE_KILL, position.distance_to(dest) / 2)
		kill_at = position + position.direction_to(dest) * run
		kill_seen = _lifted(kill_at)
		gun_at = kill_seen.move_toward(cruiser, RELEASE_TRACERS)
	else:
		kill_at = position.lerp(dest, (nml_x - position.x) / (dest.x - position.x))
		kill_seen = _lifted(kill_at)
		var edge := Vector2i(Grid.NO_MANS_LAND + (1 if defender == 1 else -1), 0)
		var edge_x := (grid.get_hex_center(edge).x + nml_x) / 2
		gun_at = kill_seen.lerp(cruiser, (edge_x - kill_seen.x) / (cruiser.x - kill_seen.x))
	if ciws_shown:
		gun_at = cruiser


# Fires from the barrel, along it, while the cruiser is shown and still there
func _follow_muzzle() -> void:
	if not ciws_shown or not is_instance_valid(muzzle):
		return
	gun_at = get_parent().to_local(muzzle.global_position)
	if tracers != null:
		tracers.position = gun_at
		# The mount's sprite points up (-y)
		tracers.direction = Vector2.UP.rotated(muzzle.global_rotation)


func _open_fire() -> void:
	tracers = CPUParticles2D.new()
	tracers.position = gun_at
	tracers.direction = gun_at.direction_to(kill_seen) if gun_at != kill_seen else Vector2.LEFT
	tracers.spread = 3.0
	tracers.gravity = Vector2.ZERO
	tracers.initial_velocity_min = TRACER_SPEED
	tracers.initial_velocity_max = TRACER_SPEED
	# Long enough to fly on past the missile
	tracers.lifetime = (gun_at.distance_to(kill_seen) + 80) / TRACER_SPEED
	tracers.amount = 24
	tracers.color = Color(1.0, 0.85, 0.4)
	tracers.scale_amount_min = 2.0
	tracers.scale_amount_max = 2.0
	add_sibling(tracers)
	_follow_muzzle()


func _shoot_down() -> void:
	moving = false
	enroute = false
	position = kill_at
	done.emit()
	texture = null
	exhaust.queue_free()
	_cease_fire(tracers, ciws_sound)
	# Up in the air, where it's seen
	await boom(kill_seen, true)
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


# Where it's seen, up in the air (globally)
func seen_at() -> Vector2:
	return global_position + Vector2.UP * height


# How high it is `along` the way (0 to 1): down from where it started climbing
# to, plus the arc
func _height_at(along: float) -> float:
	return _start_height * (1.0 - along) + 4.0 * _apex * along * (1.0 - along)


# Where a point on its ground track is seen, at the height it'll be there
func _lifted(at: Vector2) -> Vector2:
	var along := clampf(launched_from.distance_to(at) / _flight, 0.0, 1.0)
	return at + Vector2.UP * _height_at(along)


# The way it's going on screen `along` the way: over the ground toward the
# target, and up or down the screen as it climbs and dives
func _course(along: float) -> Vector2:
	var climb := (-_start_height + 4.0 * _apex * (1.0 - 2.0 * along)) / _flight
	return launched_from.direction_to(dest) + Vector2.UP * climb


# Follows its arc, and draws itself at its height over its shadow
func _fly() -> void:
	if enroute and moving:
		var along := clampf(launched_from.distance_to(position) / _flight, 0.0, 1.0)
		height = _height_at(along)
		global_rotation = (-_course(along)).angle()
	var near := 1.0 + height * GROW
	# Standing on end, it's seen nose-on from above: shortened along its length
	# (the sprite's x)
	scale = _scale * near * Vector2(lerpf(1.0, UPRIGHT, pitch), 1.0)
	var lift := (Vector2.UP * height).rotated(-global_rotation) / scale
	offset = _offset + lift
	exhaust.position = Vector2(1.5, 0) + lift
	trail.position = exhaust.position
	shadow.scale = Vector2.ONE / near


# Arrived or shot down: its smoke stays in the air to clear, and its shadow
# goes with it
func _drop_trail() -> void:
	shadow.queue_free()
	trail.emitting = false
	trail.reparent(get_parent())
	trail.create_tween().tween_callback(trail.queue_free).set_delay(trail.lifetime)
