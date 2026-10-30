extends SceneTree
# Plays a scripted game with real rendering (not headless: that renders
# nothing) and saves a screenshot of each state, to compare against earlier
# builds. Runs on a virtual X display so no window takes focus:
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --display-driver x11 \
#     --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://test/screenshots/shots.gd -- <out dir>

const GameDriver := preload("res://test/game_driver.gd")

var out: String
var game: Root
var d: GameDriver


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	run.call_deferred()


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func enemy(ship_type: String) -> Vector2i:
	return GameDriver.spot(1 - game.player_up, ship_type)


# Starts an action, screenshots it `delay` seconds after the click, then
# waits for it to finish
func act_shot(
	ship_type: String, button: String, target: Vector2i, delay: float, shot_name: String
) -> void:
	await d.select(ship_type)
	var before := d.moves
	d.press(d.action_button(button))
	await d.click(target)
	await wait(delay)
	await shot(shot_name)
	await d.wait_until(func() -> bool: return d.moves > before, 30, shot_name)


func run() -> void:
	var title: Node = load("res://title_screen.tscn").instantiate()
	root.add_child(title)
	await wait(1.0)
	await shot("01_title")
	title.free()

	seed(3)
	game = load("res://root.tscn").instantiate()
	root.add_child(game)
	d = GameDriver.new(game)
	d.prepare_board()

	for player in game.players:
		var dialog := await d.find_dialog(player, "res://gui/ship_selection.tscn")
		dialog.set_island_tiles(game.grid.get_num_island_tiles(player.player_num))
		d.press(dialog.get_node("VBoxContainer/Buttons/Classic"))
		if player.player_num == 0:
			await wait(0.5)
			await shot("02_ship_selection")
		d.press(dialog.get_node("VBoxContainer/Buttons/OK"))
		for i in GameDriver.LAYOUT.size():
			var ship := await d.placing_ship(player)
			if player.player_num == 0 and i == 4:
				d.hover(GameDriver.spot(0, ship.ship_type))
				await wait(0.3)
				await shot("03_placement")
			await d.click(GameDriver.spot(player.player_num, ship.ship_type))
	await d.wait_until(func() -> bool: return game.current_turn == 1, 5, "turn 1")
	d.ready_abilities(game.players[0])

	await d.select("battleship")
	await wait(0.5)
	await shot("04_turn_start_battleship_selected")
	await act_shot("battleship", "Fire", Vector2i(19, 10), 1.15, "05_battleship_shell_in_flight")
	await act_shot("destroyer", "Special", enemy("submarine"), 1.5, "06_sh60_outbound")
	await act_shot("cruiser", "Special", enemy("destroyer"), 0.2, "07_ew_strike")
	await act_shot("carrier", "Special", enemy("battleship"), 1.5, "08_f35_recon")
	await act_shot("submarine", "Special", Vector2i(27, 12), 1.0, "09_nuke_in_flight")
	await wait(0.3)
	await act_shot("cruiser", "Fire", enemy("carrier"), 1.2, "10_missile_in_flight")
	await act_shot("battleship", "Special", enemy("coastal_battery"), 1.3, "11_salvo")
	await wait(3.0)
	d.hover(enemy("coastal_battery"))
	await wait(1.0)
	await shot("12_markers_and_tile_history")
	await d.end_turn()

	var swap := await d.find_dialog(game, "res://gui/local_turn_swap.tscn")
	await wait(0.3)
	await shot("13_turn_swap")
	d.press(swap.get_node("VBoxContainer/OK"))
	# Player 1's first shot, replayed for player 2
	await wait(1.3)
	await shot("14_replay")
	d.press(game.turn_replay.get_node("Bar/Row/Skip"))
	await wait(0.5)
	await shot("15_player2_view")
	await d.end_turn()
	await d.swap()

	for ship in game.players[1].ships.duplicate():
		ship.sink()
	await d.end_turn()
	await d.find_dialog(game, "res://gui/victory.tscn")
	await wait(0.5)
	await shot("16_victory")
	quit()
