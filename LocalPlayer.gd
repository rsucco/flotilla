extends Player

class_name LocalPlayer

var selected_count
var selected_ship = null
var getting_move = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(num).(num):
	pass

func _input(event):
	if event.is_pressed() and event.button_index == BUTTON_LEFT:
		pass
		#print('click player')

func place_ships(ship_counts):
	for ship_type in ship_counts:
		for i in range(ship_counts[ship_type]):
			print('placing ', ship_type, ' #', i)
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

func get_move():
	print('getting move')
	getting_move = true
	
