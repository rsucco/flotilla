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

# Override to implement passive ability and drawback
func new_turn():
	.new_turn()
	var num_hit_hexes = 0
	for hex in hit_hexes:
		if !hex:
			num_hit_hexes += 1
	# Drawback: loses passive ability if two or more hexes are damaged
	if num_hit_hexes < 2:
		# Passive ability: gets two fire moves
		fire_remaining = 2
