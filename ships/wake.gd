class_name Wake
extends Node2D
# The water a ship leaves behind it: a churned streak along its track and the
# two arms of a Kelvin wake spreading from it, in flat foam like the sea's,
# fading in steps. A child of its ship, so it's drawn under it and hidden with
# it, but drawn in the board's coordinates, so what's in the water stays put.

const LIFETIME := 3.5
# A Kelvin wake's arms spread at tan(19.5°) of the distance the ship has gone
const SPREAD := 0.36
# And keep spreading a little once it's stopped (px/s)
const DRIFT := 3.0
const FOAM := Color(0.85, 0.92, 0.97)
# How far apart (px) the points along the track are
const STEP := 3.0

# Set by the ship: where its stern is, in its own coordinates, and half its
# beam (px)
var stern := Vector2.ZERO
var beam := 4.0
# The ship is under way, so the track goes on
var moving := false
var _age := 0.0
var _travelled := 0.0
# Along the track, oldest first: [where, heading, travelled, born, fleck], the
# fleck being where in the churned water a bit of foam is (-1 to 1 across it)
var _track: Array[Array] = []


func _process(delta: float) -> void:
	_age += delta
	if moving:
		_follow()
	while not _track.is_empty() and _age - _track[0][3] > LIFETIME:
		_track.pop_front()
	if _track.is_empty() and not moving:
		queue_free()
		return
	queue_redraw()


# Marks the stern's place on the track, once it's moved on far enough
func _follow() -> void:
	var at := get_global_transform() * stern
	if _track.is_empty():
		_track.append([at, Vector2.ZERO, 0.0, _age, randf_range(-1.0, 1.0)])
		return
	var last: Vector2 = _track[-1][0]
	var gone := last.distance_to(at)
	if gone < STEP:
		return
	_travelled += gone
	var heading := last.direction_to(at)
	if _track.size() == 1:
		_track[0][1] = heading
	_track.append([at, heading, _travelled, _age, randf_range(-1.0, 1.0)])


func _draw() -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for i in range(1, _track.size()):
		var a := _track[i - 1]
		var b := _track[i]
		var fade := _fade(_age - float(b[3]))
		if fade <= 0.0:
			continue
		var streak := PackedVector2Array()
		for end: Array in [a, b]:
			streak.append(_side(end, _churn(end), 1))
		for end: Array in [b, a]:
			streak.append(_side(end, _churn(end), -1))
		draw_colored_polygon(streak, Color(FOAM, 0.5 * fade))
		var fleck := _side(b, _churn(b) * absf(b[4]), signi(int(signf(b[4]))))
		draw_rect(Rect2(fleck.snapped(Vector2(2, 2)), Vector2(2, 2)), Color(FOAM, fade))
		# The arms are broken foam, not lines
		if float(b[4]) < -0.5:
			continue
		for side in [1, -1]:
			draw_line(
				_side(a, _arm(a), side), _side(b, _arm(b), side), Color(FOAM, 0.85 * fade), 2.0
			)


# The point `out` px to one side (1 or -1) of a point on the track
func _side(point: Array, out: float, side: int) -> Vector2:
	var heading: Vector2 = point[1]
	return point[0] + heading.orthogonal() * side * out


# How far out from the track the churned water reaches at a point, widening
# with its age
func _churn(point: Array) -> float:
	return beam * 0.6 + DRIFT * 0.5 * (_age - float(point[3]))


# How far out an arm of the wake has spread from a point on the track
func _arm(point: Array) -> float:
	return beam + SPREAD * (_travelled - float(point[2])) + DRIFT * (_age - float(point[3]))


# Fading in steps, as the sea's shaded in bands
func _fade(age: float) -> float:
	return ceilf((1.0 - age / LIFETIME) * 4.0) / 4.0
