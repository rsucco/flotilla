extends Projectile

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(orig, dest_hex, hidden_from = -1):
	.init(orig, dest_hex, hidden_from)
	speed = 400
	var fire = Particles2D.new()
	var fire_material = ParticlesMaterial.new()
	fire_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	if get_parent().player_up == 0:
		fire_material.initial_velocity = 15
	else:
		fire_material.initial_velocity = -15
	fire_material.gravity = Vector3(0, 0, 0)
	fire_material.damping = 10
	fire_material.color = Color.salmon
	fire_material.scale = 0.02
	fire.process_material = fire_material
	fire.texture = preload('res://ships/sprites/projectiles/fire.png')
	fire.amount = 200
	fire.lifetime = 0.3
	fire.set_one_shot(true)
	fire.set_explosiveness_ratio(1)
	fire.global_position = global_position
	get_parent().add_child(fire)
