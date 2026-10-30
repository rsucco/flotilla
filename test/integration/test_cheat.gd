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
