class_name Explosion
# The board's explosions, splashes and smoke, shared by projectiles and ships.
# Each adds its particles to `parent` at `pos` (in parent's space) and frees
# them once they've played. All smoke drifts with the one WIND.

const FIRE_TEXTURE := preload("res://ships/sprites/projectiles/fire.png")
const SMOKE_TEXTURE := preload("res://ships/sprites/projectiles/smoke.png")
# Which way smoke drifts across the board, and how fast (pixels a second)
const WIND := Vector2(-14, -10)


# A shell or missile striking home: flash, fireball, sparks, then smoke.
# `size` scales it (1 for a hit, more for a ship going up). Returns how long
# it lasts.
static func blast(parent: Node, pos: Vector2, size: float = 1.0) -> float:
	var flash := _burst(pos, FIRE_TEXTURE, 6, 0.3)
	flash.scale_amount_min = 0.1 * size
	flash.scale_amount_max = 0.13 * size
	flash.color_ramp = _ramp([Color(1, 1, 0.9, 1), Color(1, 0.85, 0.4, 0)])

	var fire := _burst(pos, FIRE_TEXTURE, int(40 * size), 1.0)
	fire.initial_velocity_min = 16.0 * size
	fire.initial_velocity_max = 48.0 * size
	fire.damping_min = 30.0
	fire.damping_max = 50.0
	fire.scale_amount_min = 0.045 * size
	fire.scale_amount_max = 0.07 * size
	fire.scale_amount_curve = _curve(1.0, 0.5)
	fire.color_ramp = _ramp(
		[
			Color(1, 0.95, 0.7, 1),
			Color(1, 0.75, 0.25, 1),
			Color(1, 0.45, 0.1, 0.9),
			Color(0.6, 0.1, 0.05, 0.5),
			Color(0.2, 0.05, 0.05, 0)
		]
	)

	var sparks := _burst(pos, FIRE_TEXTURE, int(18 * size), 0.6)
	sparks.initial_velocity_min = 60.0 * size
	sparks.initial_velocity_max = 110.0 * size
	sparks.damping_min = 80.0
	sparks.damping_max = 120.0
	sparks.scale_amount_min = 0.006
	sparks.scale_amount_max = 0.01
	sparks.color_ramp = _ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.4, 0.1, 0)])

	var smoke := _burst(pos, SMOKE_TEXTURE, int(24 * size), 2.2)
	smoke.explosiveness = 0.7
	smoke.initial_velocity_min = 8.0 * size
	smoke.initial_velocity_max = 24.0 * size
	smoke.damping_min = 6.0
	smoke.damping_max = 10.0
	smoke.gravity = WIND
	smoke.scale_amount_min = 0.03 * size
	smoke.scale_amount_max = 0.05 * size
	smoke.scale_amount_curve = _curve(0.6, 1.8)
	smoke.color_ramp = _ramp(
		[Color(0.2, 0.18, 0.17, 0), Color(0.15, 0.14, 0.13, 0.75), Color(0.3, 0.3, 0.3, 0)]
	)
	_play(parent, [flash, fire, sparks, smoke])
	return smoke.lifetime


