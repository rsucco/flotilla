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
	self.special = 'Salvo (7 turns)'
	self.secondary = 'None'
	self.passive = 'Armor grants 25% chance of hits not counting'
	self.drawback = 'None'
