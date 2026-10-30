class_name Root
extends Node2D

const ROW_LABELS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"]
const FONT_SIZE := 11
const FONT := preload("res://opensans.ttf")
const MINE_TEXTURE := preload("res://ships/sprites/projectiles/mine.png")
const HITMISS_TEXTURE := preload("res://gui/sprites/hitmiss.png")
const TURN_SWAP_SCENE := preload("res://gui/local_turn_swap.tscn")
const VICTORY_SCENE := preload("res://gui/victory.tscn")

# "Replay This Game" keeps the board and both fleets across a scene reload
static var replay := {}

var grid: Grid
var players: Array[LocalPlayer] = []
var player_up := 0
# Projectiles and other effects, drawn above the ships
var effects: Node2D
var current_turn := 0
var swapping := false
# The board and fleets this game started with, once both players have chosen
var setup := {}
# Testing cheat (debug builds): V shows both fleets
var reveal_all := false

@onready var gui: GUI = $GUI
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var turn_replay: TurnReplay = $TurnReplay


func _ready() -> void:
	effects = Node2D.new()
	effects.name = "Effects"
	players = [LocalPlayer.new(0), LocalPlayer.new(1)]
	players[0].opponent = players[1]
	players[1].opponent = players[0]
	for player in players:
		player.effects = effects
		player.tile_history = $TileHistory
		add_child(player)
		player.ship_shown.connect(gui.update_ship_info)
		player.buttons_changed.connect(gui.set_buttons)
		player.fleet_changed.connect(_update_fleets)
		player.attack_started.connect(turn_replay.begin)
		player.attack_landed.connect(turn_replay.land)
		player.attack_resolved.connect(turn_replay.end)
		player.mine_blast.connect(turn_replay.mine_blast.bind(player))
	turn_replay.sinking_shown.connect(_update_fleets)
	gui.action_pressed.connect(func(action: String) -> void: players[player_up].press(action))
	add_child(effects)
	turn_replay.effects = effects
	play_game()


func _input(_event: InputEvent) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.physical_keycode == KEY_V:
		reveal_all = not reveal_all
		if not reveal_all:
			for player in players:
				for ship in player.ships:
					# Ships revealed by an ability are drawn translucent
					ship.visible = player.active or ship.modulate.a < 1.0


func _process(_delta: float) -> void:
	# Ships hide and show themselves all turn, so keep overriding them
	if reveal_all:
		for player in players:
			for ship in player.ships:
				ship.visible = true


func play_game() -> void:
	grid = Grid.new()
	for player in players:
		player.grid = grid
	$TileHistory.grid = grid
	turn_replay.grid = grid
	player_up = 0
	var selections: Array = []
	if not replay.is_empty():
		grid.set_islands(replay.islands)
		selections = replay.selections
		replay = {}
	# Ship selection and placement
	for player in players:
		if selections.size() <= player.player_num:
			selections.append(await player.get_ship_selection())
		await player.place_ships(selections[player.player_num])
	setup = {"islands": grid.get_islands(), "selections": selections}
	pause_menu.can_replay = true
	_update_fleets()
	# Play until one player has no more ships
	while not players[0].ships.is_empty() and not players[1].ships.is_empty():
		# Increment the turn counter at the start of player 1's turn
		if player_up == 0:
			current_turn += 1
			grid.turn = current_turn
		# Wait for the hotseat players to swap seats, except on player 1's first turn
		if current_turn != 1 or player_up == 1:
			swapping = true
			# From the next player's side from here on
			_update_fleets()
			var player := players[player_up]
			var swapper := TURN_SWAP_SCENE.instantiate()
			add_child(swapper)
			swapper.offer_replay(turn_replay.has_actions(), player.watch_replay)
			var watch: bool = await swapper.swap_done
			# The board was last drawn from the other player's side
			queue_redraw()
			if turn_replay.has_actions():
				# Remember the choice for this player's next swap
				player.watch_replay = watch
				if watch:
					await turn_replay.play()
			swapping = false
		turn_replay.clear()
		gui.update_turn(current_turn)
		_update_fleets()
		# Reset AP counts, decrement ability timers, etc.
		players[player_up].new_turn()
		# The player emits made_move once a move has been made. This makes it
		# easy to wait for GUI input for local players, or network input if I
		# ever get around to adding network play.
		while players[player_up].has_moves():
			players[player_up].get_move()
			await players[player_up].made_move
			# Make sure only the active player receives button signals
			players[player_up].disconnect_buttons()
		players[player_up].finish_turn()
		# Go to the next player if they have any ships remaining
		if not players[1 - player_up].ships.is_empty():
			player_up = 1 - player_up

	var victory := VICTORY_SCENE.instantiate()
	victory.update_winner(1 if players[0].ships.size() > players[1].ships.size() else 2)
	add_child(victory)
	victory.show_stats(players, current_turn)


func _update_fleets() -> void:
	# Ships sunk last turn still count until the replay shows them sinking
	var ours: Array[Ship] = players[player_up].ships.duplicate()
	ours.append_array(turn_replay.held_ships(players[player_up]))
	gui.update_fleets(ours, players[1 - player_up].ships)


func _on_pause_menu_replay_requested() -> void:
	replay = setup
	get_tree().reload_current_scene()


