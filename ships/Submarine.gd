extends Ship

class_name Destroyer

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'submarine'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Submarine'
	self.weapon = 'Torpedo'
	self.special = SpecialAbility.new(10, 'Nuclear Strike',
	'Select a hex on opponent\'s board; instantly sinks any unit it hits directly and damages all hexes within two hexes of central hex', 2)
	self.secondary = SpecialAbility.new(1, 'Sonar Pulse',
	'Select a hex on opponent\'s board; reveals ships and submarines on that hex and its direct neighbors and also reveals the location of the submarine', 1)
	self.passive = PassiveAbility.new('Silent Service', 'Can only be hit by surface units on center hex')
	self.drawback = Drawback.new('Crushing Depths', 
	'Sinks instantly when hit in center hex by surface unit, or when hit in any hex by ASW Strike, mine, or another sub') 
