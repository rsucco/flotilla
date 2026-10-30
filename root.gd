class_name Root
extends Node2D

const ROW_LABELS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"]
const FONT_SIZE := 11
const FONT := preload("res://opensans.ttf")
const MINE_TEXTURE := preload("res://ships/sprites/projectiles/mine.png")
const HITMISS_TEXTURE := preload("res://gui/sprites/hitmiss.png")
const TURN_SWAP_SCENE := preload("res://gui/local_turn_swap.tscn")
const VICTORY_SCENE := preload("res://gui/victory.tscn")

var grid: Grid
var gui: GUI
var players: Array[LocalPlayer] = []
var player_up := 0
var current_turn := 0
var swapping := false


func _ready() -> void:
	players = [LocalPlayer.new(0), LocalPlayer.new(1)]
	for player in players:
		add_child(player)
	play_game()


func _input(_event: InputEvent) -> void:
	queue_redraw()


func play_game() -> void:
	grid = Grid.new()
	player_up = 0
	# Ship selection and placement
	for player in players:
		var selection := await player.get_ship_selection()
		await player.place_ships(selection)
	gui.update_fleets()
	# Play until one player has no more ships
	while not players[0].ships.is_empty() and not players[1].ships.is_empty():
		# Increment the turn counter at the start of player 1's turn
		if player_up == 0:
			current_turn += 1
		# Wait for the hotseat players to swap seats, except on player 1's first turn
		if current_turn != 1 or player_up == 1:
			swapping = true
			var swapper := TURN_SWAP_SCENE.instantiate()
			add_child(swapper)
			await swapper.swap_done
			swapping = false
		gui.update_turn()
		gui.update_fleets()
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
	victory.update_winner("One" if players[0].ships.size() > players[1].ships.size() else "Two")
	add_child(victory)


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
	var icon_pos := center - Vector2.ONE * grid.hex_size / 4.5
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
			draw_texture(HITMISS_TEXTURE, icon_pos, Color(1.0, 1.0, 1.0, alpha))
	if tile.is_mined:
		draw_texture(MINE_TEXTURE, icon_pos, Color(0.0, 0.0, 0.0, 0.5))
