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
