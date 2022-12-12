extends Ship

class_name CoastalBattery

var hp

# Called when the node enters the scene tree for the first time.
func _ready():
	self.default_ap = 2
	self.len_fore = 0
	self.len_aft = 0
	self.ship_type = 'coastal_battery'
	self.hit_hexes = [false]
	self.hp = 5
	self.ship_name = 'Coastal Battery'
	self.weapon = 'Big Gun'
	self.passive = PassiveAbility.new('Fortified', 'Must be hit five times to destroy')
	self.drawback = Drawback.new('Stationary', 'Cannot move, reveals itself when firing')

func _draw():
	if get_parent().get_parent().current_turn != 0:
		draw_string(get_parent().get_parent().font, \
			Vector2(-8, -10), str(hp) + '/5', Color(0.0, 0.0, 0.0))

# Drawback - Stationary
# Coastal batteries can't move; always return false
func can_move(reverse = false, distance = 1):
	return false

# Coastal batteries have no need to rotate; always return false
func can_rotate(dir = 0):
	return false

func fire(target_x, target_y):
	# Rotate turrets to point at target
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
	tween.interpolate_property(turret, 'global_rotation_degrees', old_angle_deg, new_angle_deg, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()


# Coastal batteries have 5 HP rather than a set number of hexes to be hit
func hit(hit_hex, from_ship):
	hp -= 1
	if hp == 0:
		sink()
	else:
		print('passive - fortified')

# Don't rotate in placement screen either
func rotate(rotation_offset = 0):
	pass

func new_turn():
	.new_turn()
	update()
