extends Sprite

class_name Ship

signal placed
signal fire_animation_complete
signal special_animation_complete

var hit_sound = preload('res://audio/water_hit1.wav')
var sink_sound = preload('res://audio/ship_destroyed.wav')
const SHIP_TYPES = ['coastal_battery', 'corvette', 'destroyer', 'submarine', 'cruiser', 'supply_tender', 'battleship', 'carrier']
var direction = 0
var root
var default_ap = 4
var ap = 0
var len_fore
var len_aft
var x = -10
var y = -10
var ship_type = ''
var hit_hexes = []
var smoke_nodes = []
var ship_name = ''
var weapon = ''
var special = SpecialAbility.new()
var secondary = SpecialAbility.new()
var passive = PassiveAbility.new()
var drawback = Drawback.new()
var selected = false
var placing = false
var fire_remaining = 0
var move_sound
var movement_audio_player
var moves_queued = 0
var revealed_buddy = null

# Called when the node enters the scene tree for the first time.
func _ready():
	root = get_parent().get_parent()
	movement_audio_player = AudioStreamPlayer2D.new()
	add_child(movement_audio_player)

func set_grid_position(x, y, direction):
	self.direction = direction
	self.set_rotation_degrees(direction)
	self.x = x
	self.y = y
	self.position = root.grid.get_hex_center(self.x, self.y)

func _input(event):
	if placing:
		if event is InputEventMouseMotion:
			var mouse_position = root.grid.get_hex_from_coords(event.position)
			var occupied_hexes = get_occupied_hexes(mouse_position[0], mouse_position[1])
			var any_land = false
			var already_occupied = false
			for hex in occupied_hexes:
				if root.grid.grid[hex[0]][hex[1]].island:
					any_land = true
				if root.get_ship_at_hex(hex[0], hex[1]) != null:
					already_occupied = true
			if ship_type == 'coastal_battery':
				any_land = !any_land
			if !occupied_hexes.has([-1, -1]) and !any_land and !already_occupied and \
			mouse_position[0] in range(get_parent().player_num * 16, get_parent().player_num * 16 + 15):
				set_grid_position(mouse_position[0], mouse_position[1], direction)
		elif event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				self.rotate(-60)
			elif event.button_index == BUTTON_WHEEL_DOWN:
				self.rotate(60)
			elif event.button_index == BUTTON_LEFT and x != -10 and y != -10:
				placing = false
				emit_signal('placed')

func get_occupied_hexes(on_x = self.x, on_y = self.y, in_dir = self.direction):
	var occupied_hexes = [[on_x, on_y]]
	for _i in range(len_aft):
		occupied_hexes.append(root.grid.get_hex_neighbor(
			occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir + 180))
	occupied_hexes.remove(0)
	occupied_hexes.invert()
	occupied_hexes.append([on_x, on_y])
	for _i in range(len_fore):
		occupied_hexes.append(root.grid.get_hex_neighbor(
			occupied_hexes[-1][0], occupied_hexes[-1][1], in_dir))
	return occupied_hexes

func get_size():
	return self.len_aft + self.len_fore + 1

func new_turn():
	modulate = Color.white
	ap = default_ap
	fire_remaining = 1
	if special.cooldown_current > 0:
		special.cooldown_current -= 1
	if secondary.cooldown_current > 0:
		secondary.cooldown_current -= 1

func place():
	movement_audio_player.stream = move_sound
	placing = true

