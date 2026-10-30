extends GutTest
# The Esc menu and replaying a game's setup

const ROOT_SCENE := preload("res://root.tscn")
const GameDriver := preload("res://test/game_driver.gd")


func after_each() -> void:
	get_tree().paused = false
	Root.replay = {}


func press_esc(game: Root) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game.get_viewport().push_input(event)


func test_esc_pauses_and_resumes() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var menu := game.pause_menu
	press_esc(game)
	assert_true(menu.visible, "opens")
	assert_true(get_tree().paused, "pauses the game")
	press_esc(game)
	assert_false(menu.visible, "closes")
	assert_false(get_tree().paused, "unpauses")


func test_destructive_items_ask_first() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var menu := game.pause_menu
	menu.open()
	menu.get_node("Panel/Main/NewGame").pressed.emit()
	assert_true(menu.get_node("Panel/Confirm").visible, "asks")
	menu.get_node("Panel/Confirm/Buttons/No").pressed.emit()
	assert_true(menu.get_node("Panel/Main").visible, "back to the menu")
	assert_true(menu.visible, "still open")


func test_replay_needs_a_finished_setup() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	assert_true(game.pause_menu.get_node("Panel/Main/Replay").disabled, "nothing to replay yet")
	await driver.start_game()
	assert_false(game.pause_menu.get_node("Panel/Main/Replay").disabled)
	assert_eq(game.setup.islands, game.grid.get_islands())
	assert_eq(game.setup.selections.size(), 2)
	get_node("/root/GutRunner/GutLayer").visible = true


func test_replay_keeps_board_and_fleets_but_places_again() -> void:
	var islands: Array[Vector2i] = [Vector2i(2, 3), Vector2i(20, 9)]
	var fleet := {"Destroyer": 1, "Submarine": 2}
	Root.replay = {"islands": islands, "selections": [fleet, fleet]}
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	assert_eq(game.grid.get_islands(), islands)
	var ship := await driver.placing_ship(game.players[0])
	assert_eq(ship.ship_type, "destroyer", "skips ship selection")
	assert_null(
		driver._dialog(game.players[0], "res://gui/ship_selection.tscn"), "no selection dialog"
	)
	assert_true(Root.replay.is_empty(), "only replays once")


func test_esc_works_during_ship_selection_and_placement() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	var dialog := await driver.find_dialog(game.players[0], "res://gui/ship_selection.tscn")
	press_esc(game)
	assert_true(game.pause_menu.visible, "opens over ship selection")
	press_esc(game)
	driver.press(dialog.get_node("VBoxContainer/Buttons/Classic"))
	driver.press(dialog.get_node("VBoxContainer/Buttons/OK"))
	await driver.placing_ship(game.players[0])
	press_esc(game)
	assert_true(game.pause_menu.visible, "opens during placement")
	press_esc(game)
