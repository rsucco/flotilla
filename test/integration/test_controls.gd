extends GutTest
# Playing from the keyboard and a controller: each shortcut does what its
# button would, and only when that button could be pressed

const ROOT_SCENE := preload("res://game/root.tscn")
const GameDriver := preload("res://test/game_driver.gd")

var game: Root
var driver: GameDriver
var player: LocalPlayer


func before_each() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	player = game.players[0]
	# GUT's own output panel holds the focus, which the cursor leaves alone
	get_viewport().gui_release_focus()


func after_each() -> void:
	Input.action_release("action_end_turn")
	Input.action_release("action_steer")
	Input.action_release("cursor_right")
	get_node("/root/GutRunner/GutLayer").visible = true


func pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	game.get_viewport().push_input(event)
	await wait_process_frames(1)


func key(keycode: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	game.get_viewport().push_input(event)
	await wait_process_frames(1)


func test_shortcuts_need_a_ship_selected() -> void:
	# A turn starts with a ship selected
	await pad(JOY_BUTTON_B)
	assert_null(player.selected_ship)
	await pad(JOY_BUTTON_A)
	Input.action_press("action_steer")
	await pad(JOY_BUTTON_DPAD_UP)
	assert_false(player.aiming.values().has(true), "nothing to fire with")
	assert_true(player.ships.all(func(s: Ship) -> bool: return s.ap == s.default_ap), "nor move")


func test_bumpers_and_tab_go_between_ships() -> void:
	await driver.select("battleship")
	var battleship := player.selected_ship
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	var next := player.selected_ship
	assert_ne(next, battleship, "RB: the next ship")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(player.selected_ship, battleship, "LB: back again")
	await key(KEY_TAB)
	assert_eq(player.selected_ship, next, "Tab: the next ship")
	await key(KEY_TAB, true)
	assert_eq(player.selected_ship, battleship, "Shift+Tab: back again, not on as well")


func test_face_buttons_arm_attacks_and_b_backs_out() -> void:
	driver.ready_abilities(player)
	await driver.select("battleship")
	# Off our own ships, where A would pick the ship instead
	game.cursor.move_to(Vector2i(22, 7))
	await pad(JOY_BUTTON_X)
	assert_true(player.aiming.special, "X arms the special")
	await pad(JOY_BUTTON_B)
	await pad(JOY_BUTTON_A)
	assert_true(player.aiming.fire, "A arms the guns")
	await pad(JOY_BUTTON_B)
	assert_false(player.aiming.values().has(true), "B stops aiming")
	assert_not_null(player.selected_ship, "but keeps the ship")
	await pad(JOY_BUTTON_B)
	assert_null(player.selected_ship, "then lets it go")


func test_d_pad_alone_leaves_the_ship_be() -> void:
	await driver.select("battleship")
	var ship := player.selected_ship
	await pad(JOY_BUTTON_DPAD_UP)
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await wait_seconds(0.3)
	assert_eq(ship.ap, ship.default_ap, "it's the cursor's")


func test_rt_and_d_pad_steer_the_ship() -> void:
	await driver.select("battleship")
	var ship := player.selected_ship
	var at := ship.hex
	Input.action_press("action_steer")
	await pad(JOY_BUTTON_DPAD_UP)
	await driver.wait_until(func() -> bool: return ship.hex != at, 5, "moving")
	assert_eq(ship.ap, ship.default_ap - 1, "forward")
	var heading := ship.direction
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await driver.wait_until(func() -> bool: return ship.ap == ship.default_ap - 3, 5, "turning")
	assert_eq(ship.direction, heading + 60, "to starboard")


func test_end_turn_takes_a_hold() -> void:
	Input.action_press("action_end_turn")
	await wait_seconds(0.5)
	assert_eq(game.player_up, 0, "not yet")
	await wait_seconds(0.7)
	assert_eq(game.player_up, 1, "after a second")


func test_start_opens_the_menu_and_b_does_not() -> void:
	await pad(JOY_BUTTON_B)
	assert_false(game.pause_menu.visible, "B is cancel, not the menu")
	await pad(JOY_BUTTON_START)
	assert_true(game.pause_menu.visible, "Start opens it")
	await pad(JOY_BUTTON_START)
	assert_false(game.pause_menu.visible, "and closes it")


func test_held_the_cursor_steps_then_repeats() -> void:
	game.cursor.steer(Vector2.ZERO, 0.0)
	game.cursor.move_to(Vector2i(20, 7))
	game.cursor.steer(Vector2.RIGHT, 0.016)
	assert_eq(game.cursor.hex, Vector2i(21, 7), "one hex at once")
	game.cursor.steer(Vector2.RIGHT, 0.2)
	assert_eq(game.cursor.hex, Vector2i(21, 7), "a pause")
	for i in 3:
		game.cursor.steer(Vector2.RIGHT, 0.1)
	assert_eq(game.cursor.hex, Vector2i(24, 7), "then on while held")
	game.cursor.steer(Vector2.ZERO, 0.1)
	game.cursor.steer(Vector2(0.3, 0.9), 0.016)
	assert_eq(game.cursor.hex, Vector2i(24, 8), "mostly down is down")
	await wait_process_frames(1)
	assert_eq(game.grid.get_hex_from_coords(game.pointer), game.cursor.hex, "hovered")


func test_arrow_keys_and_left_stick_steer_the_cursor() -> void:
	var keys := {KEY_LEFT: "cursor_left", KEY_RIGHT: "cursor_right", KEY_UP: "cursor_up"}
	keys[KEY_DOWN] = "cursor_down"
	for keycode: Key in keys:
		var event := InputEventKey.new()
		event.keycode = keycode
		assert_true(event.is_action(keys[keycode]), keys[keycode])
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	assert_true(stick.is_action("cursor_up"), "the left stick")
	var d_pad := InputEventJoypadButton.new()
	d_pad.button_index = JOY_BUTTON_DPAD_UP
	assert_true(d_pad.is_action("cursor_up"), "the d-pad")


func test_the_cursor_holds_still_while_steering() -> void:
	game.cursor.move_to(Vector2i(20, 7))
	Input.action_press("action_steer")
	Input.action_press("cursor_right")
	await wait_process_frames(3)
	assert_eq(game.cursor.hex, Vector2i(20, 7), "RT held")
	Input.action_release("action_steer")
	await wait_process_frames(3)
	assert_eq(game.cursor.hex, Vector2i(21, 7), "let go")


func test_a_aims_then_fires_at_the_cursor() -> void:
	await driver.select("battleship")
	game.cursor.move_to(driver.ship_of(1, "destroyer").hex)
	await pad(JOY_BUTTON_A)
	assert_true(player.aiming.fire, "first A aims")
	await pad(JOY_BUTTON_A)
	await driver.wait_until(func() -> bool: return player.attacks == 1, 10, "the shot")
	assert_false(player.aiming.values().has(true), "done aiming")
	assert_eq(player.get_hover_hexes(Vector2i(22, 7)), [] as Array[Vector2i], "no target area")


func test_a_on_our_ship_picks_it() -> void:
	await driver.select("battleship")
	var cruiser := driver.ship_of(0, "cruiser")
	game.cursor.move_to(cruiser.hex)
	await pad(JOY_BUTTON_A)
	assert_eq(player.selected_ship, cruiser)
	assert_false(player.aiming.values().has(true), "without aiming")


func test_enter_clicks_at_the_cursor() -> void:
	await driver.select("battleship")
	await key(KEY_F)
	assert_true(player.aiming.fire, "F aims")
	game.cursor.move_to(driver.ship_of(1, "destroyer").hex)
	await key(KEY_ENTER)
	await driver.wait_until(func() -> bool: return player.attacks == 1, 10, "the shot")


func test_placing_with_the_cursor_and_buttons() -> void:
	var setup: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var setting_up := GameDriver.new(setup)
	setting_up.prepare_board()
	var dialog := await setting_up.find_dialog(setup.players[0], "res://gui/ship_selection.tscn")
	dialog.set_island_tiles(setup.grid.get_num_island_tiles(0))
	setting_up.press(dialog.get_node("VBoxContainer/Buttons/Classic"))
	setting_up.press(dialog.get_node("VBoxContainer/Buttons/OK"))
	var turned := false
	while not turned:
		var ship := await setting_up.placing_ship(setup.players[0])
		var spot := GameDriver.spot(0, ship.ship_type)
		setup.cursor.move_to(spot)
		await wait_process_frames(1)
		assert_eq(ship.hex, spot, ship.ship_type + " follows the cursor")
		# Batteries don't turn
		if not ship is CoastalBattery:
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_DPAD_RIGHT
			event.pressed = true
			setup.get_viewport().push_input(event)
			assert_eq(ship.direction, 0, "the d-pad alone doesn't turn it")
			Input.action_press("action_steer")
			setup.get_viewport().push_input(event)
			Input.action_release("action_steer")
			assert_eq(ship.direction, 60, "RT and the d-pad do")
			turned = true
		var a := InputEventJoypadButton.new()
		a.button_index = JOY_BUTTON_A
		a.pressed = true
		setup.get_viewport().push_input(a)
		assert_false(ship.placing, "A places it")


func wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	game.get_viewport().push_input(event)


func pan(by: float) -> void:
	var event := InputEventPanGesture.new()
	event.delta = Vector2(0, by)
	game.get_viewport().push_input(event)


# A wheel's notch or a trackpad's swipe turns a ship being placed once, even
# when a swipe arrives as many small events
func test_each_scroll_turns_a_ship_being_placed_once() -> void:
	var ship: Ship = load("res://ships/destroyer.tscn").instantiate()
	player.adopt(ship)
	ship.set_grid_position(Vector2i(7, 12), 0)
	ship.placing = true
	for i in 4:
		wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_eq(ship.direction, 60, "a burst of wheel events: one scroll")
	await wait_seconds(0.25)
	wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_eq(ship.direction, 0, "the next scroll, back again")
	await wait_seconds(0.25)
	for i in 4:
		pan(0.1)
	assert_eq(ship.direction, 0, "a trackpad swipe that's only just started")
	for i in 20:
		pan(0.1)
	assert_eq(ship.direction, 60, "then once, however long it goes on")
	ship.placing = false
	ship.queue_free()


func test_button_hints_only_after_a_controller_or_hotkey() -> void:
	var fire: Button = game.gui.find_child("Fire")
	var own := fire.icon
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(5, 0)
	game.get_viewport().push_input(mouse)
	assert_eq(fire.icon, own, "its own icon for mouse players")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	assert_ne(fire.icon, own, "the glyph once a controller's used")
	game.cursor.move_to(Vector2i(20, 7))
	assert_ne(fire.icon, own, "and kept while the cursor stands in for the mouse")
	game.get_viewport().push_input(mouse)
	assert_eq(fire.icon, own, "its own again as the real mouse moves")
	await key(KEY_TAB)
	assert_ne(fire.icon, own, "the glyph for a hotkey too")
	var end_turn: Control = game.gui.find_child("EndTurn").get_node("Glyph")
	assert_true(end_turn.visible, "End Turn's beside it")


func test_helm_glyphs_show_while_rt_is_held() -> void:
	var forward: Button = game.gui.find_child("Forward")
	var own := forward.icon
	var steer: Control = game.gui.find_child("Starboard").get_node("SteerGlyph")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(forward.icon, own, "its own arrow on a controller")
	assert_true(steer.visible, "with RT beside it")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	game.get_viewport().push_input(trigger)
	assert_ne(forward.icon, own, "the d-pad while RT is held")
	trigger.axis_value = 0.0
	game.get_viewport().push_input(trigger)
	assert_eq(forward.icon, own, "and its arrow again once let go")
	await key(KEY_TAB)
	assert_ne(forward.icon, own, "W shows on the keyboard, which needs no RT")
	assert_false(steer.visible, "nor RT")


func test_end_turn_shows_its_hold_filling() -> void:
	var fills: Array[float] = []
	player.end_turn_holding.connect(func(fraction: float) -> void: fills.append(fraction))
	Input.action_press("action_end_turn")
	await wait_seconds(0.5)
	assert_almost_eq(game.gui.end_turn_hold, 0.5, 0.15, "half way")
	await wait_seconds(0.7)
	assert_eq(game.gui.end_turn_hold, 0.0, "empty once the turn ends")
	assert_gt(fills.max(), 0.9, "filled up first")


func test_next_ship_goes_to_ships_that_can_still_fire() -> void:
	for ship in player.ships:
		ship.fire_remaining = 1 if ship.ship_type == "carrier" else 0
	await driver.select("destroyer")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(player.selected_ship.ship_type, "carrier", "past those that can't")
	var carrier := player.selected_ship
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_ne(player.selected_ship, carrier, "then on round the rest")


func test_switching_ships_while_a_shot_is_in_the_air() -> void:
	await driver.select("battleship")
	await key(KEY_F)
	game.cursor.move_to(driver.ship_of(1, "destroyer").hex)
	await key(KEY_ENTER)
	assert_true(player.animation_playing, "the shell's in the air")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	var next := player.selected_ship
	assert_ne(next.ship_type, "battleship", "picked another ship")
	var fire: Button = driver.action_button("Fire")
	assert_true(fire.disabled, "which waits for the shell to land")
	assert_false(driver.action_button("NextShip").disabled, "though Next Ship still works")
	await driver.wait_until(func() -> bool: return not player.animation_playing, 10, "landing")
	await wait_process_frames(1)
	assert_eq(player.selected_ship, next, "still the ship picked")
	assert_eq(fire.disabled, not next.can_fire(), "its buttons back")