func hit(hit_hex, from_ship):
	var hit_hex_index = self.get_occupied_hexes().find(hit_hex)
	# Don't count hits on already hit hexes (maybe rework this if it's unfun)
	if hit_hexes[hit_hex_index]:
		root.grid.grid[hit_hex[0]][hit_hex[1]].history.append(
			[root.current_turn, 'Hit, ' + ship_name + ' (No effect)'])
	else:
		hit_hexes[hit_hex_index] = true
		if hit_hexes.count(true) >= len(hit_hexes) / 2:
			root.grid.grid[hit_hex[0]][hit_hex[1]].history.append(
				[root.current_turn, 'Hit, ' + ship_name + ' (Immobilized)'])
		else:
			root.grid.grid[hit_hex[0]][hit_hex[1]].history.append(
				[root.current_turn, 'Hit, ' + ship_name])
		var smoke = Particles2D.new()
		var smoke_material = ParticlesMaterial.new()
		smoke_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_RING
		smoke_material.emission_ring_radius = self.get_size() * 3 - 3
		smoke_material.direction = Vector3(-50, 0, 0)
		smoke_material.gravity = Vector3(0, 150, 0)
		smoke_material.spread = 25.0
		smoke_material.damping = -1.5
		smoke_material.scale = 2.5
		smoke_material.color = Color(0.0, 0.0, 0.0)
		smoke.process_material = smoke_material
		smoke.amount = pow(self.get_size(), 2) * 10
		smoke.lifetime = 0.5
		var hex_size = root.grid.hex_size
		smoke.position -= Vector2(0, hex_size * (hit_hex_index - len_aft))
		if len_fore == 0:
			smoke.position -= Vector2(0, 10)
		elif len_fore == 2:
			if hit_hex_index == 0:
				smoke.position -= Vector2(0, 10)
			elif hit_hex_index == 4:
				smoke.position += Vector2(0, 15)
		smoke_nodes.append(smoke)
		add_child(smoke)
		if not false in hit_hexes:
			self.sink()
		else:
			# Play hit sound
			var audio_player = AudioStreamPlayer2D.new()
			add_child(audio_player)
			audio_player.stream = hit_sound
			audio_player.play()
			yield(audio_player, 'finished')
			audio_player.queue_free()

