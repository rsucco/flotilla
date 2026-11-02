extends GutTest
# Single player against the AI: no hand-offs, the player's fleet stays in
# view, and the AI's turn plays out live with its ships unseen

const ROOT_SCENE := preload("res://root.tscn")
const GameDriver := preload("res://test/game_driver.gd")

var game: Root
var driver: GameDriver


func before_each() -> void:
	seed(7)
	Root.mode = Root.Mode.VS_AI
	# GUT's own window would catch the board clicks
	get_node("/root/GutRunner/GutLayer").visible = false
	Engine.time_scale = 4.0
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()


func after_each() -> void:
	Root.mode = Root.Mode.HOT_SEAT
	Root.loaded = {}
	for slot in [SaveGame.AUTOSAVE] + SaveGame.SLOTS:
		SaveGame.delete(slot)
	Engine.time_scale = 1.0
	get_node("/root/GutRunner/GutLayer").visible = true


func swap_screen() -> Node:
	return driver._dialog(game, "res://gui/local_turn_swap.tscn")


func test_the_ai_sets_up_its_own_fleet_out_of_sight() -> void:
	var ai := game.players[1]
	assert_true(ai is AIPlayer)
	assert_eq(ai.ships.size(), GameDriver.LAYOUT.size(), "one of each ship")
	for ship in ai.ships:
		assert_eq(game.grid.side_of(ship.hex), 1, ship.ship_name + " on its side")
		assert_true(ship.can_place(ship.hex, ship.direction), ship.ship_name + " placed legally")
		assert_false(ship.visible, ship.ship_name + " hidden")
	assert_null(swap_screen(), "no hand-off")
	assert_true(game.players[0].active, "straight into the player's turn")


func test_the_ais_turn_plays_out_live() -> void:
	var ours := game.players[0].ships
	await driver.end_turn()
	await driver.wait_until(func() -> bool: return game.players[1].active, 5, "the AI's turn")
	var ai := game.players[1]
	assert_eq(game.turn_replay.watching, ai, "its shots masked")
	for ship in ai.ships:
		assert_true(ship.cloaked, ship.ship_name + " cloaked")
	assert_true(ours.all(func(s: Ship) -> bool: return s.visible), "our fleet still in view")
	assert_eq(game.viewer(), 0, "from our side")
	await driver.wait_until(func() -> bool: return game.players[0].active, 60, "our next turn")
	assert_gt(driver.moves, 1, "the AI made moves")
	assert_null(swap_screen(), "no hand-off")
	assert_null(game.turn_replay.watching)
	for ship in ai.ships:
		assert_false(ship.cloaked or ship.visible, ship.ship_name + " hidden again")
	assert_eq(game.current_turn, 2)


func test_no_saving_or_conceding_on_the_ais_turn() -> void:
	await driver.end_turn()
	await driver.wait_until(func() -> bool: return game.players[1].active, 5, "the AI's turn")
	game.pause_menu.open()
	assert_true(game.pause_menu.concede.disabled)
	assert_true(game.pause_menu.save_game.disabled)
	game.pause_menu.close()


func test_saved_and_loaded_as_a_game_against_the_ai() -> void:
	game.pause_menu.open()
	assert_false(game.pause_menu.save_game.disabled, "saving on our turn")
	game.pause_menu.close()
	await driver.end_turn()
	await driver.wait_until(func() -> bool: return game.players[0].active, 60, "our next turn")
	var data := SaveGame.read(SaveGame.AUTOSAVE)
	assert_eq(data.get("mode"), Root.Mode.VS_AI, "autosaved as our turn starts")
	assert_eq(data.get("turn"), 2)
	# Loaded as Continue would, whatever mode was last played
	Root.mode = Root.Mode.HOT_SEAT
	game.queue_free()
	await wait_process_frames(1)
	Root.loaded = data
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	assert_true(game.players[1] is AIPlayer, "against the AI again")
	await driver.wait_until(func() -> bool: return game.players[0].active, 5, "our turn")
	assert_null(swap_screen(), "no hand-off")
	assert_true(game.players[0].ships.all(func(s: Ship) -> bool: return s.visible), "our fleet")
	assert_false(game.players[1].ships.any(func(s: Ship) -> bool: return s.visible), "not theirs")


func test_the_victory_screen_says_you_and_the_ai() -> void:
	game.pause_menu.open()
	game.pause_menu.concede.pressed.emit()
	game.pause_menu.get_node("Panel/Confirm/Buttons/Yes").pressed.emit()
	var victory := await driver.find_dialog(game, "res://gui/victory.tscn")
	var ai := game.players[1].navy_name()
	assert_eq(victory.get_node("VBoxContainer/Label").text, ai + " wins! You conceded.")
	# After the row of flags
	var stats := victory.get_node("VBoxContainer/Stats").get_children().slice(3)
	assert_eq([stats[1].text, stats[2].text], ["You", ai])
