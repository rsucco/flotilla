extends GutTest
# Where ships may start (Ship.can_place()) and the moves they make
# (Player.can_perform() and perform()): the same for every kind of player,
# whether its choices come from input, an AI or the network

const ROOT_SCENE := preload("res://game/root.tscn")

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


func unplaced(player: Player, type: String) -> Ship:
	var ship: Ship = add_child_autofree(load("res://ships/" + type + ".tscn").instantiate())
	ship.player = player
	ship.grid = game.grid
	return ship


func test_placed_on_our_own_water_clear_of_our_ships() -> void:
	var destroyer := unplaced(p0, "destroyer")
	assert_true(destroyer.can_place(Vector2i(5, 7), 0))
	assert_false(destroyer.can_place(Vector2i(20, 7), 0), "not on the opponent's side")
	assert_false(destroyer.can_place(Vector2i(5, 0), 0), "not hanging off the board")
	assert_false(destroyer.can_place(Vector2i(14, 7), 60), "not into no-man's-land")
	game.grid.tile(Vector2i(5, 7)).island = true
	assert_false(destroyer.can_place(Vector2i(5, 7), 0), "not on land")
	game.grid.tile(Vector2i(5, 7)).island = false
	spawn(p0, "corvette", Vector2i(5, 7))
	assert_false(destroyer.can_place(Vector2i(5, 7), 0), "not on another of our ships")
	assert_false(destroyer.can_place(Vector2i(5, 8), 0), "nor overlapping it")


func test_ships_named_in_turn_and_logged_by_name() -> void:
	var first := spawn(p0, "cruiser", Vector2i(3, 3))
	var second := spawn(p0, "cruiser", Vector2i(8, 8))
	assert_eq([first.title, second.title], ["Cruiser I", "Cruiser II"])
	second.hit(second.hex, null)
	assert_eq(game.grid.tile(second.hex).history[-1][1], "Hit, Cruiser II")
	first.title = "HMS Exeter"
	first.hit(first.hex, null)
	first.hit(first.hex, null)
	var history := game.grid.tile(first.hex).history
	assert_eq(history[-2][1], "Hit, HMS Exeter (Cruiser)", "a real name gets its type")
	assert_eq(history[-1][1], "Hit, HMS Exeter (Cruiser, No effect)")


func test_ships_named_from_their_navy_once_each() -> void:
	p0.navy = "japan"
	var titles: Array[String] = []
	for type: String in ["cruiser", "destroyer", "corvette", "coastal_battery"]:
		for i in 5:
			titles.append(spawn(p0, type, Vector2i(i, 2)).title)
	for title in titles.slice(0, 15):
		assert_string_starts_with(title, "JS ")
	assert_eq(
		titles.slice(15),
		[
			"Coastal Battery I",
			"Coastal Battery II",
			"Coastal Battery III",
			"Coastal Battery IV",
			"Coastal Battery V"
		],
		"batteries are numbered"
	)
	for title in titles:
		assert_eq(titles.count(title), 1, title + " only once")


func tap(ship: Ship, hex: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	# How touch screens' taps arrive
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.grid.get_hex_center(hex)
	ship._input(event)
	# Taken as a while later, unless the test says otherwise
	ship._tapped_at -= Ship.DOUBLE_TAP_MS


func test_placed_by_touch_with_taps() -> void:
	var ship := unplaced(p0, "destroyer")
	watch_signals(ship)
	ship.place()
	tap(ship, Vector2i(5, 7))
	assert_eq(ship.hex, Vector2i(5, 7), "a tap moves it there")
	assert_true(ship.visible)
	tap(ship, Vector2i(9, 7))
	assert_eq(ship.hex, Vector2i(9, 7), "and another moves it again")
	tap(ship, Vector2i(9, 7))
	assert_eq(ship.direction, 60, "a tap on it turns it")
	tap(ship, Vector2i(9, 7))
	ship._tapped_at += Ship.DOUBLE_TAP_MS
	tap(ship, Vector2i(9, 7))
	assert_signal_emit_count(ship, "placed", 1, "a double tap places it")
	assert_eq(ship.direction, 60, "the first of the two doesn't turn it")
	assert_false(ship.placing)


func test_batteries_go_on_land() -> void:
	var battery := unplaced(p0, "coastal_battery")
	assert_false(battery.can_place(Vector2i(3, 3), 0), "not on water")
	game.grid.tile(Vector2i(3, 3)).island = true
	assert_true(battery.can_place(Vector2i(3, 3), 0))


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
