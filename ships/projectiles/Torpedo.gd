extends Projectile

var bubbles
var path
var path_follow
var sprite
var enroute = false

# Called when the node enters the scene tree for the first time.
func _ready():
	path = $Path2D
	path_follow = $Path2D/PathFollow2D
	sprite = $Path2D/PathFollow2D/Sprite

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	path_follow.offset += speed * delta
	if enroute and get_parent().grid.get_hex_from_coords(to_global(path_follow.position)) == dest_hex:
		enroute = false
		emit_signal('done')
		explode(to_global(dest))
		yield(self, 'explosion_done')
		queue_free()

func init(orig, destination_hex, hidden_from = -1, starting_rotation = 0):
	rotation = starting_rotation
	global_position = orig
	dest_hex = destination_hex
	dest = to_local(get_parent().grid.get_hex_center(dest_hex[0], dest_hex[1]))
	hidden_from_player = hidden_from
	speed = 75
	enroute = true
	# Generate bubbles
	bubbles = Particles2D.new()
	var bubbles_material = ParticlesMaterial.new()
	bubbles_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	bubbles_material.initial_velocity = -15
	bubbles_material.gravity = Vector3(0, 0, 0)
	bubbles_material.damping = 10
	bubbles_material.color = Color.azure
	bubbles_material.scale = 0.01
	bubbles.process_material = bubbles_material
	bubbles.texture = preload('res://ships/sprites/projectiles/fire.png')
	bubbles.amount = 50
	bubbles.lifetime = 0.2
	bubbles.position += Vector2(-1.5, 0)
	sprite.add_child(bubbles)

	# Follow a nice curved path
	var start_point = Vector2.ZERO
	var turn_point = Vector2(0, -50)
	var control_point = Vector2(0, -100)
	var path_curve = Curve2D.new()
	path_curve.add_point(start_point)
	path_curve.add_point(turn_point, Vector2.ZERO, control_point)
	path_curve.add_point(dest)
	path.curve = path_curve

func explode(pos = null):
	sprite.texture = null
	.explode(pos)
