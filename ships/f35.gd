class_name F35
extends Node2D
# Flies strikes and recon passes from its carrier. Paths are planned in the
# carrier's frame (bow is up, the jet's parking spot is the origin) as a chain
# of positions and headings joined by fixed-radius turns: a catapult launch
# off the bow, onto the attack or recon heading, then the most direct way
# home onto a short final astern, a trap at the stern and a taxi back to the
# spot.

signal done

const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const JET_SOUND := preload("res://audio/f35.ogg")
const RECON_SOUND := preload("res://audio/recon.wav")
const BOW := Vector2.UP
# Where the deck ends, ahead of and behind the parking spot
const DECK_AHEAD := 155.0
const DECK_ASTERN := 34.0
# The catapult stroke ends at the bow; then a straight climb-out
const LAUNCH_RUN := 200.0
# Where the final approach starts, straight in from astern
const FINAL := Vector2(0, 150)
# Touchdown just inside the stern, then the wire stops the jet within this
const TRAP_RUN := 22.0
# Strike missiles are released this far short of the target
const STANDOFF := 170.0
# Every turn's radius, and the spacing of the points along the path
const TURN_RADIUS := 80.0
const STEP := 6.0
# Speeds in pixels per second: leaving the catapult, on final approach, and
# taxiing on deck
const LAUNCH_SPEED := 400.0
const APPROACH_SPEED := 190.0
const TAXI_SPEED := 40.0
# Climbing out to cruise, and the glide slope down to the deck
const CLIMB_RUN := 160.0
const GLIDE_RUN := 220.0
# Airborne, the jet is drawn bigger with its shadow cast this far away
const ALTITUDE_SCALE := 1.35
const SHADOW_OFFSET := Vector2(10, 14)

var speed := 0.0
var flying := false
var bombing := false
var reconning := false
var target_hex: Vector2i
# Path offsets where the missile is released, or the recon pass starts
var trigger_at := 0.0
# Path offsets of touchdown and of the wire bringing the jet to a stop
var touchdown_at := 0.0
var stopped_at := 0.0
var audio_player: AudioStreamPlayer2D
var recon_audio_player: AudioStreamPlayer2D
var shadow: Sprite2D
# Set by the ship that carries it
var ship: Ship

@onready var path: Path2D = $Path2D
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var sprite: Sprite2D = $Path2D/PathFollow2D/Sprite2D


func _ready() -> void:
	audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = JET_SOUND
	add_child(audio_player)
	recon_audio_player = AudioStreamPlayer2D.new()
	recon_audio_player.stream = RECON_SOUND
	add_child(recon_audio_player)
	shadow = Sprite2D.new()
	shadow.texture = sprite.texture
	shadow.modulate = Color(0, 0, 0, 0.35)
	path_follow.add_child(shadow)
	path_follow.move_child(shadow, 0)
	_show_altitude(0.0)


func _process(delta: float) -> void:
	if not flying:
		return
	var length := path.curve.get_baked_length()
	path_follow.progress += _pace(path_follow.progress) * delta
	_show_altitude(_altitude(path_follow.progress))
	# Start the camera sounds just before the recon pass
	if reconning and path_follow.progress > trigger_at - 100 and not recon_audio_player.playing:
		recon_audio_player.play()
	if path_follow.progress >= trigger_at:
		if bombing:
			bombing = false
			var missile: Missile = MISSILE_SCENE.instantiate()
			missile.intercepted = ship.intercepted
			missile.ciws_at = ship.ciws_at
			ship.spawn(missile)
			missile.launch(path_follow.global_position, target_hex, 0.0, true)
			# Not awaited here: that would suspend _process with the jet's state
			missile.done.connect(done.emit)
		elif reconning:
			reconning = false
			done.emit()
	if path_follow.progress >= length:
		flying = false
		audio_player.stop()
		path_follow.progress = 0
		_show_altitude(0.0)


# Returns once the missile has hit. A new sortie restarts from the deck even
# if the last one is still flying home, so impatient players can skip ahead.
func bomb(target: Vector2i) -> void:
	target_hex = target
	plan_strike(target)
	speed = 420.0
	_take_off()
	bombing = true
	await done


# Flies the length of the target's row; returns once the pass has started
func recon(target: Vector2i) -> void:
	plan_recon(target)
	speed = 550.0
	_take_off()
	reconning = true
	await done


