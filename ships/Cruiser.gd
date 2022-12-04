extends Ship

class_name Cruiser

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'cruiser'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Cruiser'
	self.weapon = 'Anti-Ship Missile'
	self.special = 'EW Strike (6 turns)'
	self.secondary = 'None'
	self.passive = '50% chance of intercepting incoming missile attacks within two hexes'
	self.drawback = 'None'

