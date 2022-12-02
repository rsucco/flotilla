extends Sprite

class_name Ship

# Declare member variables here.
var direction
var len_fore
var len_aft
var x
var y


# Called when the node enters the scene tree for the first time.
func _ready():
	self.position = get_parent().grid.get_hex_center(self.x, self.y)
	self.set_rotation_degrees(direction)
	pass # Replace with function body.

func init(direction, x, y):
	self.direction = direction
	self.x = x
	self.y = y

func get_occupied_tiles():
	var occupied_tiles = [[x, y]]
	for i in range(len_fore):
		occupied_tiles.append(get_parent().grid.get_hex_neighbor(x, y, direction, i + 1))
