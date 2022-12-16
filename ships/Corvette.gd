extends Ship

class_name Corvette

var projectile_node = preload('res://ships/projectiles/BattleshipProjectile.tscn')

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

func fire(target_x, target_y):
	.fire(target_x, target_y)
	# Rotate turret to point at target
	var turret = get_node('Turret')
	var new_angle_rad = turret.global_position.angle_to_point(
		get_parent().get_parent().grid.get_hex_center(target_x, target_y))
	var new_angle_deg = new_angle_rad * 180 / PI - 90
	var old_angle_deg = turret.global_rotation_degrees
	if new_angle_deg < 0:
		new_angle_deg += 360
	elif new_angle_deg >= 360:
		new_angle_deg -= 360
	if old_angle_deg < 0:
		old_angle_deg += 360
	elif old_angle_deg >= 360:
		old_angle_deg -= 360
	turret.global_rotation_degrees = new_angle_deg
	var tween = Tween.new()
	tween.interpolate_property(turret, 'global_rotation_degrees', old_angle_deg, new_angle_deg, 0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()
	yield(tween, 'tween_completed')
	var projectile = projectile_node.instance()
	projectile.scale = Vector2(0.5, 0.5)
	root.add_child(projectile)
	projectile.init(turret.global_position + Vector2(0, -20).rotated(turret.global_rotation), [target_x, target_y], abs(get_parent().player_num - 1))
	yield(projectile, 'done')
	emit_signal('fire_animation_complete')
	emit_signal('fire_animation_complete')