# Launch, turn onto the target, release the missile from a standoff, then
# come home
func plan_strike(target: Vector2i) -> void:
	var launched := BOW * LAUNCH_RUN
	var aim := _local(target)
	# The heading we'd have after turning toward the target off the catapult
	var way := 1.0 if BOW.angle_to(launched.direction_to(aim)) >= 0 else -1.0
	var center := launched + BOW.rotated(way * PI / 2) * TURN_RADIUS
	var heading := launched.direction_to(aim)
	var reach := center.distance_to(aim)
	if reach > TURN_RADIUS:
		var lean := atan2(TURN_RADIUS, sqrt(reach * reach - TURN_RADIUS ** 2))
		heading = center.direction_to(aim).rotated(way * lean)
	var release := aim - heading * minf(STANDOFF, launched.distance_to(aim) / 2)
	var curve := _launch()
	_connect(curve, launched, BOW, release, heading)
	trigger_at = curve.get_baked_length()
	_land(curve, release, heading)


# Launch, line up with the target's row at the near edge of the opponent's
# side, fly its length, then come home
func plan_recon(target: Vector2i) -> void:
	var cols := ship.grid.columns_of(ship.grid.side_of(target))
	# Enter from no-man's-land, which is at one end or the other
	if cols[0] < Grid.NO_MANS_LAND:
		cols.reverse()
	var pass_start := _local(Vector2i(cols[0], target.y))
	var pass_end := _local(Vector2i(cols[-1], target.y))
	var along := pass_start.direction_to(pass_end)
	var curve := _launch()
	_connect(curve, BOW * LAUNCH_RUN, BOW, pass_start, along)
	trigger_at = curve.get_baked_length()
	_straight(curve, pass_start, pass_end)
	_land(curve, pass_end, along)


# How fast to fly at `at` along the path
func _pace(at: float) -> float:
	if at < DECK_AHEAD:
		# Catapult: constant hard acceleration from a standstill
		return LAUNCH_SPEED * sqrt(maxf(at, 1.0) / DECK_AHEAD)
	if at >= stopped_at:
		return TAXI_SPEED
	if at >= touchdown_at:
		# Arrested: decelerates hard to a stop
		return maxf(APPROACH_SPEED * sqrt((stopped_at - at) / TRAP_RUN), TAXI_SPEED)
	var cruise := lerpf(LAUNCH_SPEED, speed, minf((at - DECK_AHEAD) / CLIMB_RUN, 1.0))
	# Slow to approach speed through the final turn
	return lerpf(APPROACH_SPEED, cruise, clampf((touchdown_at - at) / (GLIDE_RUN * 2), 0, 1))


# 0 on deck to 1 at cruising height
func _altitude(at: float) -> float:
	var climb := (at - DECK_AHEAD) / CLIMB_RUN
	var glide := (touchdown_at - at) / GLIDE_RUN
	return clampf(minf(climb, glide), 0.0, 1.0)


func _show_altitude(height: float) -> void:
	sprite.scale = Vector2.ONE * lerpf(1.0, ALTITUDE_SCALE, height)
	# The shadow falls the same way on screen whichever way the jet faces
	shadow.global_position = sprite.global_position + SHADOW_OFFSET * height
	shadow.global_rotation = sprite.global_rotation
	shadow.visible = height > 0.0


# A new path starting with the catapult run off the bow
func _launch() -> Curve2D:
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	_straight(curve, Vector2.ZERO, BOW * LAUNCH_RUN)
	path.curve = curve
	return curve


# Heads straight for final, traps at the stern and taxis back to the spot
func _land(curve: Curve2D, from: Vector2, heading: Vector2) -> void:
	_connect(curve, from, heading, FINAL, BOW)
	var touchdown := -BOW * (DECK_ASTERN - 4)
	var stop := touchdown + BOW * TRAP_RUN
	_straight(curve, FINAL, touchdown)
	touchdown_at = curve.get_baked_length()
	_straight(curve, touchdown, stop)
	stopped_at = curve.get_baked_length()
	_straight(curve, stop, Vector2.ZERO)


