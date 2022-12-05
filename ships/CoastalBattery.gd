extends Ship

class_name CoastalBattery

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 0
	self.len_aft = 0
	self.ship_type = 'coastal_battery'
	self.hit_hexes = [false, false]
	self.ship_name = 'Coastal Battery'
	self.weapon = 'Big Gun'
	self.special = 'None'
	self.secondary = 'None'
	self.passive = 'Must be hit five times to destroy'
	self.drawback = 'Cannot move, reveals itself when firing'

