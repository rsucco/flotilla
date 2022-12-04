extends Ship

class_name Submarine

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'destroyer'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Destroyer'
	self.weapon = 'Anti-Ship Missile'
	self.special = 'AWS Strike (4 turns)'
	self.secondary = 'Lay Mine (5 turns)'
	self.passive = 'None'
	self.drawback = 'None'

