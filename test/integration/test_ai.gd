extends GutTest
# The AI's picture of the opponent's fleet (HeatMap) and how it picks attacks

const ROOT_SCENE := preload("res://game/root.tscn")

var game: Root
var grid: Grid
var p0: Player
var p1: Player


func before_each() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	grid = game.grid
	p0 = game.players[0]
	p1 = game.players[1]
	for column: Array in grid.tiles:
		for tile: Tile in column:
			tile.island = false
	grid.turn = 5


func spawn(player: Player, type: String, hex: Vector2i) -> Ship:
	var ship: Ship = load("res://ships/" + type + ".tscn").instantiate()
	player.adopt(ship)
	ship.set_grid_position(hex, 0)
	player.ships.append(ship)
	ship.new_turn()
	return ship


# As the AI (player 1) sees player 0's side
func map() -> HeatMap:
	return HeatMap.new(grid, 0, p0.ships, [] as Array[Ship], grid.turn)


func total(heat: Dictionary) -> float:
	return heat.values().reduce(func(sum: float, h: float) -> float: return sum + h, 0.0)


func test_with_nothing_known_the_fleet_is_spread_over_the_side() -> void:
	spawn(p0, "destroyer", Vector2i(5, 5))
	spawn(p0, "corvette", Vector2i(9, 9))
	assert_almost_eq(total(map().heat), 5.0, 0.001, "one per hex of the fleet")


func test_only_what_a_player_could_know() -> void:
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 5))
	grid.log_event(Vector2i(8, 8), "Miss")
	var before := map().heat
	destroyer.set_grid_position(Vector2i(12, 2), 60)
	assert_eq(map().heat, before, "moving the fleet unseen changes nothing")


func test_a_miss_clears_a_hex_until_ships_could_have_moved() -> void:
	spawn(p0, "destroyer", Vector2i(5, 5))
	grid.log_event(Vector2i(8, 8), "Miss")
	assert_eq(map().heat[Vector2i(8, 8)], 0.0, "just missed")
	var clear: float = map().heat[Vector2i(9, 9)]
	grid.turn += 2
	var later: float = map().heat[Vector2i(8, 8)]
	assert_gt(later, 0.0, "could be back two turns later")
	assert_lt(later, clear, "but less likely than an untouched hex")


func test_a_sighting_draws_the_ship_to_it() -> void:
	spawn(p0, "destroyer", Vector2i(5, 5))
	grid.log_event(Vector2i(5, 5), "Destroyer I revealed by Recon Flight")
	var heat := map().heat
	var hottest: Vector2i = heat.keys().reduce(
		func(a: Vector2i, b: Vector2i) -> Vector2i: return a if heat[a] >= heat[b] else b
	)
	assert_eq(hottest, Vector2i(5, 5))
	assert_gt(heat[Vector2i(5, 5)], 0.5)


func test_a_named_sighting_pins_down_that_ship_alone() -> void:
	spawn(p0, "destroyer", Vector2i(2, 2))
	var second := spawn(p0, "destroyer", Vector2i(5, 5))
	second.title = "HMS Exeter"
	grid.log_event(Vector2i(5, 5), "HMS Exeter (Destroyer) revealed by Recon Flight")
	var heat := map().heat
	assert_almost_eq(heat[Vector2i(5, 5)], 1.0, 0.05, "Exeter is there")
	assert_gt(heat[Vector2i(12, 12)], 0.0, "the other destroyer could be anywhere")


func test_a_crippled_ship_is_still_where_it_was_hit() -> void:
	spawn(p0, "corvette", Vector2i(5, 5))
	grid.log_event(Vector2i(5, 5), "Hit, Corvette I")
	grid.log_event(Vector2i(5, 6), "Hit, Corvette I (Immobilized)")
	grid.turn += 3
	assert_gt(map().heat[Vector2i(5, 5)], 0.5, "over half damaged, so it can't move")


# Swaps the hot-seat game for one against the AI
func play_the_ai() -> void:
	game.queue_free()
	Root.mode = Root.Mode.VS_AI
	game = add_child_autofree(ROOT_SCENE.instantiate())
	Root.mode = Root.Mode.HOT_SEAT
	grid = game.grid
	p0 = game.players[0]
	p1 = game.players[1]
	for column: Array in grid.tiles:
		for tile: Tile in column:
			tile.island = false


func test_the_ai_fires_where_a_ship_was_just_seen() -> void:
	play_the_ai()
	spawn(p0, "carrier", Vector2i(7, 7))
	var gunner := spawn(p1, "corvette", Vector2i(20, 7))
	grid.log_event(Vector2i(7, 7), "Aircraft Carrier I revealed by Recon Flight")
	var move: Array = (p1 as AIPlayer)._best_attack()
	assert_eq(move.slice(0, 2), [gunner, "fire"])
	assert_lte(Grid.distance(move[2], Vector2i(7, 7)), 2, "at the carrier")


