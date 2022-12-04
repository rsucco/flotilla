extends Ship

class_name Carrier

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 2
	self.len_aft = 2
	self.ship_type = 'carrier'
	self.hit_hexes = [false, false, false, false, false]
	self.ship_name = 'Aircraft Carrier'
	self.weapon = 'F-35 Strike'
	self.special = 'Recon Flight (4 turns)'
	self.secondary = 'None'
	self.passive = 'Can take two attack moves in one turn instead of moving'
	self.drawback = 'If two or more hexes are damaged, can only take one attack move'
