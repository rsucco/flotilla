extends Ship

class_name Destroyer

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.desc = 'Submarine'
	self.hit_hexes = [false, false, false]