func get_ship_at_hex(hex: Vector2i) -> Ship:
	for player in players:
		var ship := player.get_ship_at_hex(hex)
		if ship != null:
			return ship
	return null


func _draw() -> void:
	var mouse_hex := grid.get_hex_from_coords(get_viewport().get_mouse_position())
	var hover_hexes := players[player_up].get_hover_hexes(mouse_hex)
	var selected_hexes: Array[Vector2i] = []
	var selected_center := Grid.OFF_GRID
	var selected := players[player_up].selected_ship
	if selected != null:
		selected_hexes = selected.get_occupied_hexes()
		selected_center = selected_hexes[selected.len_aft]
	var row_step := grid.hex_size / sqrt(3)

	for x in Grid.COLUMNS:
		# Column labels, highlighted under the mouse
		# Centered across the hex's width, so wider numbers don't drift right
		var label_pos := grid.get_hex_center(Vector2i(x, 0)) - Vector2(grid.hex_size / 2, row_step)
		if x % 2 != 0:
			label_pos.y -= row_step * 0.75
		var label_color := Color.RED if mouse_hex.x == x and current_turn != 0 else Color.WHITE
		draw_string(
			FONT,
			label_pos,
			str(x),
			HORIZONTAL_ALIGNMENT_CENTER,
			grid.hex_size,
			FONT_SIZE,
			label_color
		)

		for y in Grid.ROWS:
			var hex := Vector2i(x, y)
			var tile := grid.tile(hex)
			# Row labels on both sides
			if x == 0:
				var left := (
					grid.get_hex_center(Vector2i(0, y))
					- Vector2(grid.hex_size * 0.75, -row_step / 2)
				)
				var right := (
					grid.get_hex_center(Vector2i(Grid.COLUMNS - 1, y))
					+ Vector2(grid.hex_size * 0.6, row_step / 2)
				)
				var row_color := (
					Color(0.7, 0.0, 0.0) if mouse_hex.y == y and current_turn != 0 else Color.WHITE
				)
				draw_string(
					FONT, left, ROW_LABELS[y], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, row_color
				)
				draw_string(
					FONT, right, ROW_LABELS[y], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, row_color
				)

			var points := grid.get_hex_points(hex)
			draw_polygon(
				points,
				PackedColorArray(
					[hex_color(hex, tile, hover_hexes, selected_hexes, selected_center)]
				)
			)
			# Border
			points.append(points[0])
			draw_polyline(points, Color.BLACK)

			# Hit/miss markers on the opponent's grid, fading out over turns
			if grid.side_of(hex) == 1 - player_up:
				draw_markers(hex, tile)

			draw_string(
				FONT,
				grid.get_hex_center(hex) + Vector2(-grid.hex_size / 2, grid.hex_size / 12),
				ROW_LABELS[y] + str(x),
				HORIZONTAL_ALIGNMENT_CENTER,
				grid.hex_size,
				FONT_SIZE,
				Color.BLACK
			)


func hex_color(
	hex: Vector2i,
	tile: Tile,
	hover_hexes: Array[Vector2i],
	selected_hexes: Array[Vector2i],
	selected_center: Vector2i
) -> Color:
	if hover_hexes.has(hex) and current_turn != 0:
		# Darker on the opponent's grid
		if grid.side_of(hex) == player_up:
			return Color(0.8, 0.5, 0.25) if tile.island else Color(0.0, 0.3, 0.9)
		return Color(0.47, 0.27, 0.14) if tile.island else Color(0.0, 0.26, 0.5)
	if hex == selected_center and not swapping:
		return Color(0.7, 0.42, 0.2) if tile.island else Color(0.0, 0.3, 0.9)
	if selected_hexes.has(hex) and not swapping:
		return Color(0.0, 0.4, 0.9)
	if tile.island:
		return Color(1.0, 0.67, 0.5)
	return Color(0.0, 0.3, 0.65) if tile.no_mans_land else Color(0.0, 0.5, 1.0)


func draw_markers(hex: Vector2i, tile: Tile) -> void:
	var center := grid.get_hex_center(hex)
	var last_event := tile.get_last_event()
	if not last_event.is_empty():
		var alpha := maxf(1.0 - (current_turn - last_event[0]) / 10.0, 0.0)
		var event: String = last_event[1]
		if event == "Hit":
			draw_circle(center, 10, Color(1.0, 0.0, 0.0, alpha))
		elif event in ["Miss", "Miss (ASW Strike)", "Miss (Nuclear Strike)", "Miss (Salvo)"]:
			draw_circle(center, 10, Color(1.0, 1.0, 1.0, alpha))
		elif event == "Sunk":
			draw_circle(center, 10, Color(0.0, 0.0, 0.0, alpha))
		elif event.begins_with("Miss ("):
			# Mixed marker when a potential hit was blocked by an ability
			draw_texture(
				HITMISS_TEXTURE,
				center - HITMISS_TEXTURE.get_size() / 2,
				Color(1.0, 1.0, 1.0, alpha)
			)
	if tile.is_mined:
		draw_texture(MINE_TEXTURE, center - MINE_TEXTURE.get_size() / 2, Color(0.0, 0.0, 0.0, 0.5))
