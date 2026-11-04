extends GutTest
# Each ship's passives, drawbacks and abilities from the README, beyond the
# combat basics in test_combat_rules.gd

const ROOT_SCENE := preload("res://game/root.tscn")

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


# Corvette: Littoral Ops and Fragile


func test_corvette_gets_an_extra_move_next_to_an_island() -> void:
	var corvette := spawn(p0, "corvette", Vector2i(5, 5))
	corvette.new_turn()
	assert_eq(corvette.ap, 4)
	var hexes := corvette.get_occupied_hexes()
	for h in game.grid.get_all_hex_neighbors(hexes[0]):
		if not hexes.has(h):
			game.grid.tile(h).island = true
			break
	corvette.new_turn()
	assert_eq(corvette.ap, 5, "one more hex of movement")


func test_corvette_sinks_on_about_three_quarters_of_first_hits() -> void:
	seed(1)
	game.grid.dice.reseed(1)
	var attacker := spawn(p0, "destroyer", Vector2i(5, 7))
	var sunk := 0
	for i in 200:
		var corvette := spawn(p1, "corvette", Vector2i(20, 5))
		p1.receive_fire(corvette.hex, attacker)
		if corvette.sunk:
			sunk += 1
		remove(corvette)
	assert_between(sunk, 130, 170, "~75% of 200")


# Destroyer: ASW Strike and Lay Mine


func test_asw_strike_sinks_a_sub_touching_the_area_but_not_ships() -> void:
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	var sub := spawn(p1, "submarine", Vector2i(20, 7))
	var battleship := spawn(p1, "battleship", Vector2i(26, 7))
	# Next to the sub's hexes, not on them
	p1.receive_special(Vector2i(21, 7), destroyer)
	assert_true(sub.sunk, "sub on a neighboring hex")
	p1.receive_special(battleship.hex, destroyer)
	assert_false(battleship.hit_hexes.has(true), "ships unaffected")


func test_moving_onto_a_mine_sets_it_off() -> void:
	var destroyer := spawn(p1, "destroyer", Vector2i(20, 7))
	destroyer.ap = 4
	var ahead := game.grid.get_hex_neighbor(destroyer.get_occupied_hexes()[-1], 0)
	if destroyer.get_occupied_hexes().has(ahead) or ahead == Grid.OFF_GRID:
		ahead = game.grid.get_hex_neighbor(destroyer.get_occupied_hexes()[0], 0)
	game.grid.tile(ahead).is_mined = true
	destroyer.forward()
	assert_true(destroyer.get_occupied_hexes().has(ahead), "moved onto it")
	assert_eq(destroyer.hit_hexes.count(true), 1, "took a hit")
	assert_false(game.grid.tile(ahead).is_mined, "and the mine is gone")


# Submarine: Nuclear Strike, Silent Service and Crushing Depths


func test_nuke_sinks_what_it_hits_dead_on_and_damages_around() -> void:
	var sub := spawn(p0, "submarine", Vector2i(5, 7))
	var target := spawn(p1, "destroyer", Vector2i(22, 7))
	var nearby := spawn(p1, "destroyer", Vector2i(24, 7))
	var far := spawn(p1, "destroyer", Vector2i(29, 7))
	p1.receive_special(Vector2i(22, 7), sub)
	assert_true(target.sunk, "dead-on")
	assert_true(nearby.hit_hexes.has(true), "within two hexes")
	assert_false(far.hit_hexes.has(true), "out of range")


func test_sub_only_hurt_by_surface_units_on_its_center_hex() -> void:
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	var sub := spawn(p1, "submarine", Vector2i(20, 7))
	var off_center := sub.get_occupied_hexes()[0]
	p1.receive_fire(off_center, destroyer)
	assert_false(sub.sunk)
	assert_eq(game.grid.tile(off_center).history[-1][1], "Miss (Silent Service)")
	p1.receive_fire(sub.hex, destroyer)
	assert_true(sub.sunk, "sinks instantly on its center hex")


func test_sub_sunk_by_another_sub_anywhere() -> void:
	var attacker := spawn(p0, "submarine", Vector2i(5, 7))
	var sub := spawn(p1, "submarine", Vector2i(20, 7))
	p1.receive_fire(sub.get_occupied_hexes()[0], attacker)
	assert_true(sub.sunk)


func test_sub_sunk_by_a_mine() -> void:
	var sub := spawn(p1, "submarine", Vector2i(20, 7))
	game.grid.tile(sub.get_occupied_hexes()[0]).is_mined = true
	sub.check_for_mine()
	assert_true(sub.sunk)


func test_sub_cannot_torpedo_island_tiles() -> void:
	var sub := spawn(p0, "submarine", Vector2i(5, 7))
	sub.ap = 4
	sub.fire_remaining = 1
	game.grid.tile(Vector2i(20, 3)).island = true
	assert_false(sub.can_fire(Vector2i(20, 3)))
	assert_true(sub.can_fire(Vector2i(20, 4)))


# Cruiser: EW Strike cooldowns


func test_ew_strike_adds_five_to_cooldowns_or_resets_whichever_is_less() -> void:
	var cruiser := spawn(p0, "cruiser", Vector2i(5, 7))
	# Nuclear Strike: 6-turn cooldown
	var ready := spawn(p1, "submarine", Vector2i(22, 7))
	var cooling := spawn(p1, "submarine", Vector2i(23, 7))
	ready.special.cooldown_current = 0
	cooling.special.cooldown_current = 3
	p1.receive_special(Vector2i(22, 7), cruiser)
	assert_eq(ready.special.cooldown_current, 5, "five added")
	assert_eq(cooling.special.cooldown_current, 6, "reset, as adding five would be more")


