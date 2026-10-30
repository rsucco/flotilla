extends RefCounted
# Plays a real game through mouse input and button presses, as a player would.
# Shared by the integration tests and the screenshot script. Failures are
# reported with push_error, which fails the current GUT test.

# Ship centers for player 0, facing up; player 1 mirrors them 16 columns over.
# The tender sits next to the destroyer so UNREP has a target.
const LAYOUT := {
	"coastal_battery": Vector2i(1, 2),
	"corvette": Vector2i(3, 3),
	"destroyer": Vector2i(5, 5),
	"supply_tender": Vector2i(6, 5),
	"submarine": Vector2i(7, 5),
	"cruiser": Vector2i(9, 5),
	"battleship": Vector2i(11, 7),
	"carrier": Vector2i(13, 7),
}

var game: Root
var tree: SceneTree
var moves := 0


func _init(root: Root) -> void:
	game = root
	tree = root.get_tree()
	for player in game.players:
		player.made_move.connect(func() -> void: moves += 1)


static func spot(player: int, ship_type: String) -> Vector2i:
	return LAYOUT[ship_type] + Vector2i(player * 16, 0)


# Returns false (and reports why) if `condition` isn't met within `timeout` seconds
func wait_until(condition: Callable, timeout: float, what: String) -> bool:
	var end := Time.get_ticks_msec() + timeout * 1000
	while not condition.call():
		if Time.get_ticks_msec() > end:
			push_error("Timed out waiting for " + what)
			return false
		await tree.process_frame
	return true


func hover(hex: Vector2i) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = game.grid.get_hex_center(hex)
	motion.global_position = motion.position
	game.get_viewport().push_input(motion, true)


# Waits a frame first, as real input would: freed dialogs are only gone by then
func click(hex: Vector2i, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await tree.process_frame
	hover(hex)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = game.grid.get_hex_center(hex)
		event.global_position = event.position
		game.get_viewport().push_input(event, true)


func press(button: Button) -> void:
	if button.disabled:
		push_error(button.name + " is disabled")
		return
	button.pressed.emit()


func action_button(button: String) -> Button:
	return game.gui.get_node("GUIGrid/Actions/" + button)


# Fixed islands, one per side, for the coastal batteries
func prepare_board() -> void:
	for column: Array in game.grid.tiles:
		for tile: Tile in column:
			tile.island = false
	for player in 2:
		game.grid.tile(spot(player, "coastal_battery")).island = true


# Both players pick the classic fleet (one of everything) and place it
func start_game() -> void:
	for player in game.players:
		var dialog: Node = await find_dialog(player, "res://gui/ship_selection.tscn")
		if dialog == null:
			return
		# The first dialog opened before prepare_board() changed the islands
		dialog.set_island_tiles(game.grid.get_num_island_tiles(player.player_num))
		press(dialog.get_node("VBoxContainer/Buttons/Classic"))
		press(dialog.get_node("VBoxContainer/Buttons/OK"))
		for _i in LAYOUT.size():
			var ship := await placing_ship(player)
			if ship == null:
				return
			await click(spot(player.player_num, ship.ship_type))
	await wait_until(func() -> bool: return game.current_turn == 1, 5, "turn 1")


func find_dialog(parent: Node, scene: String) -> Node:
	await wait_until(func() -> bool: return _dialog(parent, scene) != null, 5, scene)
	return _dialog(parent, scene)


func _dialog(parent: Node, scene: String) -> Node:
	for child in parent.get_children():
		if child.scene_file_path == scene and not child.is_queued_for_deletion():
			return child
	return null


func placing_ship(player: Player) -> Ship:
	await wait_until(func() -> bool: return _placing(player) != null, 5, "a ship to place")
	return _placing(player)


func _placing(player: Player) -> Ship:
	for child in player.get_children():
		if child is Ship and child.placing:
			return child
	return null


# Skips the cooldowns, which otherwise start full
func ready_abilities(player: Player) -> void:
	for ship in player.ships:
		ship.special.cooldown_current = 0
		ship.secondary.cooldown_current = 0


# Selects our ship of `ship_type`, presses `button`, clicks `target` (if
# given), and waits for the move and its animation to finish
func act(ship_type: String, button: String, target: Vector2i = Grid.OFF_GRID) -> void:
	await select(ship_type)
	var before := moves
	press(action_button(button))
	if target != Grid.OFF_GRID:
		await click(target)
	await wait_until(func() -> bool: return moves > before, 30, ship_type + " " + button)


func select(ship_type: String) -> void:
	var ship := ship_of(game.player_up, ship_type)
	if ship == null:
		push_error("No " + ship_type + " left to select")
		return
	await click(ship.hex)


func ship_of(player: int, ship_type: String) -> Ship:
	for ship in game.players[player].ships:
		if ship.ship_type == ship_type:
			return ship
	return null


# Ends the turn of every ship with AP left. Presses at least once, since the
# game waits for a move even when none are left (e.g. the opponent is sunk).
func end_turn() -> void:
	var player := game.players[game.player_up]
	while true:
		var before := moves
		press(action_button("EndTurn"))
		if not await wait_until(func() -> bool: return moves > before, 5, "end turn"):
			return
		if not player.has_moves():
			return


# Skips the turn replay unless `watch` is set
func swap(watch: bool = false) -> void:
	var dialog := await find_dialog(game, "res://gui/local_turn_swap.tscn")
	if dialog != null:
		(dialog.get_node("VBoxContainer/WatchReplay") as CheckBox).button_pressed = watch
		press(dialog.get_node("VBoxContainer/OK"))


# Total of the "xN" counts in a fleet panel
func fleet_count(panel: String) -> int:
	var total := 0
	var icons := game.gui.get_node("GUIGrid/" + panel + "/" + panel + "Icons")
	for row in icons.get_children():
		if not row.is_queued_for_deletion():
			total += int((row.get_child(1) as Label).text.trim_prefix("x"))
	return total
