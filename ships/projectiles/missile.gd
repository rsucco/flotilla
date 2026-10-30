class_name Missile
extends Projectile

const FIRE_SOUND := preload("res://audio/missile.wav")
const MAX_SPEED := 500.0

var rotate_sound: AudioStream = preload("res://audio/missile_rotate.wav")
var enroute := false
var exhaust: CPUParticles2D


func _process(delta: float) -> void:
	super(delta)
	if enroute and speed < MAX_SPEED:
		speed += 500 * delta


# Turns toward the target (unless instafire) before accelerating
func launch(
	origin: Vector2, target: Vector2i, start_degrees: float = 0.0, instafire: bool = false
) -> void:
	super(origin, target)
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
		await get_tree().create_timer(0.5).timeout
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


func explode(pos: Vector2) -> void:
	exhaust.queue_free()
	await super(pos)
