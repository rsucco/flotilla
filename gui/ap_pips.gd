class_name APPips
extends Control
# One dot per action point: filled for those left, hollow for those spent

const RADIUS := 3.5
const GAP := 11.0

var ap := 0
var total := 0


func show_ap(left: int, full: int) -> void:
	ap = left
	# The corvette's island passive can give it more AP than usual
	total = maxi(left, full)
	queue_redraw()


func _draw() -> void:
	var start := size.x / 2 - GAP * (total - 1) / 2
	for i in total:
		var at := Vector2(start + GAP * i, size.y / 2)
		if i < ap:
			draw_circle(at, RADIUS, Color.WHITE, true, -1.0, true)
		else:
			draw_circle(at, RADIUS, Color(1, 1, 1, 0.6), false, 1.0, true)
