extends Player

class_name LocalPlayer

const TILE_HIST_HOVER_TIME = .5
var selected_count
var aiming = {'fire': false, 'special': false, 'secondary': false, 'recon': false}
var ships_with_moves = []
var targeting_hex_range = -1
var current_on_hex = [-1, -1]
var on_hex_time = 0
var tile_history

# Called when the node enters the scene tree for the first time.
func _ready():
	tile_history = get_parent().get_node('TileHistory')

func _init(num).(num):
	pass

func _unhandled_input(event):
	# Only pay attention if it's our turn
	if get_parent().player_up == player_num:
		# Keyboard input
		if event is InputEventKey:
			return
		var on_hex = get_parent().grid.get_hex_from_coords(event.position)
		var ship_at_hex = get_ship_at_hex(on_hex[0], on_hex[1])
		# Click
		if event.is_pressed() and event is InputEventMouseButton:
			# Left click
			if event.button_index == BUTTON_LEFT:
				# Left-clicking on own grid
				if on_hex[0] in range(player_num * 16, player_num * 16 + 15):
					if ship_at_hex != null and get_parent().current_turn != 0:
						select_ship(ship_at_hex)
				# Left-clicking on opponent's grid
				elif on_hex[0] in range(abs(player_num - 1) * 16, abs(player_num - 1) * 16 + 15):
					# If aiming for a shot or ability, call the relevant function
					if aiming['fire']:
						fire(on_hex[0], on_hex[1])
					elif aiming['special']:
						special(on_hex[0], on_hex[1])
					elif aiming['secondary']:
						secondary(on_hex[0], on_hex[1])
			# Right click
			elif event.button_index == BUTTON_RIGHT:
				select_ship(null)
		# Mouse motion on opponent's grid
		elif event is InputEventMouseMotion and get_parent().current_turn > 0:
			if on_hex[0] in range(abs(player_num - 1) * 16, abs(player_num - 1) * 16 + 15):
				# Reset history popup timer if we've moved outside opponent's grid
				if on_hex != current_on_hex:
					current_on_hex = on_hex
					if on_hex_time < TILE_HIST_HOVER_TIME:
						on_hex_time = 0
			else:
				current_on_hex = [-1, -1]
				tile_history.visible = false

func _process(delta):
	if current_on_hex[0] in range(abs(player_num - 1) * 16, abs(player_num - 1) * 16 + 15):
		on_hex_time += delta
	else:
		on_hex_time = 0
	# Show history popup if we've been on the same hex for 3 seconds
	if on_hex_time > TILE_HIST_HOVER_TIME and get_parent().current_turn > 0 and \
	get_parent().player_up == player_num and current_on_hex != [-1, -1]:
		tile_history.show_history(current_on_hex)
		if !tile_history.visible:
			tile_history.show()

func _button_pressed(button):
	match button.name:
		'Fire':
			aim_fire()
		'Special':
			aim_special()
		'Secondary':
			aim_secondary()
		'EndTurn':
			end_turn()
		'Forward':
			forward()
		'Port':
			port()
		'Starboard':
			starboard()
		'Reverse':
			reverse()

func aim_fire():
	if selected_ship != null and selected_ship.can_fire():
		aiming['special'] = false
		aiming['secondary'] = false
		aiming['recon'] = false
		aiming['fire'] = true
		targeting_hex_range = 0

func aim_special():
	if selected_ship != null and selected_ship.can_special():
		# Supply Tenders don't aim their UNREP ability
		if selected_ship.ship_type == 'supply_tender':
			special(selected_ship.x, selected_ship.y)
		else:
			aiming['fire'] = false
			aiming['secondary'] = false
			if selected_ship.special.name == 'Recon Flight':
				aiming['recon'] = true
			else:
				aiming['recon'] = false
			aiming['special'] = true
			targeting_hex_range = selected_ship.special.aoe

func aim_secondary():
	if selected_ship != null and selected_ship.can_secondary():
		aiming['fire'] = false
		aiming['special'] = false
		aiming['recon'] = false
		aiming['secondary'] = true
		targeting_hex_range = selected_ship.secondary.aoe

# Fire at an enemy hex with the selected ship
func fire(x, y):
	if selected_ship != null and selected_ship.can_fire([x, y]):
		# Play fire animation
		selected_ship.fire(x, y)
		yield(selected_ship, 'fire_animation_complete')
		# Send fire event to other player for tracking
		var is_hit = get_parent().players[abs(player_num - 1)].receive_fire(x, y, selected_ship)
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')

func special(x, y):
	if selected_ship != null and selected_ship.can_special():
		# Play special animation
		selected_ship.use_special(x, y)
		yield(selected_ship, 'special_animation_complete')
		# Send special to other player to check for hits
		var hits = get_parent().players[abs(player_num - 1)].receive_special(x, y, selected_ship)
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')

func secondary(x, y):
	if selected_ship != null and selected_ship.can_secondary():
		# Play animation
		selected_ship.use_secondary(x, y)
		yield(selected_ship, 'special_animation_complete')
		# Send secondary to other player to check for hits
		var hits = get_parent().players[abs(player_num - 1)].receive_special(x, y, selected_ship, true)
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')


func end_turn():
	if selected_ship != null:
		selected_ship.ap = 0
		emit_signal('made_move')

