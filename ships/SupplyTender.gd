extends Ship

class_name SupplyTender

var dc_timer

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'supply_tender'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Supply Tender'
	self.weapon = 'None'
	self.special = SpecialAbility.new(6, 'UNREP', 'Completely heals an adjacent ship')
	self.passive = PassiveAbility.new('Damage Control', 'Heals one hex every 10 turns if damaged')
	self.dc_timer = -1
	self.drawback = Drawback.new('Flammable Cargo', 'Lose 2 AP per turn if damaged')

# Supply tenders cannot fire
func can_fire():
	return false

func new_turn():
	.new_turn()
	# Drawback - Flammable Cargo
	# Lose 2 AP per turn if damaged
	if true in hit_hexes:
		print('drawback - flammable cargo')
		ap = 2
		# Passive ability - Damage Control
		# Heal one hex every 10 turns if damaged
		if dc_timer == -1:
			dc_timer = 10
		elif dc_timer == 0:
			dc_timer = 10
			hit_hexes[hit_hexes.find_last(true)] = false
			print('passive - damage control')
		else:
			dc_timer -= 1
