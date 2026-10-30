extends GutTest
# Ship rules from the README, exercised against the real game scene

const ROOT_SCENE := preload("res://root.tscn")

var game: Root
var p0: LocalPlayer
var p1: LocalPlayer


func before_each() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	p0 = game.players[0]
	p1 = game.players[1]
	for column: Array in game.grid.tiles:
		for tile: Tile in column:
			tile.island = false


func spawn(player: Player, type: String, hex: Vector2i, dir: int = 0) -> Ship:
	var ship: Ship = load("res://ships/" + type + ".tscn").instantiate()
	player.adopt(ship)
	ship.set_grid_position(hex, dir)
	player.ships.append(ship)
	return ship


func remove(ship: Ship) -> void:
	ship.player.ships.erase(ship)
	ship.queue_free()


func spawn_battery(player: Player, hex: Vector2i) -> CoastalBattery:
	game.grid.tile(hex).island = true
	return spawn(player, "coastal_battery", hex)


# Immobilization: only when more than 50% damaged


func test_three_hex_ship_mobile_after_one_hit() -> void:
	var ship := spawn(p0, "destroyer", Vector2i(5, 5))
	ship.hit_hexes = [true, false, false]
	assert_false(ship.is_immobilized())


func test_three_hex_ship_immobilized_after_two_hits() -> void:
	var ship := spawn(p0, "destroyer", Vector2i(5, 5))
	ship.hit_hexes = [true, true, false]
	assert_true(ship.is_immobilized())


func test_battleship_immobilized_only_after_three_hits() -> void:
	var ship := spawn(p0, "battleship", Vector2i(5, 5))
	ship.hit_hexes = [true, true, false, false]
	assert_false(ship.is_immobilized())
	ship.hit_hexes = [true, true, true, false]
	assert_true(ship.is_immobilized())


# Corvette: Fragile


func test_corvette_no_effect_hit_never_sinks() -> void:
	for i in 50:
		var ship := spawn(p1, "corvette", Vector2i(20, 5))
		ship.hit_hexes = [true, false]
		ship.hit(ship.get_occupied_hexes()[0], ship)
		assert_false(ship.sunk, "hit on an already-damaged hex")
		remove(ship)


func test_corvette_sinks_once_when_both_hexes_hit() -> void:
	var ship := spawn(p1, "corvette", Vector2i(20, 5))
	var hexes := ship.get_occupied_hexes()
	ship.hit_hexes = [true, false]
	ship.hit(hexes[1], ship)
	var sunk_events := game.grid.tile(hexes[1]).history.filter(
		func(e: Array) -> bool: return e[1].begins_with("Sunk")
	)
	assert_true(ship.sunk)
	assert_eq(sunk_events.size(), 1)


# Battleship: Salvo


func test_salvo_sinks_damaged_battery() -> void:
	var battery := spawn_battery(p1, Vector2i(22, 7))
	battery.hp = 4
	p1.receive_special(Vector2i(22, 7), spawn(p0, "battleship", Vector2i(5, 7)))
	assert_true(battery.sunk)


func test_salvo_on_undamaged_battery_is_normal_hit() -> void:
	var battery := spawn_battery(p1, Vector2i(22, 7))
	p1.receive_special(Vector2i(22, 7), spawn(p0, "battleship", Vector2i(5, 7)))
	assert_false(battery.sunk)
	assert_eq(battery.hp, 4)


# Cruiser: EW Strike and Missile Defense


func test_ew_strike_jams_carrier_for_one_turn() -> void:
	var carrier := spawn(p1, "carrier", Vector2i(22, 7))
	p1.receive_special(Vector2i(22, 7), spawn(p0, "cruiser", Vector2i(5, 7)))
	p1.new_turn()
	assert_eq(carrier.fire_remaining, 0, "jammed this turn")
	p1.finish_turn()
	p1.new_turn()
	assert_eq(carrier.fire_remaining, 2, "recovered next turn")


func test_ew_strike_out_of_range_not_jammed() -> void:
	var destroyer := spawn(p1, "destroyer", Vector2i(25, 3))
	p1.receive_special(Vector2i(22, 7), spawn(p0, "cruiser", Vector2i(5, 7)))
	p1.new_turn()
	assert_eq(destroyer.fire_remaining, 1)


func test_cruiser_intercepts_about_quarter_of_nukes_and_cancels_them() -> void:
	seed(1)
	var sub := spawn(p0, "submarine", Vector2i(5, 7))
	var intercepts := 0
	for i in 200:
		var target := spawn(p1, "destroyer", Vector2i(22, 7))
		var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
		p1.receive_special(Vector2i(22, 7), sub)
		if not target.sunk:
			intercepts += 1
			assert_false(cruiser.hit_hexes.has(true), "intercepted strike has no area effect")
		remove(target)
		remove(cruiser)
	assert_between(intercepts, 30, 70, "~25% of 200")


