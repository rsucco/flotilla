extends GutTest
# The ship selection dialog: choosing a navy and a fleet

const SELECTION_SCENE := preload("res://gui/ship_selection.tscn")


func slider(dialog: Node, ship_type: String) -> HSlider:
	return dialog.get_node("VBoxContainer/Body/SelectionGrid/" + ship_type + "/CountSlider")


# One of each costs 24 of the 25 points, so the last goes on a battery if
# there's an island for one
func test_classic_fleet_spends_the_spare_point_on_a_battery() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	dialog.set_island_tiles(2)
	dialog.get_node("VBoxContainer/Buttons/Classic").pressed.emit()
	assert_eq(slider(dialog, "CoastalBattery").value, 2.0, "two islands, two batteries")
	assert_eq(dialog.used_points, dialog.POINTS_BUDGET)
	dialog.set_island_tiles(1)
	dialog.get_node("VBoxContainer/Buttons/Classic").pressed.emit()
	assert_eq(slider(dialog, "CoastalBattery").value, 1.0, "one island, one")
	assert_false(dialog.can_add_ship(), "so nothing to ask about")


# The name follows the mouse or a controller's focus before anything's chosen,
# then goes back to the navy that is
func test_navy_name_follows_the_focus() -> void:
	var dialog: Control = SELECTION_SCENE.instantiate()
	dialog.taken = "uk"
	add_child_autofree(dialog)
	var flags := dialog.get_node("VBoxContainer/Navies")
	var name_label: Label = dialog.get_node("VBoxContainer/NavyName")
	(flags.get_node("japan") as Button).button_pressed = true
	(flags.get_node("italy") as Button).focus_entered.emit()
	assert_eq(name_label.text, "Marina Militare", "the focused one")
	assert_eq(dialog.navy, "japan", "still the one chosen")
	(flags.get_node("italy") as Button).focus_exited.emit()
	assert_eq(name_label.text, "Japan Maritime Self-Defense Force", "back to the chosen one")
	(flags.get_node("uk") as Button).mouse_entered.emit()
	assert_eq(name_label.text, "Royal Navy (taken)", "the opponent's, hovered")
