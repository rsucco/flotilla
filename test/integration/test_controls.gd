extends GutTest
# Playing from the keyboard and a controller: each shortcut does what its
# button would, and only when that button could be pressed

const ROOT_SCENE := preload("res://root.tscn")
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


func after_each() -> void:
	Input.action_release("action_end_turn")
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
	await pad(JOY_BUTTON_X)
	assert_true(player.aiming.special, "X arms the special")
	await pad(JOY_BUTTON_A)
	assert_true(player.aiming.fire, "A arms the guns")
	await pad(JOY_BUTTON_B)
	assert_false(player.aiming.values().has(true), "B stops aiming")
	assert_not_null(player.selected_ship, "but keeps the ship")
	await pad(JOY_BUTTON_B)
	assert_null(player.selected_ship, "then lets it go")


func test_d_pad_moves_the_ship() -> void:
	await driver.select("battleship")
	var ship := player.selected_ship
	var at := ship.hex
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