# A Nuclear Strike: a shockwave racing out to `radius`, a huge fireball, and
# a mushroom cloud (seen from above: a dark billowing cap, with a ring of
# smoke rolling out around it) that lingers and drifts off. Returns how long
# until the worst is over; the cloud outlasts it.
static func nuke(parent: Node, pos: Vector2, radius: float) -> float:
	var wave := Shockwave.new()
	wave.position = pos
	parent.add_child(wave)
	var out := wave.create_tween().set_parallel()
	out.tween_property(wave, "radius", radius, 0.7).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	out.tween_property(wave, "width", 2.0, 0.7)
	out.tween_property(wave, "glow", 0.0, 0.9).from(0.45)
	out.tween_property(wave, "modulate:a", 0.0, 0.4).set_delay(0.5)
	out.chain().tween_callback(wave.queue_free)

	blast(parent, pos, 3.0)

	var cap := _burst(pos, SMOKE_TEXTURE, 60, 5.5)
	cap.explosiveness = 0.6
	cap.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	cap.emission_sphere_radius = radius * 0.15
	cap.initial_velocity_min = 10.0
	cap.initial_velocity_max = 30.0
	cap.damping_min = 4.0
	cap.damping_max = 8.0
	cap.gravity = WIND
	cap.scale_amount_min = 0.1
	cap.scale_amount_max = 0.16
	cap.scale_amount_curve = _curve(0.5, 1.6)
	cap.angular_velocity_min = -20.0
	cap.angular_velocity_max = 20.0
	cap.color_ramp = _ramp(
		[
			Color(0.35, 0.22, 0.12, 0),
			Color(0.2, 0.15, 0.12, 0.85),
			Color(0.25, 0.24, 0.24, 0.6),
			Color(0.4, 0.4, 0.4, 0)
		]
	)

	var skirt := _burst(pos, SMOKE_TEXTURE, 70, 3.5)
	skirt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	skirt.emission_ring_radius = radius * 0.3
	skirt.emission_ring_inner_radius = radius * 0.25
	skirt.initial_velocity_min = radius * 0.5
	skirt.initial_velocity_max = radius * 0.7
	skirt.damping_min = radius * 0.2
	skirt.damping_max = radius * 0.25
	skirt.gravity = WIND
	skirt.scale_amount_min = 0.05
	skirt.scale_amount_max = 0.08
	skirt.scale_amount_curve = _curve(0.6, 1.4)
	skirt.color_ramp = _ramp(
		[Color(0.5, 0.45, 0.4, 0), Color(0.45, 0.42, 0.4, 0.55), Color(0.5, 0.5, 0.5, 0)]
	)

	var embers := _burst(pos, FIRE_TEXTURE, 30, 2.5)
	embers.explosiveness = 0.3
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = radius * 0.12
	embers.initial_velocity_min = 2.0
	embers.initial_velocity_max = 8.0
	embers.scale_amount_min = 0.03
	embers.scale_amount_max = 0.05
	embers.color_ramp = _ramp(
		[Color(1, 0.7, 0.3, 0.9), Color(0.9, 0.3, 0.1, 0.6), Color(0.4, 0.1, 0.05, 0)]
	)

	# The skirt rolls out under the cap; the embers glow through it
	_play(parent, [skirt, cap, embers])
	return 1.5


# A ring of light racing outward, over a brief glow (for nuke())
class Shockwave:
	extends Node2D

	var radius := 0.0:
		set(value):
			radius = value
			queue_redraw()
	var width := 7.0
	# The flash's light lingering inside the ring (its alpha)
	var glow := 0.0

	func _draw() -> void:
		if glow > 0.0:
			draw_circle(Vector2.ZERO, radius, Color(1, 0.8, 0.5, glow * 0.5))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 96, Color(1, 0.97, 0.9, 0.85), width, true)
		draw_arc(
			Vector2.ZERO, radius * 0.93, 0, TAU, 96, Color(1, 0.8, 0.5, 0.35), width * 2.0, true
		)


# A submarine going down between `bow` and `stern`: a boil of white water,
# then air breaking the surface along the hull, less and less. Returns how
# long it lasts.
static func bubbles(parent: Node, bow: Vector2, stern: Vector2) -> float:
	var rising := Bubbles.new()
	rising.bow = bow
	rising.stern = stern
	parent.add_child(rising)
	return Bubbles.LASTS


# A miss at sea: spray thrown out and a ring of foam spreading. Returns how
# long it lasts.
static func splash(parent: Node, pos: Vector2) -> float:
	var spray := _burst(pos, FIRE_TEXTURE, 30, 0.8)
	spray.initial_velocity_min = 20.0
	spray.initial_velocity_max = 60.0
	spray.damping_min = 50.0
	spray.damping_max = 70.0
	spray.scale_amount_min = 0.02
	spray.scale_amount_max = 0.04
	spray.color_ramp = _ramp([Color(1, 1, 1, 0.9), Color(0.85, 0.95, 1, 0)])

	# Plain square particles, which read as a crisp line of foam
	var ring := _burst(pos, null, 160, 1.2)
	ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	ring.emission_ring_radius = 4.0
	ring.emission_ring_inner_radius = 3.0
	ring.initial_velocity_min = 22.0
	ring.initial_velocity_max = 26.0
	ring.damping_min = 12.0
	ring.damping_max = 14.0
	ring.scale_amount_min = 2.5
	ring.scale_amount_max = 3.0
	ring.color_ramp = _ramp([Color(0.85, 1, 1, 0.7), Color(0.85, 1, 1, 0)])
	_play(parent, [spray, ring])
	return ring.lifetime


