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
	self.special = SpecialAbility.new(6, 'EW Strike', 
	'Select a hex on opponent\'s board; prevents all units within two hexes of central hex from firing next turn and either resets or adds five to their special ability cooldowns, whichever is less', 2)
	self.passive = PassiveAbility.new('Missile Defense', 
	'50% chance of intercepting incoming missile attacks within two hexes if no move action was taken last turn (chance is reduced to 25% for incoming nuclear strike)')