func forward():
	if selected_ship != null and selected_ship.can_move():
		selected_ship.forward()
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')

func reverse():
	if selected_ship != null and selected_ship.can_move(true):
		selected_ship.reverse()
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')

func port():
	if selected_ship != null and selected_ship.can_rotate(-60):
		selected_ship.port()
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')

func starboard():
	if selected_ship != null and selected_ship.can_rotate(60):
		selected_ship.starboard()
		update_buttons(selected_ship)
		get_parent().gui.update_ship_info(selected_ship)
		emit_signal('made_move')

func get_hover_hexes(x, y):
	# Check if hex is on our half of the board
	if x in range(16 * player_num, 16 * player_num + 15):
		# On our half, don't bother with area of effect
		return [[x, y]]
	# Border; don't do anything
	elif x == 15:
		return []
	else:
		# On opponent's half
		# Recon flight covers the entire row
		if aiming['recon']:
			var hover_hexes = []
			for i in range(abs(get_parent().player_up - 1) * 16, abs(get_parent().player_up - 1) * 16 + 15):
				hover_hexes.append([i, y])
			return hover_hexes
		# Return nothing if targeting_hex_range is -1
		elif targeting_hex_range == -1:
			return []
		# Return all neighbors within targeting_hex_range hexes otherwise
		else:
			var hover_hexes = get_parent().grid.get_all_hex_neighbors(x, y, targeting_hex_range)
			hover_hexes.append([x, y])
			return hover_hexes

func select_ship(ship):
	aiming['fire'] = false
	aiming['special'] = false
	aiming['recon'] = false
	aiming['secondary'] = false
	targeting_hex_range = -1
	if ship != null:
		# Move the ship to front of the line (if there is a ship, and if there is a
		# line, and if the ship isn't already at the front of the line)
		if len(ships_with_moves) > 0 and ships_with_moves[0] != ship and ship.ap > 0:
			ships_with_moves.remove(ships_with_moves.find(ship))
			ships_with_moves.push_front(ship)
		update_buttons(ship)
	else:
		for button in get_parent().gui.get_tree().get_nodes_in_group('action_buttons'):
			button.disabled = true
	selected_ship = ship
	get_parent().gui.update_ship_info(ship)

func update_buttons(ship):
	# Reset buttons
	for button in get_parent().gui.get_tree().get_nodes_in_group('action_buttons'):
		button.disabled = false
	# Check if ship can move forward
	if !ship.can_move():
		get_parent().gui.disable_button('Forward')
	# Check if ship can reverse
	if !ship.can_move(true):
		get_parent().gui.disable_button('Reverse')
	# Check if ship can rotate to port (-60 degrees)
	if !ship.can_rotate(-60):
		get_parent().gui.disable_button('Port')
	# Check if ship can rotate to starboard (+60 degrees)
	if !ship.can_rotate(60):
		get_parent().gui.disable_button('Starboard')
	# Check if ship can fire
	if !ship.can_fire():
		get_parent().gui.disable_button('Fire')
	# Check if ship can use special ability
	if !ship.can_special():
		get_parent().gui.disable_button('Special')
	# Check if ship can use secondary ability
	if !ship.can_secondary():
		get_parent().gui.disable_button('Secondary')

func place_ships(ship_counts):
	for ship_type in ship_counts:
		for i in range(ship_counts[ship_type]):
			var ship = load('res://ships/' + ship_type + '.tscn').instance()
			add_child(ship)
			ship.place()
			yield(ship, 'placed')
			ships.append(ship)
	emit_signal('ships_placed')

func get_ship_selection():
	var select_dialog = preload('res://ShipSelection.tscn').instance()
	select_dialog.get_node('VBoxContainer/Label').text = 'Player ' + str(player_num + 1) + ', choose your ships:'
	var num_island_tiles = get_parent().grid.get_num_island_tiles(player_num)
	select_dialog.get_node('VBoxContainer/SelectionGrid/CoastalBattery/CountSlider').max_value = num_island_tiles
	select_dialog.get_node('VBoxContainer/SelectionGrid/CoastalBattery/CountSlider').tick_count = num_island_tiles + 1
	add_child(select_dialog)
	select_dialog.popup()
	yield(select_dialog, 'popup_hide')
	emit_signal('ships_selected')
	return selected_count

func new_turn():
	.new_turn()
	# Show our ships
	for ship in ships:
		ship.visible = true
	# Hide opponent's ships
	for other_ship in get_parent().players[abs(player_num - 1)].ships:
		other_ship.visible = false
	ships_with_moves = ships.duplicate()
	select_ship(ships_with_moves[0])
	on_hex_time = 0

func get_move():
	aiming = {'fire': false, 'special': false, 'secondary': false, 'recon': false}
	targeting_hex_range = -1
	for ship in ships_with_moves:
		if ship.ap == 0:
			ships_with_moves.remove(ships_with_moves.find(ship))
	select_ship(ships_with_moves[0])
	for button in get_parent().gui.get_tree().get_nodes_in_group('action_buttons'):
		button.connect('pressed', self, '_button_pressed', [button])

func disconnect_buttons():
	for button in get_parent().gui.get_tree().get_nodes_in_group('action_buttons'):
		button.disconnect('pressed', self, '_button_pressed')
