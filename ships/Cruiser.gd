extends Ship

class_name Cruiser

const projectile_node = preload('res://ships/projectiles/Missile.tscn')
const ew_node = preload('res://ships/projectiles/EWStrike.tscn')
var silo_up = 0

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
	self.move_sound = preload('res://audio/smallship.ogg')

func fire(target_x, target_y):
	.fire(target_x, target_y)
	var projectile = projectile_node.instance()
	projectile.scale = Vector2(2, 2)
	root.add_child(projectile)
	var silo_vector
	if silo_up == 0:
		silo_vector = Vector2(0, -24).rotated(rotation)
		silo_up = 1
	else:
		silo_vector = Vector2(0, 40).rotated(rotation)
		silo_up = 0
	projectile.init(global_position + silo_vector, [target_x, target_y], abs(get_parent().player_num - 1), global_rotation_degrees)
	yield(projectile, 'done')
	emit_signal('fire_animation_complete')

func use_special(target_x, target_y):
	.use_special(target_x, target_y)
	var ew_location = root.grid.get_hex_center(target_x, target_y)
	var ew = ew_node.instance()
	root.add_child(ew)
	ew.init(ew_location)
	yield(ew, 'done')
	emit_signal('special_animation_complete')

func use_secondary(target_x, target_y):
	.use_secondary(target_x, target_y)
	emit_signal('special_animation_complete')
