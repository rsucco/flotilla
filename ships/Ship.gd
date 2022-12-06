extends Sprite

class_name Ship

signal placed
const SHIP_TYPES = ['coastal_battery', 'corvette', 'destroyer', 'submarine', 'cruiser', 'supply_tender', 'battleship', 'carrier']
var direction = 0
var root
var ap = 0
var len_fore
var len_aft
var x = -10
var y = -10
var ship_type = ''
var hit_hexes = []
var ship_name = ''
var weapon = ''
var special = ''
var secondary = ''
var passive = ''
var drawback = ''
var selected = false
var placing = false

# Called when the node enters the scene tree for the first time.
func _ready():
	root = get_parent().get_parent()
	#self.position = get_parent().grid.get_hex_center(self.x, self.y)

func set_grid_position(x, y, direction):
	self.direction = direction
	self.set_rotation_degrees(direction)
	self.x = x
	self.y = y
	self.position = root.grid.get_hex_center(self.x, self.y)

func _input(event):
	if placing:
		if event is InputEventMouseMotion:
			var mouse_position = root.grid.get_hex_from_coords(event.position)
			var occupied_hexes = get_occupied_hexes(mouse_position[0], mouse_position[1])
			var any_land = false
			var already_occupied = false
			for hex in occupied_hexes:
				if root.grid.grid[hex[0]][hex[1]].island:
					any_land = true
				if root.get_ship_at_hex(hex[0], hex[1]) != null:
					already_occupied = true
			if ship_type == 'coastal_battery':
				any_land = !any_land
			root.get_ship_at_hex(mouse_position[0], mouse_position[1])
			if !occupied_hexes.has([-1, -1]) and !any_land and !already_occupied and \
			mouse_position[0] in range(get_parent().player_num * 16, get_parent().player_num * 16 + 15):
				set_grid_position(mouse_position[0], mouse_position[1], direction)
		elif event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				self.rotate(-60)
			elif event.button_index == BUTTON_WHEEL_DOWN:
				self.rotate(60)
			elif event.button_index == BUTTON_LEFT and x != -10 and y != -10:
				placing = false
				emit_signal('placed')

func get_occupied_hexes(on_x = self.x, on_y = self.y, in_dir = self.direction):
	var occupied_hexes = [[on_x, on_y]]
	for _i in range(len_aft):
		occupied_hexes.append(root.grid.get_hex_neighbor(
			occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir + 180))
	occupied_hexes.remove(0)
	occupied_hexes.invert()
	occupied_hexes.append([on_x, on_y])
	for _i in range(len_fore):
		occupied_hexes.append(root.grid.get_hex_neighbor(
			occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir))
	return occupied_hexes

func get_size():
	return self.len_aft + self.len_fore + 1

func new_turn():
	ap = 4

func place():
	placing = true

func hit(hit_hex):
	var hit_hex_index = self.get_occupied_hexes().find(hit_hex)
	hit_hexes[hit_hex_index] = true
	var smoke = Particles2D.new()
	var smoke_material = ParticlesMaterial.new()
	smoke_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_RING
	smoke_material.emission_ring_radius = self.get_size() * 3 - 3
	smoke_material.direction = Vector3(-50, 0, 0)
	smoke_material.gravity = Vector3(0, 150, 0)
	smoke_material.spread = 25.0
	smoke_material.damping = -1.5
	smoke_material.scale = 2.5
	if ship_type == 'submarine':
		smoke_material.color = Color(0.7, 1.0, 1.0)
	else:
		smoke_material.color = Color(0.0, 0.0, 0.0)
	smoke.process_material = smoke_material
	smoke.amount = pow(self.get_size(), 2) * 10
	smoke.lifetime = 0.5
	var hex_size = root.grid.hex_size
	smoke.position -= Vector2(0, hex_size * (hit_hex_index - len_aft))
	if len_fore == 0:
		smoke.position -= Vector2(0, 10)
	elif len_fore == 2:
		if hit_hex_index == 0:
			smoke.position -= Vector2(0, 10)
		elif hit_hex_index == 4:
			smoke.position += Vector2(0, 15)
	add_child(smoke)
	if not false in hit_hexes:
		self.sink()

func sink():
	# TODO: Hacky af, change all this
	if root.selected_ship == self:
		root.selected_ship = null
	get_parent().ships.remove(get_parent().ships.find(self))
	root.gui.update_fleets()
	queue_free()

func rotate(rotation_offset):
	var rotated_hexes = get_occupied_hexes(self.x, self.y, self.direction + rotation_offset)
	var any_land = false
	var already_occupied = false
	for hex in rotated_hexes:
		if root.grid.grid[hex[0]][hex[1]].island:
			any_land = true
		if root.get_ship_at_hex(hex[0], hex[1]) != null:
			already_occupied = true
	if ship_type == 'coastal_battery':
		any_land = !any_land
	if not [-1, -1] in rotated_hexes and !any_land and !already_occupied:
		self.direction += rotation_offset
		self.set_rotation_degrees(self.direction)

func move(num_tiles):
	for _i in range(num_tiles):
		var new_hex = root.grid.get_hex_neighbor(x, y, direction)
		if [-1, -1] in get_occupied_hexes(new_hex[0], new_hex[1]):
			break
		self.x = new_hex[0]
		self.y = new_hex[1]
	self.position = root.grid.get_hex_center(self.x, self.y)
