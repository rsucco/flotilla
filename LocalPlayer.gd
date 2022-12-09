extends Player

class_name LocalPlayer

var selected_count
var getting_move = false
var ships_with_moves = []
var targeting_hex_range = 2


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(num).(num):
	pass

func _unhandled_input(event):
	# Only pay attention if it's our turn
	if get_parent().player_up == player_num:
		# Left mouse
		if event.is_pressed() and event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			var on_hex = get_parent().grid.get_hex_from_coords(event.position)
			var ship_at_hex = get_ship_at_hex(on_hex[0], on_hex[1])
			# Clicking on own grid
			if on_hex[0] in range(player_num * 16, player_num * 16 + 15):
				if ship_at_hex != null and get_parent().current_turn != 0:
					select_ship(ship_at_hex)
#				else:
#					select_ship(null)
			# Clicking on opponent's grid
			elif on_hex[0] in range(abs(player_num - 1) * 16, abs(player_num - 1) * 16 + 15):
				# Just deselecting for now; eventually targetting logic will go here
#				select_ship(null)
				pass

func _button_pressed(button):
	match button.name:
		'Fire':
			print('fire')
		'Special':
			print('special')
		'Secondary':
			print('secondary')
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

func end_turn():
	if selected_ship != null:
		print('ended turn for ', selected_ship)
		selected_ship.ap = 0
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
		# On opponent's half; return nothing if targeting_hex_range is -1
		if targeting_hex_range == -1:
			return []
		# Return all neighbors within targeting_hex_range hexes otherwise
		else:
			var hover_hexes = get_parent().grid.get_all_hex_neighbors(x, y, targeting_hex_range)
			hover_hexes.append([x, y])
			return hover_hexes

func select_ship(ship):
	if ship != null:
		# Move the ship to front of the line (if there is a ship, and if there is a
		# line, and if the ship isn't already at the front of the line)
		if len(ships_with_moves) > 0 and ships_with_moves[0] != ship:
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
	ships_with_moves = ships.duplicate()
	select_ship(ships_with_moves[0])

func get_move():
	getting_move = true
	for ship in ships_with_moves:
		if ship.ap == 0:
			ships_with_moves.remove(ships_with_moves.find(ship))
	select_ship(ships_with_moves[0])
	for button in get_parent().gui.get_tree().get_nodes_in_group('action_buttons'):
		button.connect('pressed', self, '_button_pressed', [button])

func disconnect_buttons():
	for button in get_parent().gui.get_tree().get_nodes_in_group('action_buttons'):
		button.disconnect('pressed', self, '_button_pressed')
