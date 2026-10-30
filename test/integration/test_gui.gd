extends GutTest
# GUI state that only shows up in play

const ROOT_SCENE := preload("res://root.tscn")
const SELECTION_SCENE := preload("res://gui/ship_selection.tscn")
const GameDriver := preload("res://test/game_driver.gd")


func slider(dialog: Node, ship_type: String) -> HSlider:
	return dialog.get_node("VBoxContainer/SelectionGrid/" + ship_type + "/CountSlider")


func test_battery_count_capped_by_island_tiles() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	dialog.set_island_tiles(1)
	# Any slider change recalculates every slider's limit
	slider(dialog, "Destroyer").value = 1
	slider(dialog, "CoastalBattery").value = 3
	assert_eq(slider(dialog, "CoastalBattery").value, 1.0)


func test_classic_fleet_skips_battery_without_islands() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	dialog.set_island_tiles(0)
	dialog.get_node("VBoxContainer/Buttons/Classic").pressed.emit()
	assert_eq(slider(dialog, "CoastalBattery").value, 0.0)
	assert_eq(slider(dialog, "Carrier").value, 1.0)


func test_fleet_panel_follows_turn_swap() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	# Give the players different fleets
	driver.ship_of(1, "carrier").sink()
	await driver.end_turn()
	await driver.swap()
	assert_eq(driver.fleet_count("YourFleet"), 7, "player 2's fleet")
	assert_eq(driver.fleet_count("OpponentFleet"), 8, "player 1's fleet")


# ProgressBar ignores styles under any name but "fill"
func test_battery_hp_bar_keeps_its_style() -> void:
	var battery: Node = autofree(load("res://ships/coastal_battery.tscn").instantiate())
	assert_true(battery.get_node("HPBar").has_theme_stylebox_override("fill"))


func test_tile_history_only_shows_hexes_with_history() -> void:
	# GUT's own window would catch the hover
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	var popup: TileHistory = game.get_node("TileHistory")
	driver.hover(Vector2i(20, 10))
	await wait_seconds(0.8)
	assert_false(popup.visible, "nothing to show on an untouched hex")
	game.grid.tile(Vector2i(22, 10)).history.append([1, "Miss"])
	driver.hover(Vector2i(22, 10))
	await wait_seconds(0.8)
	assert_true(popup.visible, "shows a hex with history")
	get_node("/root/GutRunner/GutLayer").visible = true


func test_ship_hidden_until_placement_finds_a_spot() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	var player := game.players[0]
	var dialog := await driver.find_dialog(player, "res://gui/ship_selection.tscn")
	dialog.set_island_tiles(game.grid.get_num_island_tiles(0))
	driver.press(dialog.get_node("VBoxContainer/Buttons/Classic"))
	driver.press(dialog.get_node("VBoxContainer/Buttons/OK"))
	var ship := await driver.placing_ship(player)
	assert_false(ship.visible, "not drawn at the origin before it has a hex")
	driver.hover(GameDriver.spot(0, ship.ship_type))
	await wait_frames(1)
	assert_true(ship.visible, "shown once it snaps to a hex")
	get_node("/root/GutRunner/GutLayer").visible = true
