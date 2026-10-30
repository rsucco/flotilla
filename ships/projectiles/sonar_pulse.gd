class_name SonarPulse
extends Sprite2D

signal done

var radius := 0.0


# Expands a ring at `pos`; returns when it's finished
func play(pos: Vector2) -> void:
	position = pos
	scale = Vector2(5, 5)
	await done


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 100, Color(0, 0, 0, 0.5), 2)


func _process(delta: float) -> void:
	radius += delta * 50
	if radius > 13:
		done.emit()
		queue_free()
	queue_redraw()
