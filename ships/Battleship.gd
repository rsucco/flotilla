extends Ship

class_name Battleship

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 2
	self.ship_type = 'battleship'
	self.hit_hexes = [false, false, false, false]
	self.ship_name = 'Battleship'
	self.weapon = 'Big Gun'
	self.special = SpecialAbility.new(7, 'Salvo', 
	'Shoot one central hex and damage whatever it contains as well as all of its immediate neighbors; if central hex is a damaged hex, sink the enemy ship instantly')
	self.passive = PassiveAbility.new('Armor', 'Armor grants 25% chance of hits not counting')
