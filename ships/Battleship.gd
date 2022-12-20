extends Ship

class_name Battleship

signal turrets_pointed

const projectile_node = preload('res://ships/projectiles/BattleshipProjectile.tscn')
var turret_up = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 2
	self.ship_type = 'battleship'
	self.hit_hexes = [false, false, false, false]
	self.ship_name = 'Battleship'
	self.weapon = 'Big Gun'
	self.special = SpecialAbility.new(7, 'Salvo', 
	'Shoot one central hex and damage whatever it contains as well as all of its immediate neighbors; if central hex is a damaged hex, sink the enemy ship instantly', 1)
	self.passive = PassiveAbility.new('Armor', 'Armor grants 25% chance of hits not counting')

func fire(target_x, target_y):
	.fire(target_x, target_y)
	point_turrets(target_x, target_y)
	yield(self, 'turrets_pointed')
	var projectile = projectile_node.instance()
	var turret = get_node('Turret' + str(turret_up))
	turret_up += 1
	if turret_up == 4:
		turret_up = 0
	root.add_child(projectile)
	projectile.init(turret.global_position + Vector2(0, -20).rotated(turret.global_rotation), [target_x, target_y], abs(get_parent().player_num - 1))
	yield(projectile, 'done')
	emit_signal('fire_animation_complete')

func hit(hit_hex, from_ship):
	randomize()
	# Passive ability - Armor
	# 25% chance of a hit not counting
	if rand_range(0, 1) > 0.25:
		.hit(hit_hex, from_ship)
	else:
		root.grid.grid[hit_hex[0]][hit_hex[1]].history.append(
			[root.current_turn, 'Miss (Blocked by Armor)'])

func use_special(target_x, target_y):
	.use_special(target_x, target_y)
	point_turrets(target_x, target_y)
	yield(self, 'turrets_pointed')
	var target_hexes = root.grid.get_all_hex_neighbors(target_x, target_y, special.aoe)
	# We want the first and last turret to both shoot at the center hex,
	# so add it to the beginning and end of the array
	target_hexes.append([target_x, target_y])
	target_hexes.push_front([target_x, target_y])
	# Divert shots to center hex if they'd otherwise go out of bounds
	while len(target_hexes) < 8:
		target_hexes.append([target_x, target_y])
	for i in range(0, 8, 2):
		print(target_hexes[i], ', ', target_hexes[i+1])
		var turret = get_node('Turret' + str(i / 2))
		var projectile1 = projectile_node.instance()
		root.add_child(projectile1)
		projectile1.init(turret.global_position + Vector2(-5, -20).rotated(turret.global_rotation), [target_hexes[i][0], target_hexes[i][1]], abs(get_parent().player_num - 1))
		var projectile2 = projectile_node.instance()
		root.add_child(projectile2)
		projectile2.init(turret.global_position + Vector2(5, -20).rotated(turret.global_rotation), [target_hexes[i + 1][0], target_hexes[i + 1][1]], abs(get_parent().player_num - 1))
		if i == 6:
			yield(projectile2, 'done')
	emit_signal('special_animation_complete')

func point_turrets(target_x, target_y):
	# Rotate turrets to point at target
	for i in range(4):
		var turret = get_node('Turret' + str(i))
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
		tween.interpolate_property(turret, 'global_rotation_degrees', old_angle_deg, new_angle_deg, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		add_child(tween)
		tween.start()
		if i == 3:
			yield(tween, 'tween_completed')
	emit_signal('turrets_pointed')
