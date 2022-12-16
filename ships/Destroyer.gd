extends Ship

class_name Submarine

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'destroyer'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Destroyer'
	self.weapon = 'Anti-Ship Missile'
	self.special = SpecialAbility.new(4, 'ASW Strike',
	'Select a hex on opponent\'s board; if the hex or any of its direct neighbors contacts an enemy submarine, sink it instantly (does not affect ships)', 1)
	self.secondary = SpecialAbility.new(5, 'Lay Mine', 'Select a hex on opponent\'s board to place a mine; if any ships move over that tile, they will take a hit in a random hex', 0)

func fire(target_x, target_y):
	.fire(target_x, target_y)
	emit_signal('fire_animation_complete')

func use_special(target_x, target_y):
	.use_special(target_x, target_y)
	emit_signal('special_animation_complete')

func use_secondary(target_x, target_y):
	.use_secondary(target_x, target_y)
	emit_signal('special_animation_complete')
