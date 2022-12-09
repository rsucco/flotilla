extends Ship

class_name CoastalBattery

# Called when the node enters the scene tree for the first time.
func _ready():
	self.default_ap = 2
	self.len_fore = 0
	self.len_aft = 0
	self.ship_type = 'coastal_battery'
	self.hit_hexes = [false]
	self.ship_name = 'Coastal Battery'
	self.weapon = 'Big Gun'
	self.passive = PassiveAbility.new('Fortified', 'Must be hit five times to destroy')
	self.drawback = Drawback.new('Stationary', 'Cannot move, reveals itself when firing')

# Coastal batteries can't move; always return false
func can_move(reverse = false, distance = 1):
	return false

# Coastal batteries have no need to rotate; always return false
func can_rotate(dir = 0):
	return false

# Don't rotate in placement screen either
func rotate(rotation_offset = 0):
	pass