# Adds the shortest route from `from` (flying `heading`) to `to`, arriving
# flying `to_heading`, made of turns at TURN_RADIUS and straights: a Dubins
# path, either turn-straight-turn or turn-turn-turn
func _connect(
	curve: Curve2D, from: Vector2, heading: Vector2, to: Vector2, to_heading: Vector2
) -> void:
	# Each option is [length, legs]; legs are ["arc", center, start, way,
	# sweep] or ["straight", start, end]
	var options := []
	# Each turn either way (+1 turns the way Vector2.rotated() does)
	for way_out: float in [1.0, -1.0]:
		var center_out := from + heading.rotated(way_out * PI / 2) * TURN_RADIUS
		for way_in: float in [1.0, -1.0]:
			var center_in := to + to_heading.rotated(way_in * PI / 2) * TURN_RADIUS
			var gap := center_out.distance_to(center_in)
			var tangent := heading
			if way_out == way_in:
				if gap > 0.001:
					tangent = center_out.direction_to(center_in)
			else:
				# Crossing between circles turning opposite ways needs room
				if gap < TURN_RADIUS * 2:
					continue
				var tilt := atan2(TURN_RADIUS * 2, sqrt(gap * gap - 4 * TURN_RADIUS ** 2))
				tangent = (center_in - center_out).rotated(way_out * tilt).normalized()
			var leave := center_out + tangent.rotated(-way_out * PI / 2) * TURN_RADIUS
			var join := center_in + tangent.rotated(-way_in * PI / 2) * TURN_RADIUS
			var turn_out := _sweep(center_out, from, leave, way_out)
			var turn_in := _sweep(center_in, join, to, way_in)
			(
				options
				. append(
					[
						(turn_out + turn_in) * TURN_RADIUS + leave.distance_to(join),
						[
							["arc", center_out, from, way_out, turn_out],
							["straight", leave, join],
							["arc", center_in, join, way_in, turn_in],
						]
					]
				)
			)
		# Turn-turn-turn: a middle circle touching both, turning the other way
		var center_last := to + to_heading.rotated(way_out * PI / 2) * TURN_RADIUS
		var span := center_out.distance_to(center_last)
		if span < 0.001 or span > TURN_RADIUS * 4:
			continue
		var offset := sqrt(4 * TURN_RADIUS ** 2 - span * span / 4)
		for side: float in [1.0, -1.0]:
			var across := center_out.direction_to(center_last).orthogonal() * side * offset
			var middle := (center_out + center_last) / 2 + across
			var first := (center_out + middle) / 2
			var second := (middle + center_last) / 2
			var turns := [
				_sweep(center_out, from, first, way_out),
				_sweep(middle, first, second, -way_out),
				_sweep(center_last, second, to, way_out)
			]
			(
				options
				. append(
					[
						(turns[0] + turns[1] + turns[2]) * TURN_RADIUS,
						[
							["arc", center_out, from, way_out, turns[0]],
							["arc", middle, first, -way_out, turns[1]],
							["arc", center_last, second, way_out, turns[2]],
						]
					]
				)
			)
	var best: Array = options[0]
	for option: Array in options:
		if option[0] < best[0]:
			best = option
	for leg: Array in best[1]:
		if leg[0] == "arc":
			_arc(curve, leg[1], leg[2], leg[3], leg[4])
		else:
			_straight(curve, leg[1], leg[2])


# Angle swept going round `center` from `from` to `to` the `way` way
func _sweep(center: Vector2, from: Vector2, to: Vector2, way: float) -> float:
	var angle := (to - center).angle() - (from - center).angle()
	return fposmod(way * angle, TAU)


func _arc(curve: Curve2D, center: Vector2, from: Vector2, way: float, sweep: float) -> void:
	var steps := ceili(sweep * TURN_RADIUS / STEP)
	for k in range(1, steps + 1):
		_add(curve, center + (from - center).rotated(way * sweep * k / steps))


func _straight(curve: Curve2D, from: Vector2, to: Vector2) -> void:
	var steps := ceili(from.distance_to(to) / STEP)
	for k in range(1, steps + 1):
		_add(curve, from.lerp(to, float(k) / steps))


# Skips points on top of the last one, where a leg of (almost) no length ends
func _add(curve: Curve2D, point: Vector2) -> void:
	if curve.get_point_position(curve.point_count - 1).distance_to(point) > 0.5:
		curve.add_point(point)


func _local(hex: Vector2i) -> Vector2:
	return path.to_local(ship.grid.get_hex_center(hex))


func _take_off() -> void:
	path_follow.progress = 0
	# PathFollow2D turns the sprite 90 degrees once it starts following
	sprite.rotation_degrees = 90
	sprite.z_index = 1
	audio_player.play()
	flying = true
