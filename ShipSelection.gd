extends PopupDialog


var selected_count = {
	'CoastalBattery': 0,
	'Corvette': 0,
	'Destroyer': 0,
	'Cruiser': 0,
	'Submarine': 0,
	'SupplyTender': 0,
	'Battleship': 0,
	'Carrier': 0
	}


func _on_CountSlider_value_changed(value):
	for ship_type in selected_count.keys():
		selected_count[ship_type] = get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').value
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountLabel').text = str(selected_count[ship_type])
	var used_points = 0
	for value in selected_count.values():
		used_points += value
	get_node('VBoxContainer/SelectionGrid/Points/PointsUsed').text = str(used_points) + '/25'

func _on_Reset_pressed():
	for ship_type in selected_count.keys():
		selected_count[ship_type] = 0
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').value = 0
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountLabel').text = '0'
		get_node('VBoxContainer/SelectionGrid/Points/PointsUsed').text = '0/25'

func _on_OK_pressed():
	get_parent().selected_count = selected_count
	queue_free()
