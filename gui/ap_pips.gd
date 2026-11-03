class_name APPips
extends Node2D
# A dot above each of our ships for every action point it has left

const RADIUS := 3.5
const GAP := 10.0
# Between the top of the ship and the dots
const LIFT := 8.0

var ships: Array[Ship] = []
# What the dots were last drawn from: each ship's place, heading, AP and
# whether it's shown
var _drawn := []


# Ships move and spend AP between redraws. Only redrawn when that changes, so
# an idle board doesn't keep the screen redrawing (and a handheld's battery
# draining).
func _process(_delta: float) -> void:
	var now := ships.map(
		func(ship: Ship) -> Array:
			if not is_instance_valid(ship):
				return []
			return [ship.global_position, ship.global_rotation, ship.ap, ship.visible]
	)
	if now != _drawn:
		_drawn = now
		queue_redraw()


func _draw() -> void:
	for ship in ships:
		if not is_instance_valid(ship) or not ship.visible or ship.ap <= 0:
			continue
		# The top of the sprite on screen, whichever way the ship faces
		var rect := ship.get_rect()
		var corners: Array[Vector2] = []
		for corner: Vector2 in [
			rect.position,
			rect.end,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + Vector2(0, rect.size.y)
		]:
			corners.append(to_local(ship.to_global(corner)))
		var top: float = corners.map(func(c: Vector2) -> float: return c.y).min()
		var middle := to_local(ship.global_position).x
		var start := middle - GAP * (ship.ap - 1) / 2
		for i in ship.ap:
			var at := Vector2(start + GAP * i, top - LIFT)
			draw_circle(at, RADIUS, Color.WHITE, true, -1.0, true)
			# Outlined so they stand out on the water
			draw_circle(at, RADIUS, Color(0, 0, 0, 0.6), false, 1.0, true)
