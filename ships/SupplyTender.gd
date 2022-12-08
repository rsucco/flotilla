extends Ship

class_name SupplyTender

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
	self.drawback = Drawback.new('Flammable Cargo', 'Lose 2 AP per turn if damaged')
