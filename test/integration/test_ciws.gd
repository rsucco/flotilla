extends GutTest
# Passive - Missile Defense: cruisers shooting down missiles and nukes

const ROOT_SCENE := preload("res://root.tscn")
const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const Timed := preload("res://test/timed.gd")

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
	var cruiser := spawn(p1, "cruiser", Vector2i(25, 2))
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	destroyer.ap = 2
	destroyer.fire_remaining = 1
	destroyer.intercepted = true
	destroyer.ciws_at = cruiser.global_position
	await Timed.finish(destroyer.fire.bind(Vector2i(24, 9)))
	var missile := missiles[0]
	var at := game.grid.get_hex_from_coords(missile.position)
	assert_eq(at.x, Grid.NO_MANS_LAND, "dies over no-man's-land")
	assert_not_null(missile.tracers, "CIWS fired")
	var edge_x := missile.tracers.position.x
	assert_between(edge_x, missile.position.x, game.grid.get_hex_center(Vector2i(16, 0)).x)
	var bearing := game.effects.to_local(cruiser.global_position).direction_to(missile.kill_at)
	assert_almost_eq(missile.tracers.direction, bearing, Vector2.ONE * 0.01, "from the cruiser")
	await wait_seconds(2.5)


func _intercepted_missile(cruiser_at: Vector2i = Vector2i(24, 7)) -> Missile:
	var missile: Missile = MISSILE_SCENE.instantiate()
	missile.grid = game.grid
	missile.intercepted = true
	missile.ciws_at = game.grid.get_hex_center(cruiser_at)
	game.effects.add_child(missile)
	return missile


func test_ciws_fires_just_before_the_kill_and_briefly_after() -> void:
	var missile := _intercepted_missile()
	missile.launch(game.grid.get_hex_center(Vector2i(5, 7)), Vector2i(24, 9), 0.0, true)
	await wait_until(func() -> bool: return missile.ciws_sound != null, 5)
	var heard := Time.get_ticks_msec()
	var sound := missile.ciws_sound
	await wait_until(func() -> bool: return missile.tracers != null, 5)
	var opened := Time.get_ticks_msec()
	var tracers := missile.tracers
	assert_between((opened - heard) / 1000.0, 0.15, 0.5, "heard a little before it's seen")
	await wait_for_signal(missile.done, 5)
	var lead := (Time.get_ticks_msec() - opened) / 1000.0
	assert_between(lead, 0.2, 0.6, "opens fire just before the kill")
	await wait_seconds(Missile.FIRE_AFTER + 0.1)
	assert_false(tracers.emitting, "stops soon after")
	assert_true(
		is_instance_valid(sound) and sound.volume_db == Missile.CIWS_VOLUME_DB, "still heard"
	)
	await wait_seconds(Missile.SOUND_AFTER + Missile.SOUND_FADE)
	assert_false(is_instance_valid(sound), "then fades out")


func test_ciws_fires_from_the_cruiser_in_the_replay() -> void:
	var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
	var missile := _intercepted_missile()
	missile.ciws_at = cruiser.global_position
	missile.ciws_shown = true
	missile.launch(game.grid.get_hex_center(Vector2i(5, 7)), Vector2i(24, 9), 0.0, true)
	assert_almost_eq(missile.gun_at, game.effects.to_local(cruiser.global_position), Vector2.ONE)
	assert_eq(
		game.grid.side_of(game.grid.get_hex_from_coords(missile.kill_at)),
		-1,
		"still killed over no-man's-land"
	)
	await wait_for_signal(missile.done, 5)


# Global angle the mount's sprite (pointing up) has when aimed at `at`
func _aim(cruiser: Cruiser, at: Vector2) -> float:
	return cruiser.ciws.global_position.direction_to(at).angle() + PI / 2


# The replay starts the mount turning when the CIWS is first heard. Checked
# against the timings, as test frames can be far longer than the game's.
func test_ciws_mount_turns_any_way_round_before_the_tracers_show() -> void:
	assert_lt(PI / Cruiser.CIWS_SLEW, Missile.SOUND_LEAD * 0.5, "with time to spare")


