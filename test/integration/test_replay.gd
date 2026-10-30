extends GutTest
# Replaying a player's attacks for the opponent at the hot-seat swap

const ROOT_SCENE := preload("res://root.tscn")
const GameDriver := preload("res://test/game_driver.gd")

var game: Root
var driver: GameDriver


func before_each() -> void:
	# GUT's own window would catch the board clicks
	get_node("/root/GutRunner/GutLayer").visible = false
	Engine.time_scale = 4.0
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	driver.ready_abilities(game.players[0])


func after_each() -> void:
	Engine.time_scale = 1.0
	get_node("/root/GutRunner/GutLayer").visible = true


func replay_done() -> bool:
	return not game.turn_replay.playing


func test_records_attacks_but_not_moves() -> void:
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.act("cruiser", "Forward")
	assert_eq(game.turn_replay.actions.size(), 1)
	var action: TurnReplay.Action = game.turn_replay.actions[0]
	assert_eq(action.hit_ships, [driver.ship_of(1, "destroyer")] as Array[Ship])
	assert_eq(action.smoke.size(), 1)


func test_damage_appears_as_the_replay_lands() -> void:
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	var smoke: CPUParticles2D = game.turn_replay.actions[0].smoke[0]
	await driver.end_turn()
	await driver.swap(true)
	await wait_process_frames(1)
	assert_true(game.turn_replay.playing, "replay started")
	assert_false(smoke.visible, "hit not shown before the shell lands")
	await driver.wait_until(replay_done, 20, "the replay")
	assert_true(smoke.visible, "hit shown once it lands")
	assert_true(game.turn_replay.actions.is_empty(), "cleared for player 2's turn")


func test_sunk_ships_kept_until_replayed() -> void:
	var sub := driver.ship_of(1, "submarine")
	await driver.act("destroyer", "Special", sub.hex)
	assert_true(sub.sunk)
	await driver.end_turn()
	await wait_seconds(2)
	assert_true(is_instance_valid(sub), "kept after its sinking effect")
	await driver.swap(true)
	await wait_process_frames(1)
	assert_true(sub.visible, "afloat again at the start of the replay")
	await driver.wait_until(replay_done, 20, "the replay")
	assert_false(sub.visible, "shown sinking")
	assert_false(sub.held, "frees itself once its sound ends")


func test_skip_jumps_to_the_end_result() -> void:
	await driver.act("battleship", "Special", GameDriver.spot(1, "cruiser"))
	var smoke: Array[CPUParticles2D] = game.turn_replay.actions[0].smoke
	await driver.end_turn()
	await driver.swap(true)
	# Skip once the replayed shells are in the air
	await driver.wait_until(
		func() -> bool:
			return game.turn_replay.spawned.any(func(n: Node) -> bool: return n is Projectile),
		20,
		"replayed shells"
	)
	var in_flight := game.turn_replay.spawned.duplicate()
	driver.press(game.turn_replay.get_node("Bar/Row/Skip"))
	assert_false(game.turn_replay.playing)
	assert_eq(Engine.time_scale, 4.0, "time scale restored")
	for s in smoke:
		assert_true(s.visible)
	await wait_process_frames(2)
	for node: Variant in in_flight:
		assert_false(is_instance_valid(node), "replayed shells removed")
	assert_eq(
		game.players[0].get_children().filter(func(n: Node) -> bool: return n is Ship and n.ghost),
		[],
		"ghosts removed"
	)


func test_speed_doubles_the_current_time_scale() -> void:
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.swap(true)
	await wait_process_frames(1)
	driver.press(game.turn_replay.get_node("Bar/Row/Speed"))
	assert_eq(Engine.time_scale, 8.0)
	await driver.wait_until(replay_done, 20, "the replay")
	assert_eq(Engine.time_scale, 4.0, "restored afterwards")


func test_mine_replay_does_not_show_where_it_went() -> void:
	var mine := Vector2i(28, 2)
	await driver.act("destroyer", "Secondary", mine)
	await driver.end_turn()
	await driver.swap(true)
	await wait_process_frames(1)
	var ghost: Destroyer
	for child in game.players[0].get_children():
		if child is Destroyer and child.ghost:
			ghost = child
	var path := ghost.sh60.path.curve
	var mine_at := ghost.sh60.to_local(game.grid.get_hex_center(mine))
	for i in path.point_count:
		assert_gt(path.get_point_position(i).distance_to(mine_at), 100.0, "path stays away")
	assert_false(ghost.sh60.mining, "nothing dropped")
	await driver.wait_until(replay_done, 30, "the replay")


