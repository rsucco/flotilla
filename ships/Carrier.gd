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
	self.special = SpecialAbility.new(4, 'Recon Flight', 
	'Select three connecting hexes on opponent\'s board; reveals hexes and all their immediate neighbors')
	self.passive = PassiveAbility.new('Flight Ops', 'Can take two attack moves in one turn instead of moving')
	self.drawback = Drawback.new('Degraded Runway', 'If two or more hexes are damaged, can only take one attack move')
