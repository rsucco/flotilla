extends GutTest
# A still board isn't redrawn: on a handheld, redrawing every frame for
# nothing roughly doubles the power the game draws (fl-4te.3)

const ROOT_SCENE := preload("res://game/root.tscn")
const GameDriver := preload("res://test/game_driver.gd")

var game: Root
var draws := {}


func before_each() -> void:
	get_node("/root/GutRunner/GutLayer").visible = false
	game = add_child_autofree(ROOT_SCENE.instantiate())
	var driver := GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()
	await wait_process_frames(5)
	draws.clear()
	for item: CanvasItem in [game]:
		item.draw.connect(func() -> void: draws[item] = draws.get(item, 0) + 1)


func after_each() -> void:
	get_node("/root/GutRunner/GutLayer").visible = true


func test_stick_motion_doesnt_redraw_the_board() -> void:
	# As a Steam Deck's controls send, hundreds a second, even untouched
	for i in 20:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_RIGHT_X
		motion.axis_value = 0.01 * i
		game.get_viewport().push_input(motion)
		await wait_process_frames(1)
	assert_eq(draws.get(game, 0), 0)

