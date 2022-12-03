extends Ship

class_name Corvette

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 0
	self.len_aft = 1
	self.desc = 'Corvette'
	self.hit_hexes = [false, false]