func sink():
	if revealed_buddy != null and is_instance_valid(revealed_buddy):
		revealed_buddy.queue_free()
	# Play sink sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = sink_sound
	audio_player.play()
	# Play sink animation
	# Make visible to opponent
	visible = true
	var tween = Tween.new()
	tween.interpolate_property(self, 'modulate', Color(1.0, 1.0, 1.0), Color(0.0, 0.5, 0.62, 0.5), 3.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()
	for hex in get_occupied_hexes():
		root.grid.grid[hex[0]][hex[1]].history.append([root.current_turn, 'Sunk, ' + ship_name])
	get_parent().ships.remove(get_parent().ships.find(self))
	root.gui.update_fleets()
	yield(tween, 'tween_completed')
	visible = false
	yield(audio_player, 'finished')
	queue_free()

func rotate(rotation_offset):
	moves_queued += 1
	if not movement_audio_player.playing:
		movement_audio_player.play()
	var rotated_hexes = get_occupied_hexes(self.x, self.y, self.direction + rotation_offset)
	var any_land = false
	var already_occupied = false
	for hex in rotated_hexes:
		if root.grid.grid[hex[0]][hex[1]].island:
			any_land = true
		var ship_at_hex = root.get_ship_at_hex(hex[0], hex[1])
		if ship_at_hex != null and ship_at_hex != self:
			already_occupied = true
	if not [-1, -1] in rotated_hexes and !any_land and !already_occupied:
		self.direction += rotation_offset
		var tween = Tween.new()
		tween.interpolate_property(self, 'rotation_degrees', self.rotation_degrees, self.direction, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		add_child(tween)
		tween.start()
		yield(tween, 'tween_completed')
		moves_queued -= 1
		if moves_queued == 0:
			movement_audio_player.stop()

func is_hex_hit(hex):
	return hit_hexes[self.get_occupied_hexes().find(hex)]

# Returns true if moving 1 hex forward in the current direction would not result
# in the ship colliding with another ship, an island, or going out of bounds, and
# if the ship is not too damaged
func can_move(reverse = false, distance = 1):
	# Make sure the ship is less than 50% damaged
	if hit_hexes.count(true) >= len(hit_hexes) / 2:
		return false
	# Make sure we have sufficient action points for this move
	if ap < distance or (reverse and ap < 4):
		return false
	var new_hex
	# Get potential new center hex
	if !reverse:
		new_hex = root.grid.get_hex_neighbor(x, y, direction, distance)
	else:
		new_hex = root.grid.get_hex_neighbor(x, y, direction + 180, distance)
	# Get potential new occupied hexes
	var occupied_hexes = get_occupied_hexes(new_hex[0], new_hex[1])
	# Don't go out of bounds
	if [-1, -1] in occupied_hexes:
		return false
	# Don't allow moving into an island tile or another ship
	for hex in occupied_hexes:
		var ship_at_hex = root.get_ship_at_hex(hex[0], hex[1])
		if root.grid.grid[hex[0]][hex[1]].island or \
		(ship_at_hex != null and ship_at_hex != self):
			return false
	return true

# Returns true if the ship can rotate by the specified number of degrees
func can_rotate(rotation_offset):
	# Make sure the ship is less than 50% damaged
	if hit_hexes.count(true) >= len(hit_hexes) / 2:
		return false
	# 2 AP required to rotate
	if ap < 2:
		return false
	# Get potential new occupied hexes
	var occupied_hexes = get_occupied_hexes(x, y, direction + rotation_offset)
	# Don't go out of bounds
	if [-1, -1] in occupied_hexes:
		return false
	# Don't allow moving into an island tile or another ship
	for hex in occupied_hexes:
		var ship_at_hex = root.get_ship_at_hex(hex[0], hex[1])
		if root.grid.grid[hex[0]][hex[1]].island or \
		(ship_at_hex != null and ship_at_hex != self):
			return false
	return true

# Return true if a ship can fire
func can_fire(aim_hex = [0, 0]):
	# 2 AP and 1 fire action required to fire
	if ap >= 2 and fire_remaining >= 1:
		return true
	else:
		return false

func can_special():
	if special.desc == '' or special.cooldown_current != 0 or ap < 2:
		return false
	else:
		return true

func can_secondary():
	if secondary.desc == '' or secondary.cooldown_current != 0 or ap < 2:
		return false
	else:
		return true

func forward():
	moves_queued += 1
	if not movement_audio_player.playing:
		movement_audio_player.play()
	var new_hex = root.grid.get_hex_neighbor(x, y, direction)
	self.x = new_hex[0]
	self.y = new_hex[1]
	self.ap -= 1
	var tween = Tween.new()
	tween.interpolate_property(self, 'position', position, root.grid.get_hex_center(self.x, self.y), 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()
	check_for_mine()
	yield(tween, 'tween_completed')
	moves_queued -= 1
	if moves_queued == 0:
		movement_audio_player.stop()

func reverse():
	moves_queued += 1
	if not movement_audio_player.playing:
		movement_audio_player.play()
	var new_hex = root.grid.get_hex_neighbor(x, y, direction + 180)
	self.x = new_hex[0]
	self.y = new_hex[1]
	self.ap -= 4
	var tween = Tween.new()
	tween.interpolate_property(self, 'position', position, root.grid.get_hex_center(self.x, self.y), 2.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()
	check_for_mine()
	yield(tween, 'tween_completed')
	moves_queued -= 1
	if moves_queued == 0:
		movement_audio_player.stop()

func port():
	rotate(-60)
	self.ap -= 2
	check_for_mine()

func starboard():
	rotate(60)
	self.ap -= 2
	check_for_mine()

func check_for_mine():
	for hex in get_occupied_hexes():
		if root.grid.grid[hex[0]][hex[1]].is_mined:
			root.grid.grid[hex[0]][hex[1]].is_mined = false
			for ship_hex in get_occupied_hexes():
				if !is_hex_hit(ship_hex):
					hit(ship_hex, self)
					break

func fire(target_x, target_y):
	ap -= 2
	fire_remaining -= 1

func use_special(target_x, target_y):
	ap -= 2
	special.cooldown_current = special.cooldown_interval

func use_secondary(target_x, target_y):
	ap -= 2
	secondary.cooldown_current = secondary.cooldown_interval

func heal():
	var healed_hexes = []
	for i in range(len(hit_hexes)):
		healed_hexes.append(false)
	hit_hexes = healed_hexes
	for smoke in smoke_nodes:
		remove_child(smoke)
		smoke.queue_free()
	smoke_nodes = []
