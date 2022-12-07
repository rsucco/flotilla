extends Player

class_name LocalPlayer

var selected_count
var selecting = false
var getting_move = false
var ships_with_moves = []


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(num).(num):
	pass

func _input(event):
	if event.is_pressed() and event.button_index == BUTTON_LEFT and get_parent().player_up == player_num:
		var on_hex = get_parent().grid.get_hex_from_coords(event.position)
		if on_hex[0] in range(player_num * 16, player_num * 16 + 15):
			var ship_at_hex = get_ship_at_hex(on_hex[0], on_hex[1])
			if ship_at_hex != null and get_parent().current_turn != 0:
				select_ship(ship_at_hex)
			else:
				select_ship(null)

func select_ship(ship):
	# Move the ship to front of the line
	if ship != null and len(ships_with_moves) > 0:
		ships_with_moves.remove(ships_with_moves.find(ship))
		ships_with_moves.push_front(ship)
	selected_ship = ship
	get_parent().gui.update_ship_info(ship)

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
	print('getting move')
	getting_move = true
	
	emit_signal('made_move')
