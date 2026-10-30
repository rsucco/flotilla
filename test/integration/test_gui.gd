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
	await wait_process_frames(1)
	assert_true(ship.visible, "shown once it snaps to a hex")
	get_node("/root/GutRunner/GutLayer").visible = true


func test_ok_needs_at_least_one_ship() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	var ok: Button = dialog.get_node("VBoxContainer/Buttons/OK")
	assert_true(ok.disabled, "disabled with nothing picked")
	slider(dialog, "Destroyer").value = 1
	assert_false(ok.disabled)
	dialog.get_node("VBoxContainer/Buttons/Reset").pressed.emit()
	assert_true(ok.disabled, "disabled again after Reset")


func test_unspent_points_ask_before_starting() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	watch_signals(dialog)
	slider(dialog, "Destroyer").value = 1
	dialog.get_node("VBoxContainer/Buttons/OK").pressed.emit()
	assert_signal_not_emitted(dialog, "confirmed", "asks first")
	assert_true(dialog.get_node("VBoxContainer/Confirm").visible)
	assert_string_contains(dialog.get_node("VBoxContainer/Confirm/Label").text, "22 points left")
	dialog.get_node("VBoxContainer/Confirm/No").pressed.emit()
	assert_true(dialog.get_node("VBoxContainer/Buttons").visible, "back to picking")
	dialog.get_node("VBoxContainer/Buttons/OK").pressed.emit()
	dialog.get_node("VBoxContainer/Confirm/Yes").pressed.emit()
	assert_signal_emitted(dialog, "confirmed")


func test_no_prompt_when_leftover_points_buy_nothing() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	dialog.set_island_tiles(0)
	watch_signals(dialog)
	# 24 of 25 points; nothing costs 1
	slider(dialog, "Carrier").value = 4
	slider(dialog, "Battleship").value = 1
	dialog.get_node("VBoxContainer/Buttons/OK").pressed.emit()
	assert_signal_emitted(dialog, "confirmed")


func test_title_button_asks_first() -> void:
	var dialog: Node = add_child_autofree(SELECTION_SCENE.instantiate())
	dialog.get_node("VBoxContainer/Buttons/Title").pressed.emit()
	assert_true(dialog.get_node("VBoxContainer/Confirm").visible)
	assert_eq(dialog.get_node("VBoxContainer/Confirm/Label").text, "Return to the title screen?")
	dialog.get_node("VBoxContainer/Confirm/No").pressed.emit()
	assert_true(dialog.get_node("VBoxContainer/Buttons").visible)


func test_tile_history_on_own_side_hides_enemy_mines() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	var popup: TileHistory = game.get_node("TileHistory")
	# Player 1's own side
	game.grid.tile(Vector2i(4, 10)).history.append([1, "Miss"])
	game.grid.tile(Vector2i(6, 10)).history.append([1, "Mine laid"])
	driver.hover(Vector2i(4, 10))
	await wait_seconds(0.8)
	assert_true(popup.visible, "shows the opponent's shot")
	driver.hover(Vector2i(6, 10))
	await wait_seconds(0.8)
	assert_false(popup.visible, "the opponent's mine stays hidden")
	assert_eq(popup.events_for(Vector2i(6, 10), 1).size(), 1, "the mine's owner still sees it")
	get_node("/root/GutRunner/GutLayer").visible = true
