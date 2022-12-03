extends Ship

class_name Battleship

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 2
	self.desc = 'Battleship'
	self.hit_hexes = [false, false, false, false]
