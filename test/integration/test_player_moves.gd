extends GutTest
# Player.can_perform() and perform(): the moves every kind of player makes,
# whether from input, an AI or the network

const ROOT_SCENE := preload("res://root.tscn")

var game: Root
var p0: LocalPlayer
var p1: LocalPlayer


func before_each() -> void:
	Engine.time_scale = 4.0
	game = add_child_autofree(ROOT_SCENE.instantiate())
	p0 = game.players[0]
	p1 = game.players[1]
	for column: Array in game.grid.tiles:
		for tile: Tile in column:
			tile.island = false


func after_each() -> void:
	Engine.time_scale = 1.0


func spawn(player: Player, type: String, hex: Vector2i) -> Ship:
	var ship: Ship = load("res://ships/" + type + ".tscn").instantiate()
	player.adopt(ship)
	ship.set_grid_position(hex, 0)
	player.ships.append(ship)
	ship.new_turn()
	return ship


func test_attacks_only_on_the_opponents_side() -> void:
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	assert_true(p0.can_perform(destroyer, "fire", Vector2i(20, 7)))
	assert_false(p0.can_perform(destroyer, "fire", Vector2i(3, 7)), "not our own side")
	assert_false(p0.can_perform(destroyer, "fire", Vector2i(15, 7)), "not no-man's-land")
	assert_false(p0.can_perform(destroyer, "fire"), "not without a target")
	assert_false(p1.can_perform(destroyer, "fire", Vector2i(3, 7)), "only with our own ships")
	assert_false(p0.can_perform(destroyer, "dance"), "only real moves")


func test_unrep_only_heals_our_ships_next_to_the_tender() -> void:
	var tender: SupplyTender = spawn(p0, "supply_tender", Vector2i(5, 7))
	tender.special.cooldown_current = 0
	var next_to := spawn(p0, "corvette", Vector2i(6, 7))
	var far := spawn(p0, "corvette", Vector2i(10, 2))
	assert_true(p0.can_perform(tender, "special", next_to.hex))
	assert_false(p0.can_perform(tender, "special", far.hex), "not out of reach")
	assert_false(p0.can_perform(tender, "special", Vector2i(20, 7)), "not at the opponent")


func test_moves_and_attacks_without_any_input() -> void:
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	var target := spawn(p1, "carrier", Vector2i(20, 7))
	var at := destroyer.hex
	await p0.perform(destroyer, "forward")
	assert_ne(destroyer.hex, at, "moved")
	assert_eq(destroyer.ap, 3)
	watch_signals(p0)
	await p0.perform(destroyer, "fire", target.hex)
	# perform() returns as the missile signals it's done; let it finish
	await wait_process_frames(1)
	assert_signal_emit_count(p0, "attack_started", 1)
	assert_signal_emit_count(p0, "attack_resolved", 1)
	assert_true(target.hit_hexes.has(true), "the opponent resolved it")
	assert_eq([p0.attacks, p0.hits], [1, 1], "counted for the victory screen")
	assert_false(p0.animation_playing)
	assert_signal_not_emitted(p0, "made_move", "left to whoever chose the move")