# Smoke and a little fire from a hit that's still burning, for a ship to
# carry. Its smoke stays where it rose, so it trails a ship that moves.
static func burning(size: int) -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.texture = SMOKE_TEXTURE
	smoke.local_coords = false
	smoke.amount = 10 + size * 3
	smoke.lifetime = 2.6
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 3.0
	smoke.spread = 180.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 6.0
	smoke.gravity = WIND
	smoke.scale_amount_min = 0.025
	smoke.scale_amount_max = 0.035
	smoke.scale_amount_curve = _curve(0.5, 1.9)
	smoke.color_ramp = _ramp(
		[Color(0.1, 0.09, 0.08, 0), Color(0.12, 0.11, 0.1, 0.7), Color(0.35, 0.35, 0.35, 0)]
	)

	var fire := CPUParticles2D.new()
	fire.texture = FIRE_TEXTURE
	fire.amount = 10
	fire.lifetime = 0.6
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 2.5
	fire.spread = 180.0
	fire.initial_velocity_min = 2.0
	fire.initial_velocity_max = 5.0
	fire.gravity = Vector2.ZERO
	fire.scale_amount_min = 0.025
	fire.scale_amount_max = 0.04
	fire.color_ramp = _ramp([Color(1, 0.85, 0.4, 0.9), Color(1, 0.35, 0.1, 0)])
	smoke.add_child(fire)
	return smoke


# A one-shot burst in every direction, added by _play() once set up
static func _burst(
	pos: Vector2, texture: Texture2D, amount: int, lifetime: float
) -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.texture = texture
	burst.amount = maxi(amount, 1)
	burst.lifetime = lifetime
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.position = pos
	return burst


# Adds the bursts to `parent`, each freed once it's played (by a tween of its
# own, so a replay skipped early can free it first)
static func _play(parent: Node, bursts: Array[CPUParticles2D]) -> void:
	for burst in bursts:
		parent.add_child(burst)
		burst.create_tween().tween_callback(burst.queue_free).set_delay(burst.lifetime + 0.1)


static func _ramp(colors: Array[Color]) -> Gradient:
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	ramp.offsets = offsets
	ramp.colors = PackedColorArray(colors)
	return ramp


static func _curve(start: float, end: float) -> Curve:
	var curve := Curve.new()
	curve.max_value = maxf(start, end)
	curve.add_point(Vector2(0, start))
	curve.add_point(Vector2(1, end))
	return curve


# Rings of air breaking the surface along a sunken hull (for bubbles()), in
# flat foam like the sea's
class Bubbles:
	extends Node2D

	const LASTS := 4.0
	# How long one ring takes to spread and go
	const POP := 0.7
	const FOAM := Color(0.85, 0.92, 0.97)

	var bow: Vector2
	var stern: Vector2
	var _age := 0.0
	var _next := 0.0
	# [where, born, how wide it spreads]
	var _rings: Array[Array] = []
	# The boil: patches of white water along the hull, [where, how big]
	var _boil: Array[Array] = []

	func _ready() -> void:
		for i in 5:
			var at := bow.lerp(stern, (i + randf()) / 5) + Vector2(randf_range(-3, 3), 0)
			_boil.append([at, randf_range(4.0, 8.0)])

	func _process(delta: float) -> void:
		_age += delta
		# Thick at first, thinning out (visual randomness: the global generator)
		while _next <= _age and _age < LASTS - POP:
			var at := bow.lerp(stern, randf()) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			_rings.append([at, _next, randf_range(3.0, 7.0)])
			_next += 0.03 + 0.25 * _age / LASTS
		_rings = _rings.filter(func(ring: Array) -> bool: return _age - float(ring[1]) < POP)
		if _age >= LASTS:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# The boil where it went down, spreading and settling in steps
		var boil := 1.0 - _age / (LASTS * 0.5)
		if boil > 0.0:
			var color := Color(FOAM, 0.3 * ceilf(boil * 3.0) / 3.0)
			for patch in _boil:
				draw_circle(
					patch[0], float(patch[1]) + 5.0 * (1.0 - boil), color, true, -1.0, false
				)
		for ring in _rings:
			var t := (_age - float(ring[1])) / POP
			var color := Color(FOAM, 0.9 if t < 0.5 else 0.5)
			draw_arc(ring[0], 1.0 + float(ring[2]) * t, 0, TAU, 12, color, 1.5)
