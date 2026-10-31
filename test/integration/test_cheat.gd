extends GutTest
# The V cheat that shows both fleets (fl-7q4)

const ROOT_SCENE := preload("res://root.tscn")
const GameDriver := preload("res://test/game_driver.gd")


func press_v(game: Root) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_V
	event.pressed = true
	game.get_viewport().push_input(event)


func test_v_shows_both_fleets_and_back() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	var enemy: Ship = game.players[1].ships[0]
	assert_false(enemy.visible, "hidden normally")
	press_v(game)
	await wait_physics_frames(2)
	assert_true(enemy.visible, "shown by the cheat")
	assert_true(game.players[0].ships[0].visible, "own fleet still shown")
	press_v(game)
	await wait_physics_frames(2)
	assert_false(enemy.visible, "hidden again")
	assert_true(game.players[0].ships[0].visible, "own fleet still shown")
	get_node("/root/GutRunner/GutLayer").visible = true


func test_turning_v_off_keeps_revealed_ships() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	var enemy: Ship = game.players[1].ships[0]
	press_v(game)
	await wait_physics_frames(2)
	game.players[1].reveal(enemy, " revealed by Recon Flight")
	press_v(game)
	await wait_physics_frames(2)
	assert_true(enemy.visible, "still revealed")
	get_node("/root/GutRunner/GutLayer").visible = true


func test_c_readies_the_active_players_abilities() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	await driver.select("submarine")
	assert_true(driver.action_button("Special").disabled, "nuke on cooldown")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = true
	game.get_viewport().push_input(event)
	await wait_physics_frames(2)
	assert_eq(driver.ship_of(0, "submarine").special.cooldown_current, 0)
	assert_false(driver.action_button("Special").disabled, "nuke ready")
	assert_gt(driver.ship_of(1, "submarine").special.cooldown_current, 0, "not the opponent's")
	get_node("/root/GutRunner/GutLayer").visible = true