# Pulsing gives the sub away, so it doesn't stay to shoot: it runs
func test_a_submarine_that_pulsed_runs_rather_than_fires() -> void:
	var ai := AIPlayer.new(0)
	ai.grid = grid
	ai.opponent = p1
	add_child_autofree(ai)
	var sub := spawn(ai, "submarine", Vector2i(7, 7))
	grid.log_event(sub.hex, "Submarine used Sonar Pulse")
	ai._fleeing.append(sub)
	var move: Array = ai._flee()
	assert_eq(move[0], sub)
	assert_true(move[1] in AIPlayer.MOVES)
	assert_true(ai._best_attack().is_empty(), "no shots from the fleeing sub")
	sub.ap = 0
	assert_true(ai._flee().is_empty(), "nothing left to run with")
	ai.new_turn()
	assert_true(ai._fleeing.is_empty(), "next turn it fights again")


func test_a_submarine_only_pulses_before_anything_else() -> void:
	var ai := AIPlayer.new(0)
	ai.grid = grid
	ai.opponent = p1
	add_child_autofree(ai)
	# Enough value that it would rather pulse than fire
	ai.values = AIPlayer.VALUES.merged({"Sonar Pulse": 5.0}, true)
	spawn(p1, "destroyer", Vector2i(22, 7))
	var sub := spawn(ai, "submarine", Vector2i(7, 7))
	sub.secondary.cooldown_current = 0
	assert_eq(ai._best_attack().slice(0, 2), [sub, "secondary"], "with all its AP")
	sub.ap = 2
	assert_ne(ai._best_attack().slice(0, 2), [sub, "secondary"], "not once it's acted")


func test_every_fleet_spends_the_budget_within_the_rules() -> void:
	var selection := AIPlayer.SELECTION
	for fleet: Dictionary in AIPlayer.FLEETS:
		var points := 0
		for ship_type: String in fleet:
			assert_true(selection.POINT_VALUES.has(ship_type), ship_type + " is a ship")
			assert_lte(fleet[ship_type], selection.MAX_PER_TYPE, ship_type)
			points += fleet[ship_type] * selection.POINT_VALUES[ship_type]
		assert_eq(points, selection.POINTS_BUDGET, str(fleet))


func test_batteries_only_with_islands_to_put_them_on() -> void:
	grid.tile(Vector2i(20, 3)).island = true
	var ai := AIPlayer.new(1)
	ai.grid = grid
	ai.opponent = p0
	add_child_autofree(ai)
	for i in 20:
		var fleet := ai.get_ship_selection()
		assert_lte(fleet.get("CoastalBattery", 0), 1, str(fleet))


func test_the_ai_takes_another_navy() -> void:
	var ai := AIPlayer.new(1)
	ai.grid = grid
	ai.opponent = p0
	add_child_autofree(ai)
	p0.navy = "uk"
	for i in 20:
		ai.get_ship_selection()
		assert_true(Navies.ALL.has(ai.navy) and ai.navy != "uk", ai.navy)


func test_ships_move_off_where_they_were_seen() -> void:
	var ai := AIPlayer.new(1)
	ai.grid = grid
	ai.opponent = p0
	add_child_autofree(ai)
	var ship := spawn(ai, "destroyer", Vector2i(20, 7))
	grid.log_event(Vector2i(20, 7), "Hit, Destroyer I")
	assert_false(ai._best_move().is_empty(), "moves the ship that was hit")
	var quiet := spawn(ai, "cruiser", Vector2i(26, 3))
	ai.ships.erase(ship)
	assert_true(ai._best_move().is_empty(), "leaves an unseen ship where it is")
	assert_true(quiet.can_move(), "though it could move")


func test_the_tender_heads_for_a_damaged_ship() -> void:
	var ai := AIPlayer.new(1)
	ai.grid = grid
	ai.opponent = p0
	add_child_autofree(ai)
	var hurt := spawn(ai, "cruiser", Vector2i(20, 7))
	hurt.hit_hexes[0] = true
	# Just out of UNREP's reach
	var tender := spawn(ai, "supply_tender", Vector2i(23, 6))
	tender.special.cooldown_current = 0
	var move: Array = ai._best_move()
	assert_eq(move.slice(0, 1), [tender])
	var in_reach := false
	for h in ai._hexes_after(tender, move[1]):
		for o in hurt.get_occupied_hexes():
			in_reach = in_reach or Grid.distance(h, o) <= SupplyTender.REACH
	assert_true(in_reach, "into reach of it")


func test_a_cloaked_battery_shows_itself_as_it_fires() -> void:
	play_the_ai()
	grid.tile(Vector2i(20, 3)).island = true
	var battery: CoastalBattery = spawn(p1, "coastal_battery", Vector2i(20, 3))
	game.turn_replay.watch(p1)
	battery.cloaked = true
	await p1.perform(battery, "fire", Vector2i(5, 5))
	await wait_process_frames(1)
	assert_eq(p0.temp_revealed_ships.size(), 1)
	var copy := p0.temp_revealed_ships[0]
	assert_true(copy.is_inside_tree() and copy.visible, "shown on our side straight away")
	assert_eq(copy.self_modulate, Color.WHITE, "not cloaked like the battery")
	assert_true(copy.get_node("Turret").visible)
	assert_almost_eq(
		(copy.get_node("Turret") as Node2D).rotation, battery.turret.rotation, 0.01, "as it fired"
	)
	game.turn_replay.stop_watching()
