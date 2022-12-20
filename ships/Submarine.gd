extends Ship

class_name Submarine

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'submarine'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Submarine'
	self.weapon = 'Torpedo'
	self.special = SpecialAbility.new(15, 'Nuclear Strike',
	'Select a hex on opponent\'s board; instantly sinks any unit it hits directly and damages all hexes within two hexes of central hex', 2)
	self.secondary = SpecialAbility.new(1, 'Sonar Pulse',
	'Select a hex on opponent\'s board; reveals ships and submarines on that hex and its direct neighbors and also reveals the location of the submarine', 1)
	self.passive = PassiveAbility.new('Silent Service', 'Can only be hit by surface units on center hex')
	self.drawback = Drawback.new('Crushing Depths', 
	'Sinks instantly when hit in center hex by surface unit, or when hit in any hex by ASW Strike, mine, or another sub') 

func hit(hit_hex, from_ship):
	# Drawback - Crushing Depths
	# Sink instantly when hit in center hex or in any hex by another sub or a mine
	if hit_hex == [x, y] or from_ship.ship_type == 'submarine':
		print('drawback - crushing depths')
		sink()
	else:
		get_parent().get_parent().grid.grid[hit_hex[0]][hit_hex[1]].history.append(
			[get_parent().get_parent().current_turn, 'Miss'])
		print('passive - silent service')
		# Passive ability - Silent Service
		# If hit on non-center hex by a surface unit, hit doesn't count

func fire(target_x, target_y):
	.fire(target_x, target_y)
	emit_signal('fire_animation_complete')

func use_special(target_x, target_y):
	.use_special(target_x, target_y)
	emit_signal('special_animation_complete')

func use_secondary(target_x, target_y):
	.use_secondary(target_x, target_y)
	emit_signal('special_animation_complete')
