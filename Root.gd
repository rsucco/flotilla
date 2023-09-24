extends Node2D

var font
var grid
var gui
var selecting = true
var ships = [[], []]
var current_turn = 0
var players = []
var player_up = 0
var mine_texture

# Called when the node enters the scene tree for the first time.
func _ready():
	players = [LocalPlayer.new(0), LocalPlayer.new(1)]
	for player in players:
		add_child(player)
	font = DynamicFont.new()
	font.font_data = load("res://opensans.ttf")
	font.size = 11
	mine_texture = load("res://ships/sprites/projectiles/mine.png")
	play_game()

# Draw game board
func _draw():
	var y_grid_display = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O']
	var mouse_hex = grid.get_hex_from_coords(get_viewport().get_mouse_position())
	var hover_hexes = players[player_up].get_hover_hexes(mouse_hex[0], mouse_hex[1])
	var selected_hexes = []
	var selected_center_hex = []
	if players[player_up].selected_ship != null:
		selected_hexes = players[player_up].selected_ship.get_occupied_hexes()
		selected_center_hex = selected_hexes[players[player_up].selected_ship.len_aft]
	for x in range(31):
		# Draw column markers
		var string_color
		var string_location = grid.get_hex_center(x, 0) - Vector2(4, grid.hex_size / sqrt(3))
		if x % 2 != 0:
			string_location -= Vector2(0, grid.hex_size / sqrt(3) * 0.75)
		if mouse_hex[0] == x and current_turn != 0:
			string_color = Color(1.0, 0.0, 0.0)
		else:
			string_color = Color(1.0, 1.0, 1.0)
		draw_string(font, string_location, str(x), string_color)

		for y in range(15):
			# Draw row markers
			if x == 0:
				var left_string_location = grid.get_hex_center(0, y) - Vector2(grid.hex_size * 0.75, -grid.hex_size / sqrt(3) / 2)
				var right_string_location = grid.get_hex_center(30, y) + Vector2(grid.hex_size * 0.6, grid.hex_size / sqrt(3) / 2)
				if mouse_hex[1] == y and current_turn != 0:
					string_color = Color(0.7, 0.0, 0.0)
				else:
					string_color = Color(1.0, 1.0, 1.0)
				draw_string(font, left_string_location, y_grid_display[y], string_color)
				draw_string(font, right_string_location, y_grid_display[y], string_color)

			# Draw the hexagon
			var color
			# Highlight hover hexes appropriately
			if [x, y] in hover_hexes and current_turn != 0:
				# Darker colors on opponent's grid
				if x in range(player_up * 16, player_up * 16 + 15):
					if grid.grid[x][y].island:
						color = PoolColorArray([Color(0.8, 0.5, 0.25)])
					else:
						color = PoolColorArray([Color(0.0, 0.3, 0.9)])
				else:
					if grid.grid[x][y].island:
						color = PoolColorArray([Color(0.47, 0.27, 0.14)])
					else:
						color = PoolColorArray([Color(0.0, 0.26, 0.5)])
			elif selected_center_hex == [x, y]:
				if grid.grid[x][y].island:
					color = PoolColorArray([Color(0.7, 0.42, 0.2)])
				else:
					color = PoolColorArray([Color(0.0, 0.3, 0.9)])
			elif [x, y] in selected_hexes:
				color = PoolColorArray([Color(0.0, 0.4, 0.9)])
			elif grid.grid[x][y].island:
				color = PoolColorArray([Color(1.0, 0.67, 0.5)])
			elif grid.grid[x][y].no_mans_land:
				color = PoolColorArray([Color(0.0, 0.3, 0.65)])
			else:
				color = PoolColorArray([Color(0.0, 0.5, 1.0)])
			var hex_points = grid.get_hex_points(x, y)
			draw_polygon(hex_points, color)

			# Draw the border
			for i in range(1, 6):
				draw_line(hex_points[i - 1], hex_points[i], Color(0.0, 0.0, 0.0))
			draw_line(hex_points[5], hex_points[0], Color(0.0, 0.0, 0.0))

			# Draw hit or miss marker, if applicable, fading out as turns go by
			if x in range(abs(player_up - 1) * 16, abs(player_up - 1) * 16 + 15):
				var hit_miss = grid.grid[x][y].get_last_event()
				if hit_miss != null:
					var alpha_val = max(1.0 - (current_turn - hit_miss[0]) / 10.0, 0.0)
					if hit_miss[1] == 'Hit':
						draw_circle(grid.get_hex_center(x, y), 10, Color(1.0, 0.0, 0.0, alpha_val))
					elif hit_miss[1] == 'Miss':
						draw_circle(grid.get_hex_center(x, y), 10, Color(1.0, 1.0, 1.0, alpha_val))
					elif hit_miss[1] == 'Sunk':
						draw_circle(grid.get_hex_center(x, y), 10, Color(0.0, 0.0, 0.0, alpha_val))
				# Draw mines if applicable
				if grid.grid[x][y].is_mined:
					draw_texture(mine_texture, grid.get_hex_center(x, y) - Vector2(grid.hex_size / 4.5, grid.hex_size / 4.5), Color(0.0, 0.0, 0.0, 0.5))

			# Draw tile coordinates
			draw_string(font, grid.get_hex_center(x, y) - Vector2(grid.hex_size / 10, -grid.hex_size / 12), y_grid_display[y] + str(x), Color(0.0, 0.0, 0.0))

func _input(event):
	update()

func play_game():
	# Initial game setup
	# Create new grid
	grid = Grid.new()
	player_up = 0
	# Get player ship selection and positions
	for player in players:
		# Get ship selections
		player.get_ship_selection()
		yield(player, 'ships_selected')
		var selection = player.selected_count
		# Place ships
		player.place_ships(selection)
		yield(player, 'ships_placed')
	# Reveal both players' fleet composition
	gui.update_fleets()
	# Play until one player has no more ships
	while len(players[0].ships) > 0 and len(players[1].ships) > 0:
		# Increment turn counter at the start of player 1's turn
		if player_up == 0:
			current_turn += 1
		gui.update_turn()
		# Reset AP counts, decrement ability timers, etc.
		players[player_up].new_turn()
		# Get moves from the player as long as they can make a move
		while players[player_up].has_moves():
			# The player object will emit the 'made_move' signal once a move has been made
			# This makes it easy to wait for GUI input for local players, or wait for
			# network input for if I ever get around to adding network play
			players[player_up].get_move()
			yield(players[player_up], 'made_move')
			# Make sure the player only receives signals from the buttons if it's their turn
			players[player_up].disconnect_buttons()
		players[player_up].finish_turn()
		# Next player
		player_up = abs(player_up - 1)
	# TODO: Make this pretty
	if len(players[0].ships) > len(players[1].ships):
		print('Player 1 wins!')
	else:
		print('Player 2 wins!')
	queue_free()

func get_ship_at_hex(x, y):
	var all_ships = players[0].ships + players[1].ships
	for ship in all_ships:
		var occupied_hexes = ship.get_occupied_hexes()
		if occupied_hexes != null and [x, y] in occupied_hexes:
			return ship
	return null
