extends Sprite

class_name Projectile

signal done
signal explosion_done

var dest
var dest_hex
var hidden_from_player
var speed
var moving = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(orig, destination_hex, hidden_from = -1):
	global_position = orig
	dest_hex = destination_hex
	dest = get_parent().grid.get_hex_center(dest_hex[0], dest_hex[1])
	rotation = position.angle_to_point(dest)
	hidden_from_player = hidden_from
	moving = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if moving:
		position = position.move_toward(dest, speed * delta)
		if get_parent().grid.get_hex_from_coords(position) == dest_hex:
			moving = false
			emit_signal('done')
			explode()
			yield(self, 'explosion_done')
			queue_free()

func explode(pos = null):
	if pos == null:
		position = dest
		pos = position
	texture = null
	var last_event = get_parent().grid.grid[dest_hex[0]][dest_hex[1]].get_last_event()
	if last_event != null and last_event[1] in ['Hit', 'Sunk'] or \
	get_parent().grid.grid[dest_hex[0]][dest_hex[1]].island:
		boom(pos)
	else:
		splash(pos)

func boom(pos):
	var fire = Particles2D.new()
	var fire_material = ParticlesMaterial.new()
	fire_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	fire_material.initial_velocity = 15
	fire_material.gravity = Vector3(0, 0, 0)
	fire_material.spread = 360.0
	fire_material.damping = 10
	fire_material.color = Color.coral
	fire_material.scale = 0.03
	fire.process_material = fire_material
	fire.texture = preload('res://ships/sprites/projectiles/fire.png')
	fire.amount = 200
	fire.lifetime = 0.7
	fire.set_one_shot(true)
	fire.set_explosiveness_ratio(1)
	fire.position = pos
	get_parent().add_child(fire)

	var smoke = Particles2D.new()
	var smoke_material = ParticlesMaterial.new()
	smoke_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	smoke_material.initial_velocity = 30
	smoke_material.gravity = Vector3(0, 0, 0)
	smoke_material.spread = 360.0
	smoke_material.damping = 15
	smoke_material.scale = 0.03
	smoke.process_material = smoke_material
	smoke.texture = preload('res://ships/sprites/projectiles/smoke.png')
	smoke.amount = 300
	smoke.lifetime = 0.9
	smoke.set_one_shot(true)
	smoke.set_explosiveness_ratio(1)
	smoke.position = pos
	get_parent().add_child(smoke)

	var t = Timer.new()
	t.set_wait_time(0.9)
	t.set_one_shot(true)
	self.add_child(t)
	t.start()
	yield(t, "timeout")
	fire.queue_free()
	smoke.queue_free()
	emit_signal('explosion_done')

func splash(pos):
	var ripples = Particles2D.new()
	var ripples_material = ParticlesMaterial.new()
	ripples_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_RING
	ripples_material.emission_ring_radius = 1
	ripples_material.initial_velocity = 35
	ripples_material.gravity = Vector3(0, 0, 0)
	ripples_material.spread = 360.0
	ripples_material.damping = 35
	ripples_material.color = Color(0.65, 1.0, 1.0, 0.5)
	ripples_material.scale = 3
	ripples.process_material = ripples_material
	ripples.amount = 1000
	ripples.lifetime = 0.75
	ripples.set_one_shot(true)
	ripples.set_explosiveness_ratio(1)
	ripples.position = pos
	get_parent().add_child(ripples)

	var t = Timer.new()
	t.set_wait_time(ripples.lifetime)
	t.set_one_shot(true)
	self.add_child(t)
	t.start()
	yield(t, "timeout")
	ripples.queue_free()
	emit_signal('explosion_done')
