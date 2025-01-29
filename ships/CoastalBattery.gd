extends Ship

class_name CoastalBattery

const projectile_node = preload('res://ships/projectiles/BattleshipProjectile.tscn')
const fire_sound = preload('res://audio/battleship.wav')
const turret_sound = preload('res://audio/artillery_rotate.wav')
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
	self.hit_sound = preload('res://audio/land_hit.wav')

# Drawback - Stationary
# Coastal batteries can't move; always return false
func can_move(reverse = false, distance = 1):
	return false

# Coastal batteries have no need to rotate; always return false
func can_rotate(dir = 0):
	return false

func fire(target_x, target_y):
	.fire(target_x, target_y)
	# Rotate turret to point at target
	# Play sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = turret_sound
	audio_player.play()
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
	yield(tween, 'tween_completed')
	# Stop rotation sound and play fire sound
	audio_player.stop()
	audio_player.stream = fire_sound
	audio_player.play()
	var projectile = projectile_node.instance()
	root.add_child(projectile)
	projectile.init(turret.global_position + Vector2(0, -20).rotated(turret.global_rotation), [target_x, target_y], abs(get_parent().player_num - 1))
	yield(projectile, 'done')
	emit_signal('fire_animation_complete')
	yield(audio_player, 'finished')
	audio_player.queue_free()


# Coastal batteries have 5 HP rather than a set number of hexes to be hit
func hit(hit_hex, from_ship):
	# Play hit sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = hit_sound
	audio_player.play()
	hp -= 1
	var hp_bar = get_node('HPBar')
	hp_bar.value = hp
	root.grid.grid[hit_hex[0]][hit_hex[1]].history.append(
	[root.current_turn, 'Hit, Coastal Battery (' + str(hp) + 'HP)'])
	if hp == 0:
		sink()
	else:
		print('passive - fortified')
	yield(audio_player, 'finished')
	audio_player.queue_free()

# Don't rotate in placement screen either
func rotate(_rotation_offset = 0):
	pass

func new_turn():
	.new_turn()
	update()