# Battleship: Salvo on ships, and Armor


func test_salvo_sinks_a_ship_hit_on_a_damaged_hex() -> void:
	var destroyer := spawn(p1, "destroyer", Vector2i(22, 7))
	destroyer.hit_hexes = [false, true, false]
	p1.receive_special(destroyer.hex, spawn(p0, "battleship", Vector2i(5, 7)))
	assert_true(destroyer.sunk)


func test_battleship_armor_blocks_about_a_quarter_of_hits() -> void:
	seed(1)
	game.grid.dice.reseed(1)
	var attacker := spawn(p0, "destroyer", Vector2i(5, 7))
	var blocked := 0
	for i in 400:
		var battleship := spawn(p1, "battleship", Vector2i(22, 7))
		p1.receive_fire(battleship.hex, attacker)
		if not battleship.hit_hexes.has(true):
			blocked += 1
		remove(battleship)
	assert_between(blocked, 70, 130, "~25% of 400")


func test_armor_never_blocks_a_hit_on_a_damaged_hex() -> void:
	seed(1)
	game.grid.dice.reseed(1)
	var attacker := spawn(p0, "destroyer", Vector2i(5, 7))
	var battleship := spawn(p1, "battleship", Vector2i(22, 7))
	battleship.hit_hexes = [false, false, true, false]
	for i in 20:
		p1.receive_fire(battleship.hex, attacker)
		var event: String = game.grid.tile(battleship.hex).history[-1][1]
		assert_eq(event, "Hit, Battleship I (No effect)", "still marked as a hit")


# Aircraft Carrier: Flight Ops, Degraded Runway and Recon Flight


func test_carrier_attacks_twice_until_two_hexes_are_damaged() -> void:
	var carrier := spawn(p0, "carrier", Vector2i(5, 7))
	carrier.new_turn()
	assert_eq(carrier.fire_remaining, 2)
	carrier.hit_hexes = [true, false, false, false, false]
	carrier.new_turn()
	assert_eq(carrier.fire_remaining, 2, "one damaged hex")
	carrier.hit_hexes = [true, true, false, false, false]
	carrier.new_turn()
	assert_eq(carrier.fire_remaining, 1, "two damaged hexes")


func test_recon_flight_reveals_ships_in_the_row() -> void:
	var carrier := spawn(p0, "carrier", Vector2i(5, 7))
	var in_row := spawn(p1, "destroyer", Vector2i(20, 7))
	var other_row := spawn(p1, "destroyer", Vector2i(20, 2))
	p1.receive_special(Vector2i(27, 7), carrier)
	assert_string_contains(game.grid.tile(in_row.hex).history[-1][1], "revealed by Recon Flight")
	assert_true(game.grid.tile(other_row.hex).history.is_empty(), "other rows untouched")


# Coastal Battery and Supply Tender


func test_battery_never_moves() -> void:
	var battery := spawn_battery(p0, Vector2i(5, 7))
	battery.ap = 4
	assert_false(battery.can_move())
	assert_false(battery.can_rotate(60))


func test_damage_control_heals_a_hex_every_ten_turns() -> void:
	var tender: SupplyTender = spawn(p0, "supply_tender", Vector2i(5, 7))
	var hexes := tender.get_occupied_hexes()
	tender.hit(hexes[0], tender)
	tender.hit(hexes[2], tender)
	for turn in 9:
		tender.new_turn()
	assert_eq(tender.hit_hexes.count(true), 2, "not after nine turns")
	assert_eq(tender.ap, 2, "half speed while damaged")
	var still_burning := tender.smoke_nodes[0]
	tender.new_turn()
	assert_eq(tender.hit_hexes.count(true), 1, "one hex healed on the tenth")
	await wait_process_frames(1)
	assert_eq(tender.smoke_nodes.keys(), [0], "its smoke gone too")
	assert_same(tender.smoke_nodes[0], still_burning, "the rest left burning")
	for turn in 10:
		tender.new_turn()
	assert_false(tender.hit_hexes.has(true), "the other ten turns later")
	assert_eq(tender.ap, 4, "full speed again")


func test_damage_control_counts_afresh_after_unrep() -> void:
	var tender: SupplyTender = spawn(p0, "supply_tender", Vector2i(5, 7))
	tender.hit(tender.hex, tender)
	for turn in 5:
		tender.new_turn()
	tender.heal()
	tender.new_turn()
	tender.hit(tender.hex, tender)
	for turn in 9:
		tender.new_turn()
	assert_true(tender.hit_hexes.has(true), "not healed early on the old count")
	tender.new_turn()
	assert_false(tender.hit_hexes.has(true))


# README: Salvo has a 3-turn cooldown
func test_salvo_cools_down_for_three_turns() -> void:
	var battleship := spawn(p0, "battleship", Vector2i(5, 7))
	assert_eq(battleship.special.cooldown_interval, 3)


# README: the carrier has 6 AP, so it can still move after both its attacks
func test_a_carrier_can_move_after_attacking_twice() -> void:
	var carrier := spawn(p0, "carrier", Vector2i(7, 7))
	carrier.new_turn()
	assert_eq(carrier.ap, 6)
	assert_eq(carrier.fire_remaining, 2)
	carrier.ap -= 4
	carrier.fire_remaining = 0
	assert_true(carrier.can_move(), "two attacks' AP spent, one hex still left")
