class_name BattleshipProjectile
extends Projectile

const DEFAULT_FIRE_SOUND := preload("res://audio/battleship.wav")


func launch(
	origin: Vector2, target: Vector2i, fire_sound: AudioStream = DEFAULT_FIRE_SOUND
) -> void:
	super(origin, target)
	Sfx.play(self, fire_sound)
	speed = 400.0
	# Muzzle flash, blown along the line of fire
	var flash := CPUParticles2D.new()
	flash.gravity = Vector2.ZERO
	flash.direction = Vector2.RIGHT.rotated(rotation)
	flash.initial_velocity_min = 15.0
	flash.initial_velocity_max = 15.0
	flash.damping_min = 10.0
	flash.damping_max = 10.0
	flash.color = Color.SALMON
	flash.scale_amount_min = 0.02
	flash.scale_amount_max = 0.02
	flash.texture = FIRE_TEXTURE
	flash.amount = 200
	flash.lifetime = 0.3
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.global_position = global_position
	flash.finished.connect(flash.queue_free)
	add_sibling(flash)
