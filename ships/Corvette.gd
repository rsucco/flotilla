extends Ship

class_name Corvette

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 0
	self.len_aft = 1
	self.ship_type = 'corvette'
	self.hit_hexes = [false, false]
	self.ship_name = 'Corvette'
	self.weapon = 'Deck Gun'
	self.passive = PassiveAbility.new('Littoral Ops', 'Gains an extra move if starting next to an island tile')
	self.drawback = Drawback.new('Fragile', 'Has a 75% chance of sinking if hit in either hex')

func new_turn():
	# TODO: Override this to set ap=5 if any neighbor hex is an island tile, ap=4 otherwise
	.new_turn()