func test_ciws_mount_tracks_the_missile_then_returns_to_the_bow() -> void:
	var cruiser: Cruiser = spawn(p1, "cruiser", Vector2i(24, 7), 1)
	var missile := _intercepted_missile()
	missile.ciws_at = cruiser.global_position
	missile.ciws_shown = true
	missile.launch(game.grid.get_hex_center(Vector2i(5, 7)), Vector2i(24, 9), 0.0, true)
	cruiser.track(missile)
	await wait_for_signal(missile.done, 5)
	await wait_process_frames(2)
	var off := angle_difference(
		cruiser.ciws.global_rotation, _aim(cruiser, missile.global_position)
	)
	assert_almost_eq(off, 0.0, 0.05, "on the missile at the kill")
	await wait_until(func() -> bool: return missile.fading, 5)
	await wait_seconds(0.6)
	assert_almost_eq(cruiser.ciws.rotation, 0.0, 0.001, "back to the bow")


func test_replay_shows_the_intercepting_cruisers_ciws() -> void:
	var cruiser: Cruiser = spawn(p1, "cruiser", Vector2i(24, 7))
	var other: Cruiser = spawn(p1, "cruiser", Vector2i(24, 2))
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	destroyer.intercepted = true
	destroyer.ciws_at = cruiser.global_position
	game.turn_replay.begin(destroyer, "fire", Vector2i(24, 9))
	game.turn_replay.land()
	game.turn_replay.end()
	game.turn_replay.play()
	await wait_until(func() -> bool: return cruiser.tracking != null, 10)
	assert_true(cruiser.tracking.ciws_shown, "the replayed missile")
	assert_null(other.tracking, "only the one shooting it down")
	await wait_until(func() -> bool: return not game.turn_replay.playing, 10)


func test_intercepting_cruiser_recorded_for_the_replay() -> void:
	seed(1)
	var cruiser := spawn(p1, "cruiser", Vector2i(24, 7))
	spawn(p1, "corvette", Vector2i(24, 9))
	var destroyer := spawn(p0, "destroyer", Vector2i(5, 7))
	while not p1.roll_intercept(destroyer, "fire", Vector2i(24, 9)):
		pass
	destroyer.intercepted = true
	destroyer.ciws_at = p1.interceptor.global_position
	game.turn_replay.begin(destroyer, "fire", Vector2i(24, 9))
	assert_eq(game.turn_replay.recording.props["ciws_at"], cruiser.global_position)


func test_missile_released_past_no_mans_land_dies_soon_after() -> void:
	var missile := _intercepted_missile()
	var release := game.grid.get_hex_center(Vector2i(18, 7))
	missile.launch(release, Vector2i(29, 7), 0.0, true)
	assert_almost_eq(missile.kill_at.distance_to(release), Missile.RELEASE_KILL, 0.1)
	var cruiser := game.grid.get_hex_center(Vector2i(24, 7))
	assert_almost_eq(
		missile.gun_at,
		missile.kill_at.move_toward(cruiser, Missile.RELEASE_TRACERS),
		Vector2.ONE,
		"just the last stretch, from the cruiser's bearing"
	)
	await wait_seconds(2.5)


func test_missile_released_close_to_its_target_dies_halfway() -> void:
	var missile := _intercepted_missile()
	var release := game.grid.get_hex_center(Vector2i(18, 7))
	var target := game.grid.get_hex_center(Vector2i(20, 7))
	missile.launch(release, Vector2i(20, 7), 0.0, true)
	assert_almost_eq(missile.kill_at, release.lerp(target, 0.5), Vector2.ONE)
	await wait_seconds(2.0)


func test_missile_released_over_no_mans_land_dies_on_the_way_in() -> void:
	var missile := _intercepted_missile()
	var release := game.grid.get_hex_center(Vector2i(Grid.NO_MANS_LAND, 7))
	missile.launch(release, Vector2i(29, 7), 0.0, true)
	assert_almost_eq(missile.kill_at.distance_to(release), Missile.RELEASE_KILL, 0.1)
	await wait_seconds(2.0)
