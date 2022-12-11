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
	self.special = SpecialAbility.new(7, 'Salvo', 
	'Shoot one central hex and damage whatever it contains as well as all of its immediate neighbors; if central hex is a damaged hex, sink the enemy ship instantly', 1)
	self.passive = PassiveAbility.new('Armor', 'Armor grants 25% chance of hits not counting')

func fire(target_x, target_y):
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
