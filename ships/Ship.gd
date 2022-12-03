extends Sprite

class_name Ship

# Declare member variables here.
var direction
var len_fore
var len_aft
var x
var y
var desc = ''
var hit_hexes = []

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
	for i in range(len_fore):
		occupied_hexes.append(get_parent().grid.get_hex_neighbor(occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir))
	occupied_hexes.remove(0)
	occupied_hexes.invert()
	occupied_hexes.append([on_x, on_y])
	for i in range(len_aft):
		occupied_hexes.append(get_parent().grid.get_hex_neighbor(occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir + 180))
	return occupied_hexes

func hit(hit_hex):
	var i = self.get_occupied_hexes().find(hit_hex)
	hit_hexes[i] = true
	if not false in hit_hexes:
		self.sink()

func sink():
	hide()
	if get_parent().selected_ship == self:
		get_parent().selected_ship = null
	get_parent().ships.remove(get_parent().ships.find(self))
	get_parent().remove_child(self)

func rotate(rotation_offset):
	if not [-1, -1] in get_occupied_hexes(self.x, self.y, self.direction + rotation_offset):
		self.direction += rotation_offset
		self.set_rotation_degrees(self.direction)

func move(num_tiles):
	for i in range(num_tiles):
		var new_hex = get_parent().grid.get_hex_neighbor(x, y, direction)
		if [-1, -1] in get_occupied_hexes(new_hex[0], new_hex[1]):
			break
		self.x = new_hex[0]
		self.y = new_hex[1]
	self.position = get_parent().grid.get_hex_center(self.x, self.y)
