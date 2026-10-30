extends GutTest
# A whole game played through the real input and buttons: selection,
# placement, every weapon and ability, movement, a mine, turn swaps, and
# victory. Engine errors at any point fail the test.

const ROOT_SCENE := preload("res://root.tscn")
const GameDriver := preload("res://test/game_driver.gd")

var game: Root
var driver: GameDriver


func before_each() -> void:
	# GUT's own window sits over the board and would eat the clicks
	get_node("/root/GutRunner/GutLayer").visible = false
	# Animations are the slow part
	Engine.time_scale = 4.0
	seed(3)
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	driver.prepare_board()


func after_each() -> void:
	get_node("/root/GutRunner/GutLayer").visible = true
	Engine.time_scale = 1.0


func enemy(ship_type: String) -> Vector2i:
	return GameDriver.spot(1 - game.player_up, ship_type)


func test_full_game() -> void:
	await driver.start_game()
	var p0 := game.players[0]
	var p1 := game.players[1]
	assert_eq(p0.ships.size(), 8, "player 1 placed the classic fleet")
	assert_eq(p1.ships.size(), 8, "player 2 placed the classic fleet")

	# Player 1, turn 1: every ability, plus some weapons and moves
	driver.ready_abilities(p0)
	await driver.act("coastal_battery", "Fire", enemy("coastal_battery"))
	await driver.act("corvette", "Fire", Vector2i(19, 12))
	await driver.act("corvette", "Port")
	await driver.act("destroyer", "Special", enemy("submarine"))
	assert_null(driver.ship_of(1, "submarine"), "ASW Strike sank the sub")
	var mine := Vector2i(25, 3)
	await driver.act("destroyer", "Secondary", mine)
	assert_true(game.grid.tile(mine).is_mined)
	await driver.act("submarine", "Special", Vector2i(27, 12))
	await driver.act("submarine", "Secondary", Vector2i(19, 8))
	await driver.act("cruiser", "Fire", enemy("carrier"))
	await driver.act("cruiser", "Special", enemy("destroyer"))
	assert_true(driver.ship_of(1, "destroyer").jammed, "EW Strike jammed the destroyer")
	driver.ship_of(0, "destroyer").hit_hexes[0] = true
	await driver.act("supply_tender", "Special", GameDriver.spot(0, "destroyer"))
	assert_false(driver.ship_of(0, "destroyer").hit_hexes.has(true), "UNREP healed the destroyer")
	await driver.act("supply_tender", "Forward")
	await driver.act("battleship", "Fire", Vector2i(19, 10))
	await driver.act("battleship", "Special", enemy("coastal_battery"))
	assert_null(driver.ship_of(1, "coastal_battery"), "Salvo sank the damaged battery")
	await driver.act("carrier", "Fire", Vector2i(21, 12))
	await driver.act("carrier", "Special", enemy("battleship"))
	assert_true(driver.ship_of(1, "battleship").visible, "Recon Flight revealed the battleship")
	await driver.end_turn()

	# Player 2, turn 1
	await driver.swap()
	assert_eq(game.player_up, 1)
	assert_eq(
		driver.fleet_count("YourFleet"), p1.ships.size(), "fleet panel shows player 2's fleet"
	)
	assert_eq(driver.fleet_count("OpponentFleet"), p0.ships.size())
	await driver.select("destroyer")
	assert_true(driver.action_button("Fire").disabled, "jammed destroyer can't fire")
	await driver.act("cruiser", "Forward")
	assert_false(game.grid.tile(mine).is_mined, "the cruiser set off the mine")
	await driver.act("cruiser", "Fire", enemy("carrier"))
	# The corvette was jammed too, but can still move
	await driver.act("corvette", "Starboard")
	await driver.act("battleship", "Reverse")
	await driver.act("carrier", "Fire", enemy("battleship"))
	await driver.end_turn()

	# Player 1, turn 2: the weapons not fired yet, then sink the rest
	await driver.swap()
	await driver.act("destroyer", "Fire", enemy("destroyer"))
	await driver.act("submarine", "Fire", enemy("supply_tender"))
	for ship in p1.ships.duplicate():
		ship.sink()
	await driver.end_turn()
	var victory := await driver.find_dialog(game, "res://gui/victory.tscn")
	assert_not_null(victory)
	if victory:
		assert_eq(victory.get_node("VBoxContainer/Label").text, "Player One wins!\n")
