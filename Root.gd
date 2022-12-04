extends Node2D

var font
var grid
var gui
var ships = [[], []]
var selected_ship = null
var current_turn = 0
var player_up = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	font = DynamicFont.new()
	font.font_data = load("res://opensans.ttf")
	font.size = 11
	grid = Grid.new()
	for i in range(3):
		add_ship('Corvette', i * 2, i + 1, i * 60 + 180, 0)
		add_ship('Destroyer', i * 3 + 4, i * 2 + 1, i * 60 + 60, 0)
		add_ship('Cruiser', i * 2 + 1, i * 3 + 4, i * 60 + 120, 0)
		add_ship('Submarine', i * 2 + 8, i * 3 + 7, i * 60 + 240, 0)
		if i > 0:
			add_ship('Battleship', i * 4 + 18, i * 4, i * 60 + 300, 1)
	add_ship('Carrier', 19, 11, 300, 1)
	add_ship('SupplyTender', 27, 2, 0, 1)
	add_ship('Corvette', 18, 3, 0, 1)
	add_ship('Destroyer', 27, 11, 120, 1)

func _draw():
	# Draw grid
	var y_grid_display = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O']
	var mouse_hex = grid.get_hex_from_coords(get_viewport().get_mouse_position())
	var selected_hexes = []
	if selected_ship != null:
		selected_hexes = selected_ship.get_occupied_hexes()
	for x in range(31):
		# Draw column markers
		var string_color
		var string_location = grid.get_hex_center(x, 0) - Vector2(4, grid.hex_size / sqrt(3))
		if x % 2 != 0:
			string_location -= Vector2(0, grid.hex_size / sqrt(3) * 0.75)
		if mouse_hex[0] == x:
			string_color = Color(1.0, 0.0, 0.0)
		else:
			string_color = Color(1.0, 1.0, 1.0)
		draw_string(font, string_location, str(x), string_color)
		for y in range(15):
			# Draw row markers
			if x == 0:
				var left_string_location = grid.get_hex_center(0, y) - Vector2(grid.hex_size * 0.75, -grid.hex_size / sqrt(3) / 2)
				var right_string_location = grid.get_hex_center(30, y) + Vector2(grid.hex_size * 0.6, grid.hex_size / sqrt(3) / 2)
				if mouse_hex[1] == y:
					string_color = Color(0.7, 0.0, 0.0)
				else:
					string_color = Color(1.0, 1.0, 1.0)
				draw_string(font, left_string_location, y_grid_display[y], string_color)
				draw_string(font, right_string_location, y_grid_display[y], string_color)
			# Draw the hexagon
			var color
			if mouse_hex == [x, y]:
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
			
			draw_string(font, grid.get_hex_center(x, y) - Vector2(grid.hex_size / 10, -grid.hex_size / 12), y_grid_display[y] + str(x), Color(0.0, 0.0, 0.0))

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print('Click! Mouse position: ', event.position)
		var on_hex = grid.get_hex_from_coords(event.position)
		print('On hex: ', on_hex)
		print('Hex neighbors: ', grid.get_all_hex_neighbors(on_hex[0], on_hex[1]))
		var ship_at_hex = get_ship_at_hex(on_hex[0], on_hex[1])
		if event.button_index == BUTTON_LEFT:
			select_ship(ship_at_hex)
		if ship_at_hex != null:
			print('Ship at hex: ', ship_at_hex.ship_name)
			print('Occupied hexes: ', ship_at_hex.get_occupied_hexes())
			if event.button_index == BUTTON_LEFT:
				ship_at_hex.hit(on_hex)
			elif event.button_index == BUTTON_MIDDLE:
				ship_at_hex.rotate(60)
			elif event.button_index == BUTTON_RIGHT:
				ship_at_hex.move(1)
			print('Hit hexes: ', ship_at_hex.hit_hexes)
		if selected_ship != null:
			print('Selected ship: ', selected_ship.ship_name, ' at ', selected_ship.x, ',', selected_ship.y)
		print('========================')
	update()

func game_loop():
	# Player 1 select and place ships
	# Player 2 select and place ships
	# Reveal both players' fleet composition
	# while both players have ships:
	# 	for player in players:
	#		for ship in player.ships:
	#			while ship.has_moves:
	#				fire, move, ability, rotate, or end turn?
	#				if fire:
	#					get target hex
	#					ship.attack(target hex)
	#				elif special ability:
	#					get target hex
	#					ship.special_ability(target hex)
	#				elif recon ability:
	#					get target hex(es)
	#					ship.recon_ability(target hexes)
	#				elif forward and (can move forward)?:
	#					get number of hexes forward
	#					if can move there:
	#						ship.move(hexes forward)
	#				elif port/starboard and (can rotate port/starboard)?:
	#					get degree rotation
	#					if can rotate there:
	#						ship.rotate(rotation)
	#				elif end turn:
	#					break
	pass

func select_ship(ship):
	selected_ship = ship
	gui.update_ship_info()
	update()

func add_ship(ship_type, x, y, direction, player):
	var ship = load('res://ships/' + ship_type + '.tscn').instance()
	ship.set_grid_position(x, y, direction)
	add_child(ship)
	ships[player].append(ship)
	gui.update_fleets()

func get_ship_at_hex(x, y):
	for ship in ships[0] + ships[1]:
		var occupied_hexes = ship.get_occupied_hexes()
		if occupied_hexes != null and [x, y] in occupied_hexes:
			return ship
	return null
