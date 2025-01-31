extends Ship

class_name Destroyer

const projectile_node = preload('res://ships/projectiles/Missile.tscn')

var sh60

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'destroyer'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Destroyer'
	self.weapon = 'Anti-Ship Missile'
	self.special = SpecialAbility.new(2, 'ASW Strike',
	'Select a hex on opponent\'s board; if the hex or any of its direct neighbors contacts an enemy submarine, sink it instantly (does not affect ships)', 1)
	self.secondary = SpecialAbility.new(3, 'Lay Mine', 'Select a hex on opponent\'s board to place a mine; if any ships move over that tile, they will take a hit in a random hex', 0)
	self.sh60 = $SH60
	self.move_sound = preload('res://audio/smallship.ogg')

func fire(target_x, target_y):
	.fire(target_x, target_y)
	sh60.instant_recall()
	var projectile = projectile_node.instance()
	projectile.scale = Vector2(2, 2)
	root.add_child(projectile)
	projectile.init(global_position + Vector2(0, -25).rotated(rotation), [target_x, target_y], abs(get_parent().player_num - 1), global_rotation_degrees)
	yield(projectile, 'done')
	emit_signal('fire_animation_complete')

func use_special(target_x, target_y):
	.use_special(target_x, target_y)
	sh60.instant_recall()
	sh60.bomb(target_x, target_y)
	yield(sh60, 'done')
	emit_signal('special_animation_complete')

func use_secondary(target_x, target_y):
	.use_secondary(target_x, target_y)
	sh60.instant_recall()
	sh60.mine(target_x, target_y)
	yield(sh60, 'done')
	emit_signal('special_animation_complete')
