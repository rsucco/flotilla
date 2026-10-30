class_name EWStrike
extends Node2D

const EW_SOUND := preload("res://audio/ew_strike.wav")
const MASK := preload("res://ships/sprites/projectiles/ew_mask.png")

# Opaque pixels of the mask, where the static particles spawn. Computed once.
static var mask_points := PackedVector2Array()


# Plays the jamming effect at `pos`; returns when it's finished
func play(pos: Vector2) -> void:
	Sfx.play(self, EW_SOUND)
	position = pos
	add_child(make_static())
	await get_tree().create_timer(0.5).timeout
	queue_free()


func make_static() -> CPUParticles2D:
	if mask_points.is_empty():
		var image := MASK.get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0:
					mask_points.append(Vector2(x, y))
	var particles := CPUParticles2D.new()
	particles.position = Vector2(-101, -100)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	particles.emission_points = mask_points
	particles.gravity = Vector2.ZERO
	particles.amount = 1500
	particles.lifetime = 0.15
	particles.randomness = 1.0
	particles.scale_amount_min = 0.0
	particles.scale_amount_max = 5.0
	# Black to white over each particle's life (Gradient's default)
	particles.color_ramp = Gradient.new()
	return particles