func test_cruiser_intercepts_about_half_of_missiles() -> void:
	seed(1)
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	var intercepts := 0
	for i in 200:
		var target := spawn(p1, "battleship", Vector2i(22, 7))
		var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
		if p1.receive_fire(Vector2i(22, 7), destroyer) == null:
			intercepts += 1
		remove(target)
		remove(cruiser)
	assert_between(intercepts, 80, 120, "~50% of 200")


# Submarine: Sonar Pulse


func test_sonar_pulse_reveals_ship_on_center_hex() -> void:
	var target := spawn(p1, "destroyer", Vector2i(22, 7))
	target.visible = false
	p1.receive_special(Vector2i(22, 7), spawn(p0, "submarine", Vector2i(5, 7)), true)
	assert_true(target.visible)
	p1.finish_turn()
	# Its revealed copy is freed at the end of the frame
	await wait_process_frames(1)


# Coastal Battery: Stationary drawback


func test_battery_reveals_itself_when_firing() -> void:
	var battery := spawn_battery(p0, Vector2i(5, 7))
	battery.ap = 2
	battery.fire_remaining = 1
	battery.fire(Vector2i(22, 7))
	assert_eq(p1.temp_revealed_ships.size(), 1)
	assert_eq(game.grid.tile(Vector2i(5, 7)).history[-1][1], "Coastal Battery revealed by firing")
	p1.finish_turn()
	# Its revealed copy is freed at the end of the frame
	await wait_process_frames(1)


func test_battery_sinks_cleanly() -> void:
	# Its sink sound ends before the fade does, freeing the sound player first
	var battery := spawn_battery(p0, Vector2i(5, 7))
	battery.held = true
	await battery.sink_effect()
	assert_false(battery.visible)


# Destroyer: Lay Mine


func test_mines_hit_a_random_hex() -> void:
	seed(1)
	var hit_indexes := {}
	for i in 60:
		var ship := spawn(p1, "battleship", Vector2i(22, 7))
		game.grid.tile(ship.hex).is_mined = true
		ship.check_for_mine()
		hit_indexes[ship.hit_hexes.find(true)] = true
		remove(ship)
	# -1 means the armor blocked it; any of the 4 hexes can take the hit
	hit_indexes.erase(-1)
	assert_eq(hit_indexes.size(), 4)


# Supply Tender: UNREP


func ready_tender() -> SupplyTender:
	var tender: SupplyTender = spawn(p0, "supply_tender", Vector2i(5, 7))
	tender.ap = 4
	tender.special.cooldown_current = 0
	return tender


func click(player: LocalPlayer, hex: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.grid.get_hex_center(hex)
	player._unhandled_input(event)


func test_unrep_targets_only_adjacent_ships_not_itself() -> void:
	var tender := ready_tender()
	var adjacent := spawn(p0, "destroyer", Vector2i(6, 7))
	spawn(p0, "destroyer", Vector2i(10, 7))
	assert_eq(tender.adjacent_ships(), [adjacent] as Array[Ship])


func test_unrep_unavailable_with_nothing_adjacent() -> void:
	var tender := ready_tender()
	spawn(p0, "destroyer", Vector2i(10, 7))
	assert_false(tender.can_special())


func test_unrep_heals_only_the_clicked_ship() -> void:
	var tender := ready_tender()
	tender.hit_hexes = [true, false, false]
	var target := spawn(p0, "destroyer", Vector2i(6, 7))
	target.hit_hexes = [true, true, false]
	var other := spawn(p0, "destroyer", Vector2i(4, 7))
	other.hit_hexes = [true, false, false]
	p0.active = true
	p0.selected_ship = tender
	p0._aim_special()
	click(p0, tender.hex)
	assert_true(tender.can_special(), "clicking the tender itself does nothing")
	click(p0, target.hex)
	assert_false(target.hit_hexes.has(true), "clicked ship fully healed")
	assert_true(other.hit_hexes.has(true), "other adjacent ship untouched")
	assert_true(tender.hit_hexes.has(true), "tender doesn't heal itself")


func test_unrep_restores_battery_hp() -> void:
	var tender := ready_tender()
	var battery := spawn_battery(p0, Vector2i(6, 7))
	battery.hp = 2
	tender.use_special(battery.hex)
	assert_eq(battery.hp, 5)
