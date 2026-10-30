class_name Torpedo
extends Projectile

const FIRE_SOUND := preload("res://audio/torpedo.wav")

var enroute := false

@onready var path: Path2D = $Path2D
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var sprite: Sprite2D = $Path2D/PathFollow2D/Sprite2D


# Follows its own path instead of moving straight, so no super()
func _process(delta: float) -> void:
	path_follow.progress += speed * delta
	if enroute and grid.get_hex_from_coords(to_global(path_follow.position)) == dest_hex:
		enroute = false
		done.emit()
		await explode(to_global(dest))
		queue_free()


# `start_rotation` is in radians. Doesn't call super(): dest is in local
# coordinates here because the torpedo follows a curved local path.
func launch(origin: Vector2, target: Vector2i, start_rotation: float = 0.0) -> void:
	root = get_parent()
	Sfx.play(self, FIRE_SOUND)
	rotation = start_rotation
	global_position = origin
	dest_hex = target
	dest = to_local(grid.get_hex_center(dest_hex))
	speed = 150.0
	enroute = true

	var bubbles := CPUParticles2D.new()
	bubbles.local_coords = true
	bubbles.gravity = Vector2.ZERO
	bubbles.initial_velocity_min = -15.0
	bubbles.initial_velocity_max = -15.0
	bubbles.damping_min = 10.0
	bubbles.damping_max = 10.0
	bubbles.color = Color.AZURE
	bubbles.scale_amount_min = 0.01
	bubbles.scale_amount_max = 0.01
	bubbles.texture = FIRE_TEXTURE
	bubbles.amount = 50
	bubbles.lifetime = 0.2
	bubbles.position.x -= 1.5
	sprite.add_child(bubbles)

	# Curve out of the tube, then head for the target
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(0, -50), Vector2.ZERO, Vector2(0, -100))
	curve.add_point(dest)
	path.curve = curve


func explode(pos: Vector2) -> void:
	sprite.texture = null
	await super(pos)
