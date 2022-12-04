extends Sprite

class_name Ship

const SHIP_TYPES = ['coastal_battery', 'corvette', 'destroyer', 'submarine', 'cruiser', 'supply_tender', 'battleship', 'carrier']
var direction
var len_fore
var len_aft
var x
var y
var ship_type = ''
var hit_hexes = []
var ship_name = ''
var weapon = ''
var special = ''
var secondary = ''
var passive = ''
var drawback = ''

# Called when the node enters the scene tree for the first time.
func _ready():
	self.position = get_parent().grid.get_hex_center(self.x, self.y)

func set_grid_position(x, y, direction):
	self.direction = direction
	self.set_rotation_degrees(direction)
	self.x = x
	self.y = y

func get_occupied_hexes(on_x = self.x, on_y = self.y, in_dir = self.direction):
	var occupied_hexes = [[on_x, on_y]]
	for _i in range(len_fore):
		occupied_hexes.append(get_parent().grid.get_hex_neighbor(occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir))
	occupied_hexes.remove(0)
	occupied_hexes.invert()
	occupied_hexes.append([on_x, on_y])
	for _i in range(len_aft):
		occupied_hexes.append(get_parent().grid.get_hex_neighbor(occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir + 180))
	return occupied_hexes

func get_size():
	return self.len_aft + self.len_fore + 1

func hit(hit_hex):
	hit_hexes[self.get_occupied_hexes().find(hit_hex)] = true
	var smoke = Particles2D.new()
	var smoke_material = ParticlesMaterial.new()
	smoke_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_RING
	smoke_material.emission_ring_radius = self.get_size() * 3 - 3
	smoke_material.direction = Vector3(-50, 0, 0)
	smoke_material.gravity = Vector3(0, 150, 0)
	smoke_material.spread = 25.0
	smoke_material.damping = -1.5
	smoke_material.scale = 2.5
	smoke_material.color = Color(0.0, 0.0, 0.0)
	smoke.process_material = smoke_material
	smoke.amount = pow(self.get_size(), 2) * 10
	smoke.lifetime = 0.5
	add_child(smoke)
	if not false in hit_hexes:
		self.sink()

func sink():
	# TODO: Hacky af, change all this
	if get_parent().selected_ship == self:
		get_parent().selected_ship = null
	get_parent().ships[0].remove(get_parent().ships[0].find(self))
	get_parent().ships[1].remove(get_parent().ships[1].find(self))
	get_parent().gui.update_fleets()
	queue_free()

func rotate(rotation_offset):
	if not [-1, -1] in get_occupied_hexes(self.x, self.y, self.direction + rotation_offset):
		self.direction += rotation_offset
		self.set_rotation_degrees(self.direction)

func move(num_tiles):
	for _i in range(num_tiles):
		var new_hex = get_parent().grid.get_hex_neighbor(x, y, direction)
		if [-1, -1] in get_occupied_hexes(new_hex[0], new_hex[1]):
			break
		self.x = new_hex[0]
		self.y = new_hex[1]
	self.position = get_parent().grid.get_hex_center(self.x, self.y)
