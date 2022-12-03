extends Ship

class_name Carrier

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 2
	self.len_aft = 2
	self.desc = 'Aircraft Carrier'
	self.hit_hexes = [false, false, false, false, false]
