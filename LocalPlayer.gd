extends Player

class_name LocalPlayer

var selected_count


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(num).(num):
	pass

func get_ship_selection():
	var select_dialog = preload('res://ShipSelection.tscn').instance()
	select_dialog.get_node('VBoxContainer/Label').text = 'Player ' + str(player_num + 1) + ', choose your ships:'
	var num_island_tiles = get_parent().grid.get_num_island_tiles(player_num)
	select_dialog.get_node('VBoxContainer/SelectionGrid/CoastalBattery/CountSlider').max_value = num_island_tiles
	select_dialog.get_node('VBoxContainer/SelectionGrid/CoastalBattery/CountSlider').tick_count = num_island_tiles + 1
	add_child(select_dialog)
	select_dialog.popup()
	yield(select_dialog, 'popup_hide')
	return selected_count
