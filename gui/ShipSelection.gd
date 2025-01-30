extends PopupPanel

const points_budget = 25

const point_values = {
	'CoastalBattery': 2,
	'Corvette': 2,
	'Destroyer': 3,
	'Cruiser': 3,
	'Submarine': 3,
	'SupplyTender': 3,
	'Battleship': 4,
	'Carrier': 5
}

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

var island_tiles = 0

func _ready():
	for ship_type in point_values.keys():
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/Label').text += ' (' + str(point_values[ship_type]) + ' Points)'

func _on_CountSlider_value_changed(value):
	var used_points = 0
	for ship_type in selected_count.keys():
		selected_count[ship_type] = get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').value
		# Update slider values
		var count_label_text = str(selected_count[ship_type]) + ' (' + str(selected_count[ship_type] * point_values[ship_type]) + ' Points)'
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountLabel').text = count_label_text
		used_points += selected_count[ship_type] * point_values[ship_type]
	# Ensure that no sliders are allowed to exceed the max points
	for ship_type in selected_count.keys():
		var already_spent_points = selected_count[ship_type] * point_values[ship_type]
		var max_slider_value = int((points_budget - used_points + already_spent_points) / point_values[ship_type])
		if ship_type == 'Coastal Battery':
			max_slider_value = min(max_slider_value, island_tiles)
		var slider_value = min(max_slider_value, 5)
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').max_value = slider_value
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').tick_count = slider_value + 1
	get_node('VBoxContainer/SelectionGrid/Points/PointsUsed').text = str(used_points) + '/' + str(points_budget)
	get_node('VBoxContainer/Buttons/OK').disabled = (used_points == 0)

	
func _on_Reset_pressed():
	for ship_type in selected_count.keys():
		var written_ship_type
		if ship_type == 'CoastalBattery':
			written_ship_type = 'Coastal Battery'
		else:
			written_ship_type = ship_type
		selected_count[ship_type] = 0
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').value = 0
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/Label').text = written_ship_type + ' (' + str(point_values[ship_type]) + ' Points)'
		get_node('VBoxContainer/SelectionGrid/Points/PointsUsed').text = '0/' + str(points_budget)

func _on_OK_pressed():
	get_parent().selected_count = selected_count
	queue_free()

func set_island_tiles(num_tiles):
	island_tiles = num_tiles
	get_node('VBoxContainer/SelectionGrid/CoastalBattery/CountSlider').max_value = island_tiles
	get_node('VBoxContainer/SelectionGrid/CoastalBattery/CountSlider').tick_count = island_tiles + 1


func _on_Classic_pressed():
	# Reset them to 0 before setting them to 1, otherwise the value_changed signal gets confused
	for ship_type in selected_count.keys():
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').value = 0
	for ship_type in selected_count.keys():
		get_node('VBoxContainer/SelectionGrid/' + ship_type + '/CountSlider').value = 1
