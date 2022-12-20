extends Projectile

var bubbles

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(orig, dest_hex, hidden_from = -1):
	.init(orig, dest_hex, hidden_from)
	speed = 300
	bubbles = Particles2D.new()
	var bubbles_material = ParticlesMaterial.new()
	bubbles_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	bubbles_material.initial_velocity = 15
	bubbles_material.gravity = Vector3(0, 0, 0)
	bubbles_material.damping = 10
	bubbles_material.color = Color.azure
	bubbles_material.scale = 0.005
	bubbles.process_material = bubbles_material
	bubbles.texture = preload('res://ships/sprites/projectiles/bubbles.png')
	bubbles.amount = 100
	bubbles.lifetime = 0.2
	bubbles.position += Vector2(1.5, 0)
#	add_child(bubbles)

func explode():
	.explode()
	bubbles.queue_free()
