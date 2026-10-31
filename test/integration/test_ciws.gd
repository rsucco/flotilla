extends GutTest
# Passive - Missile Defense: cruisers shooting down missiles and nukes

const ROOT_SCENE := preload("res://root.tscn")
const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")

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


func test_cruiser_intercepts_about_quarter_of_nukes_and_cancels_them() -> void:
	seed(1)
	var sub := spawn(p0, "submarine", Vector2i(5, 7))
	var intercepts := 0
	for i in 200:
		var target := spawn(p1, "destroyer", Vector2i(22, 7))
		var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
		p1.roll_intercept(sub, "special", Vector2i(22, 7))
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
		p1.roll_intercept(destroyer, "fire", Vector2i(22, 7))
		if p1.receive_fire(Vector2i(22, 7), destroyer) == null:
			intercepts += 1
		remove(target)
		remove(cruiser)
	assert_between(intercepts, 80, 120, "~50% of 200")


func test_no_intercept_without_a_ship_on_the_hex() -> void:
	spawn(p1, "cruiser", Vector2i(24, 7))
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	for i in 20:
		assert_false(p1.roll_intercept(destroyer, "fire", Vector2i(22, 7)))


func test_intercepted_missile_shot_down_over_no_mans_land() -> void:
	var missiles: Array[Missile] = []
	game.effects.child_entered_tree.connect(
		func(node: Node) -> void:
			if node is Missile:
				missiles.append(node)
	)
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	destroyer.ap = 2
	destroyer.fire_remaining = 1
	destroyer.intercepted = true
	await destroyer.fire(Vector2i(24, 9))
	var at := game.grid.get_hex_from_coords(missiles[0].position)
	assert_eq(at.x, Grid.NO_MANS_LAND, "dies over no-man's-land")
	assert_not_null(missiles[0].tracers, "CIWS fired")
	var edge_x := missiles[0].tracers.position.x
	assert_between(edge_x, missiles[0].position.x, game.grid.get_hex_center(Vector2i(16, 0)).x)
	await wait_seconds(2.5)


func _intercepted_missile() -> Missile:
	var missile: Missile = MISSILE_SCENE.instantiate()
	missile.grid = game.grid
	missile.intercepted = true
	game.effects.add_child(missile)
	return missile


func test_ciws_fires_just_before_the_kill_and_briefly_after() -> void:
	var missile := _intercepted_missile()
	missile.launch(game.grid.get_hex_center(Vector2i(5, 7)), Vector2i(24, 9), 0.0, true)
	await wait_until(func() -> bool: return missile.tracers != null, 5)
	var opened := Time.get_ticks_msec()
	var tracers := missile.tracers
	await wait_for_signal(missile.done, 5)
	var lead := (Time.get_ticks_msec() - opened) / 1000.0
	assert_between(lead, 0.2, 0.6, "opens fire just before the kill")
	await wait_seconds(Missile.FIRE_AFTER + 0.1)
	assert_false(tracers.emitting, "stops soon after")


func test_ciws_fires_from_the_cruiser_in_the_replay() -> void:
	var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
	var missile := _intercepted_missile()
	missile.ciws_at = cruiser.global_position
	missile.launch(game.grid.get_hex_center(Vector2i(5, 7)), Vector2i(24, 9), 0.0, true)
	assert_almost_eq(missile.gun_at, game.effects.to_local(cruiser.global_position), Vector2.ONE)
	assert_eq(
		game.grid.side_of(game.grid.get_hex_from_coords(missile.kill_at)),
		-1,
		"still killed over no-man's-land"
	)
	await wait_for_signal(missile.done, 5)


func test_intercepting_cruiser_recorded_for_the_replay() -> void:
	seed(1)
	var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
	spawn(p1, "corvette", Vector2i(24, 9))
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	while not p1.roll_intercept(destroyer, "fire", Vector2i(24, 9)):
		pass
	destroyer.intercepted = true
	game.turn_replay.begin(destroyer, "fire", Vector2i(24, 9))
	assert_eq(game.turn_replay.recording.props["ciws_at"], cruiser.global_position)


func test_missile_released_past_no_mans_land_dies_soon_after() -> void:
	var missile := _intercepted_missile()
	var release := game.grid.get_hex_center(Vector2i(18, 7))
	missile.launch(release, Vector2i(26, 7), 0.0, true)
	assert_almost_eq(missile.kill_at.distance_to(release), Missile.RELEASE_KILL, 0.1)
	await wait_seconds(2.5)
