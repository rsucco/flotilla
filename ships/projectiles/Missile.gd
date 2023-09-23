extends Projectile

var max_speed = 300
var fire

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(orig, dest_hex, hidden_from = -1, starting_rotation = 0, instafire = false):
	.init(orig, dest_hex, hidden_from)
	global_rotation_degrees = starting_rotation
	speed = 0
	fire = Particles2D.new()
	var fire_material = ParticlesMaterial.new()
	fire_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	fire_material.initial_velocity = 15
	fire_material.gravity = Vector3(0, 0, 0)
	fire_material.damping = 10
	fire_material.color = Color.darksalmon
	fire_material.scale = 0.005
	fire.process_material = fire_material
	fire.texture = preload('res://ships/sprites/projectiles/fire.png')
	fire.amount = 100
	fire.lifetime = 0.2
	fire.position += Vector2(1.5, 0)
	add_child(fire)
	if instafire:
		global_rotation_degrees = position.angle_to_point(dest) * 180 / PI
	else:
		var t = Timer.new()
		t.set_wait_time(.5)
		t.set_one_shot(true)
		self.add_child(t)
		t.start()
		yield(t, "timeout")
		var tween = Tween.new()
		tween.interpolate_property(self, 'global_rotation_degrees', global_rotation_degrees, position.angle_to_point(dest) * 180 / PI, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		add_child(tween)
		tween.start()
		yield(tween, 'tween_completed')
	speed = 300

func explode(pos = null):
	.explode(pos)
	fire.queue_free()
