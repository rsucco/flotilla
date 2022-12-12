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
	.new_turn()
	# Passive ability - Littoral Ops
	# Gain an extra action point if starting turn adjacent to an island tile
	for hex in get_occupied_hexes():
		for neighbor in get_parent().get_parent().grid.get_all_hex_neighbors(hex[0], hex[1]):
			if get_parent().get_parent().grid.grid[neighbor[0]][neighbor[1]].island:
				print('passive - littoral ops')
				ap = 5
				break

func hit(hit_hex, from_ship):
	.hit(hit_hex, from_ship)
	randomize()
	# Drawback - Fragile
	# 75% chance of sinking if hit in either hex
	if rand_range(0, 1) < 0.75:
		print('drawback - fragile')
		sink()