func test_watch_choice_is_remembered_per_player() -> void:
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.swap(false)
	assert_false(game.players[1].watch_replay)
	assert_true(game.players[0].watch_replay, "player 1 unaffected")
	await driver.act("battleship", "Fire", GameDriver.spot(0, "destroyer"))
	await driver.end_turn()
	var dialog := await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	assert_true((dialog.get_node("VBoxContainer/WatchReplay") as CheckBox).button_pressed)


func test_no_replay_offered_without_attacks() -> void:
	await driver.end_turn()
	var dialog := await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	assert_false(dialog.get_node("VBoxContainer/WatchReplay").visible)


func first_shell() -> Projectile:
	for node in game.turn_replay.spawned:
		if is_instance_valid(node) and node is Projectile:
			return node
	return null


func shell_over(side: int) -> bool:
	var shell := first_shell()
	return (
		shell != null
		and game.grid.side_of(game.grid.get_hex_from_coords(shell.global_position)) == side
	)


func test_shells_hidden_until_they_cross_over() -> void:
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.swap(true)
	await driver.wait_until(
		func() -> bool: return shell_over(0), 20, "a shell over player 1's side"
	)
	await wait_process_frames(1)
	assert_false(first_shell().visible, "hidden over the attacker's side")
	await driver.wait_until(func() -> bool: return shell_over(1), 20, "the shell to cross over")
	await wait_process_frames(1)
	assert_true(first_shell().visible, "shown over the defender's side")


func test_battery_shells_always_shown() -> void:
	await driver.act("coastal_battery", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.swap(true)
	await driver.wait_until(
		func() -> bool: return shell_over(0), 20, "a shell over player 1's side"
	)
	await wait_process_frames(1)
	assert_true(first_shell().visible, "the battery already gave itself away")


func test_mine_blasts_are_replayed() -> void:
	# Player 2's mine in front of player 1's cruiser
	var cruiser := driver.ship_of(0, "cruiser")
	var mine := game.grid.get_hex_neighbor(game.grid.get_hex_neighbor(cruiser.hex, 0), 0)
	game.grid.tile(mine).is_mined = true
	await driver.act("cruiser", "Forward")
	assert_eq(game.turn_replay.actions.size(), 1)
	assert_eq(game.turn_replay.actions[0].kind, "mine")
	assert_eq(game.turn_replay.actions[0].target, mine)
	await driver.end_turn()
	await driver.swap(true)
	await driver.wait_until(
		func() -> bool:
			return game.turn_replay.spawned.any(func(n: Node) -> bool: return n is CPUParticles2D),
		10,
		"the blast"
	)
	await wait_process_frames(1)
	for node in game.turn_replay.spawned:
		if is_instance_valid(node) and node is CPUParticles2D:
			assert_true(node.visible, "shown on the attacker's side")
	await driver.wait_until(replay_done, 20, "the replay")


func revealed_shown(kind: String) -> bool:
	return game.players[1].temp_revealed_ships.any(
		func(s: Ship) -> bool: return s.ship_type == kind and s.is_inside_tree() and s.visible
	)


func test_battery_revealed_as_it_fires() -> void:
	await driver.act("coastal_battery", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.swap(true)
	await wait_process_frames(2)
	assert_true(game.turn_replay.playing, "replay started")
	assert_true(revealed_shown("coastal_battery"), "shown before the shell lands")
	await driver.wait_until(replay_done, 20, "the replay")
	assert_true(revealed_shown("coastal_battery"), "still shown for the turn")


func test_sub_revealed_by_its_sonar_pulse() -> void:
	await driver.act("submarine", "Secondary", Vector2i(20, 10))
	await driver.end_turn()
	await driver.swap(true)
	await wait_process_frames(2)
	assert_true(game.turn_replay.playing, "replay started")
	assert_true(revealed_shown("submarine"), "shown as the pulse plays")
	await driver.wait_until(replay_done, 20, "the replay")
	assert_true(revealed_shown("submarine"), "still shown for the turn")


func test_replay_shows_the_defenders_side_without_spoilers() -> void:
	var sub := driver.ship_of(1, "submarine")
	await driver.act("destroyer", "Special", sub.hex)
	assert_eq(driver.fleet_count("OpponentFleet"), 7, "the attacker sees the sinking")
	await driver.end_turn()
	await driver.swap(true)
	await wait_process_frames(2)
	assert_true(game.turn_replay.playing, "replay started")
	assert_eq(game.gui.ship_name.text, "", "no attacker's ship in the panel")
	assert_true(driver.action_button("Fire").disabled, "no attacker's buttons")
	assert_eq(driver.fleet_count("YourFleet"), 8, "defender's fleet, sub not sunk yet")
	await driver.wait_until(func() -> bool: return not sub.held, 20, "the sinking")
	assert_eq(driver.fleet_count("YourFleet"), 7, "counted once shown")
	await driver.wait_until(replay_done, 20, "the replay")
