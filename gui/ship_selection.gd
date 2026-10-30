extends PanelContainer

# Emitted with {node name: count} when the player confirms
signal confirmed(counts: Dictionary)

const POINTS_BUDGET := 25
const MAX_PER_TYPE := 5

# Keyed by node name under SelectionGrid
const POINT_VALUES := {
	"CoastalBattery": 2,
	"Corvette": 2,
	"Destroyer": 3,
	"Cruiser": 3,
	"Submarine": 3,
	"SupplyTender": 3,
	"Battleship": 4,
	"Carrier": 5,
}

var selected_count := {}
var island_tiles := 0
var used_points := 0
var pending: Callable

@onready var grid: GridContainer = $VBoxContainer/SelectionGrid


func _ready() -> void:
	for ship_type: String in POINT_VALUES:
		selected_count[ship_type] = 0
		label(ship_type).text += " (" + str(POINT_VALUES[ship_type]) + " Points)"


func slider(ship_type: String) -> HSlider:
	return grid.get_node(ship_type + "/CountSlider")


func label(ship_type: String) -> Label:
	return grid.get_node(ship_type + "/Label")


func _on_CountSlider_value_changed(_value: float) -> void:
	used_points = 0
	for ship_type: String in POINT_VALUES:
		selected_count[ship_type] = int(slider(ship_type).value)
		var cost: int = selected_count[ship_type] * POINT_VALUES[ship_type]
		grid.get_node(ship_type + "/CountLabel").text = (
			str(selected_count[ship_type]) + " (" + str(cost) + " Points)"
		)
		used_points += cost
	# Don't let any slider exceed the remaining points
	for ship_type: String in POINT_VALUES:
		var already_spent: int = selected_count[ship_type] * POINT_VALUES[ship_type]
		@warning_ignore("integer_division")
		var max_count: int = (POINTS_BUDGET - used_points + already_spent) / POINT_VALUES[ship_type]
		if ship_type == "CoastalBattery":
			max_count = mini(max_count, island_tiles)
		max_count = mini(max_count, MAX_PER_TYPE)
		slider(ship_type).max_value = max_count
		slider(ship_type).tick_count = max_count + 1
	$VBoxContainer/SelectionGrid/Points/PointsUsed.text = (
		str(used_points) + "/" + str(POINTS_BUDGET)
	)
	$VBoxContainer/Buttons/OK.disabled = used_points == 0


func _on_Reset_pressed() -> void:
	for ship_type: String in POINT_VALUES:
		selected_count[ship_type] = 0
		slider(ship_type).value = 0
		label(ship_type).text = (
			ship_type.capitalize() + " (" + str(POINT_VALUES[ship_type]) + " Points)"
		)
	$VBoxContainer/SelectionGrid/Points/PointsUsed.text = "0/" + str(POINTS_BUDGET)


func _on_OK_pressed() -> void:
	if can_add_ship():
		ask("You have " + str(POINTS_BUDGET - used_points) + " points left. Start anyway?", _start)
	else:
		_start()


func _on_Title_pressed() -> void:
	ask(
		"Return to the title screen?",
		get_tree().change_scene_to_file.bind("res://title_screen.tscn")
	)


# Whether any leftover points could still buy a ship
func can_add_ship() -> bool:
	for ship_type: String in POINT_VALUES:
		if slider(ship_type).value < slider(ship_type).max_value:
			return true
	return false


# Swaps the buttons for a yes/no question; Yes runs `action`
func ask(question: String, action: Callable) -> void:
	pending = action
	$VBoxContainer/Buttons.visible = false
	$VBoxContainer/Confirm/Label.text = question
	$VBoxContainer/Confirm.visible = true


func _start() -> void:
	confirmed.emit(selected_count)
	queue_free()


func _on_Yes_pressed() -> void:
	pending.call()


func _on_No_pressed() -> void:
	$VBoxContainer/Confirm.visible = false
	$VBoxContainer/Buttons.visible = true


func set_island_tiles(count: int) -> void:
	island_tiles = count
	slider("CoastalBattery").max_value = count
	slider("CoastalBattery").tick_count = count + 1


func _on_Classic_pressed() -> void:
	# Reset to 0 before setting to 1, otherwise the value_changed signal gets confused
	for ship_type: String in POINT_VALUES:
		slider(ship_type).value = 0
	for ship_type: String in POINT_VALUES:
		slider(ship_type).value = 1
