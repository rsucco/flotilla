extends GutTest
# The F-35's planned flight paths

const ROOT_SCENE := preload("res://root.tscn")
const GameDriver := preload("res://test/game_driver.gd")
const HEADINGS: Array[int] = [0, 60, 120, 180, 240, 300]

var carrier: Carrier
var f35: F35


func before_each() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	get_node("/root/GutRunner/GutLayer").visible = false
	await driver.start_game()
	get_node("/root/GutRunner/GutLayer").visible = true
	carrier = driver.ship_of(0, "carrier")
	f35 = carrier.f35


func after_each() -> void:
	Engine.time_scale = 1.0


# The plane's simulated positions, in the path's own coordinates
func track() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in f35.path.curve.point_count:
		points.append(f35.path.curve.get_point_position(i))
	return points


func test_launches_off_the_bow_and_lands_from_astern() -> void:
	for heading in HEADINGS:
		carrier.rotation_degrees = heading
		for plan: Callable in [
			f35.plan_strike.bind(Vector2i(27, 12)), f35.plan_recon.bind(Vector2i(24, 4))
		]:
			plan.call()
			var points := track()
			assert_lt(
				points[0].direction_to(points[1]).angle_to(F35.BOW),
				0.01,
				str("launch at ", heading)
			)
			var final := points[-2].direction_to(points[-1])
			assert_lt(absf(final.angle_to(F35.BOW)), 0.01, str("landing at ", heading))
			assert_eq(points[-1], Vector2.ZERO, "back on deck")


func test_never_turns_tighter_than_its_turn_radius() -> void:
	var max_turn := F35.STEP / F35.TURN_RADIUS + 0.001
	for heading in HEADINGS:
		carrier.rotation_degrees = heading
		for plan: Callable in [
			f35.plan_strike.bind(Vector2i(18, 3)), f35.plan_recon.bind(Vector2i(24, 4))
		]:
			plan.call()
			var points := track()
			for i in range(1, points.size() - 1):
				var turn := (points[i] - points[i - 1]).angle_to(points[i + 1] - points[i])
				assert_lt(absf(turn), max_turn, str("turn at point ", i, ", heading ", heading))


func test_strike_released_from_standoff_heading_at_the_target() -> void:
	var target := Vector2i(27, 12)
	for heading in HEADINGS:
		carrier.rotation_degrees = heading
		f35.plan_strike(target)
		var aim := f35.path.to_local(carrier.grid.get_hex_center(target))
		var release := f35.path.curve.sample_baked(f35.trigger_at)
		var ahead := f35.path.curve.sample_baked(f35.trigger_at + 10)
		assert_lt(release.distance_to(aim), F35.STANDOFF + F35.STEP, str("in range at ", heading))
		var off := release.direction_to(ahead).angle_to(release.direction_to(aim))
		assert_lt(absf(off), 0.35, str("heading at the target at ", heading))


func test_recon_pass_flies_straight_along_the_row() -> void:
	var row := 4
	# Columns 16 and 30 are both even, so the pass is level
	var y := carrier.grid.get_hex_center(Vector2i(16, row)).y
	for heading in HEADINGS:
		carrier.rotation_degrees = heading
		f35.plan_recon(Vector2i(24, row))
		var start := f35.path.to_global(f35.path.curve.sample_baked(f35.trigger_at))
		assert_almost_eq(start.x, carrier.grid.get_hex_center(Vector2i(16, row)).x, 1.0)
		for along in range(0, 500, 50):
			var point := f35.path.to_global(f35.path.curve.sample_baked(f35.trigger_at + along))
			assert_almost_eq(point.y, y, 2.0, str("on the row at ", heading))


func test_second_strike_restarts_from_the_deck() -> void:
	Engine.time_scale = 4.0
	await f35.bomb(Vector2i(20, 5))
	assert_true(f35.flying, "still heading home after the hit")
	f35.bomb(Vector2i(22, 9))
	assert_eq(f35.path_follow.progress, 0.0, "skips the rest of the first sortie")
	assert_true(f35.bombing, "on the second strike")
	await wait_for_signal(f35.done, 20)
