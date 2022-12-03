extends Sprite

class_name Ship

# Declare member variables here.
var direction
var len_fore
var len_aft
var x
var y
var desc = ''

# Called when the node enters the scene tree for the first time.
func _ready():
	self.position = get_parent().grid.get_hex_center(self.x, self.y)

func set_grid_position(x, y, direction):
	self.direction = direction
	self.set_rotation_degrees(direction)
	self.x = x
	self.y = y

func get_occupied_hexes():
	var occupied_hexes = [[x, y]]
	for i in range(len_fore):
		occupied_hexes.append(get_parent().grid.get_hex_neighbor(occupied_hexes[-1][0], occupied_hexes[-1][1], direction))
	occupied_hexes.invert()
	for i in range(len_aft):
		occupied_hexes.append(get_parent().grid.get_hex_neighbor(occupied_hexes[-1][0], occupied_hexes[-1][1], direction + 180))
	return occupied_hexes

func rotate(rotation_offset):
	self.direction += rotation_offset
	self.set_rotation_degrees(self.direction)

func move(num_tiles):
	for i in range(num_tiles):
		var new_hex = get_parent().grid.get_hex_neighbor(x, y, direction)
		if new_hex == [-1, -1]:
			break
		self.x = new_hex[0]
		self.y = new_hex[1]
	self.position = get_parent().grid.get_hex_center(self.x, self.y)
