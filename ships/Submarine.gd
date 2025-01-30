extends Ship

class_name Submarine

const projectile_node = preload('res://ships/projectiles/Torpedo.tscn')
const nuke_node = preload('res://ships/projectiles/Nuke.tscn')
const pulse_node = preload('res://ships/projectiles/SonarPulse.tscn')
const sonar_sound = preload('res://audio/sonar.wav')

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
	self.sink_sound = preload('res://audio/sub_destroyed.wav')
	self.move_sound = preload('res://audio/sub_movement.ogg')

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

# Submarines cannot shoot at land tiles
func can_fire(aim_hex = [15, 0]):
	return .can_fire(aim_hex) and not root.grid.grid[aim_hex[0]][aim_hex[1]].island

func fire(target_x, target_y):
	.fire(target_x, target_y)
	var projectile = projectile_node.instance()
	root.add_child(projectile)
	var torpedo_position = global_position - Vector2(0, 42).rotated(rotation)
	projectile.init(torpedo_position, [target_x, target_y], abs(get_parent().player_num - 1), global_rotation)
	yield(projectile, 'done')
	emit_signal('fire_animation_complete')

func use_special(target_x, target_y):
	.use_special(target_x, target_y)
	var nuke = nuke_node.instance()
	nuke.scale = Vector2(2, 2)
	root.add_child(nuke)
	nuke.init(global_position + Vector2(0, -25).rotated(rotation), [target_x, target_y], abs(get_parent().player_num - 1), global_rotation_degrees)
	yield(nuke, 'done')
	emit_signal('special_animation_complete')

func use_secondary(target_x, target_y):
	.use_secondary(target_x, target_y)
	# Play sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = sonar_sound
	audio_player.play()
	var pulse_location = root.grid.get_hex_center(target_x, target_y)
	var pulse = pulse_node.instance()
	root.add_child(pulse)
	pulse.init(pulse_location)
	yield(pulse, 'done')
	emit_signal('special_animation_complete')
	yield(audio_player, 'finished')
	audio_player.queue_free()
