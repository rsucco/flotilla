extends GutTest
# The rules' rolls come only from the game's Dice, so a move replays the same
# from the same seed, whatever else draws random numbers meanwhile (a networked
# game relies on this)

const ROOT_SCENE := preload("res://root.tscn")


func outcomes(game: Root, noise: bool) -> Array[bool]:
	var p0: Player = game.players[0]
	var p1: Player = game.players[1]
	var sunk: Array[bool] = []
	for i in 30:
		var corvette: Ship = load("res://ships/corvette.tscn").instantiate()
		p1.adopt(corvette)
		corvette.set_grid_position(Vector2i(20, 5), 0)
		p1.ships.append(corvette)
		if noise:
			# Effects, the AI and the like drawing on the global generator
			for j in 7:
				randf()
		corvette.hit(corvette.hex, null)
		sunk.append(corvette.sunk)
		if not corvette.sunk:
			p1.ships.erase(corvette)
			corvette.queue_free()
	return sunk


func test_the_same_seed_rolls_the_same() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	game.grid.dice.reseed(42)
	var first := outcomes(game, false)
	game.grid.dice.reseed(42)
	assert_eq(outcomes(game, true), first, "unaffected by other random numbers")
	assert_true(first.has(true) and first.has(false), "and still chance")


func test_each_game_rolls_its_own() -> void:
	var one: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var other: Root = add_child_autofree(ROOT_SCENE.instantiate())
	one.grid.dice.reseed(42)
	var alone: Array[float] = [one.grid.dice.roll(), one.grid.dice.roll()]
	one.grid.dice.reseed(42)
	var first := one.grid.dice.roll()
	other.grid.dice.roll()
	assert_eq([first, one.grid.dice.roll()] as Array[float], alone, "the other game's rolls aside")
