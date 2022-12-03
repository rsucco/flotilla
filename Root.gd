extends Node2D

var font
var grid
var ships

# Called when the node enters the scene tree for the first time.
func _ready():
	font = DynamicFont.new()
	font.font_data = load("res://opensans.ttf")
	font.size = 10
	grid = Grid.new()
	ships = []
	for i in range(3):
		var	corvette = preload('res://ships/Corvette.tscn').instance()
		corvette.set_grid_position(i * 2, i + 1, i * 60 + 180)
		add_child(corvette)
		ships.append(corvette)
		var destroyer = preload('res://ships/Destroyer.tscn').instance()
		destroyer.set_grid_position(i * 3 + 4, i * 2 + 1, i * 60 + 60)
		add_child(destroyer)
		ships.append(destroyer)
		var cruiser = preload('res://ships/Cruiser.tscn').instance()
		cruiser.set_grid_position(i * 2 + 1, i * 3 + 4, i * 60 + 120)
		add_child(cruiser)
		ships.append(cruiser)
		var submarine = preload('res://ships/Submarine.tscn').instance()
		submarine.set_grid_position(i * 2 + 8, i * 3 + 7, i * 60 + 240)
		add_child(submarine)
		ships.append(submarine)
		if i > 0:
			var battleship = preload('res://ships/Battleship.tscn').instance()
			battleship.set_grid_position(i * 4 + 18, i * 4, i * 60 + 300)
			add_child(battleship)
			ships.append(battleship)
	var carrier = preload('res://ships/Carrier.tscn').instance()
	carrier.set_grid_position(19, 11, 300)
	add_child(carrier)
	ships.append(carrier)
	var tender = preload('res://ships/SupplyTender.tscn').instance()
	tender.set_grid_position(27, 2, 0)
	add_child(tender)
	ships.append(tender)

func _draw():
	var y_grid_display = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O']
	var mouse_hex = grid.get_hex_from_coords(get_viewport().get_mouse_position())
	for x in range(31):
		# Draw column markers
		var string_color
		var string_location = grid.get_hex_center(x, 0) - Vector2(0, grid.hex_size / sqrt(3))
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
				string_location = grid.get_hex_center(0, y) - Vector2(grid.hex_size * 0.75, -grid.hex_size / sqrt(3) / 2)
				if mouse_hex[1] == y:
					string_color = Color(0.7, 0.0, 0.0)
				else:
					string_color = Color(1.0, 1.0, 1.0)
				draw_string(font, string_location, y_grid_display[y], string_color)
			var color
			if mouse_hex == [x, y]:
				color = PoolColorArray([Color(1.0, 0.0, 0.0)])
			elif grid.grid[x][y].is_land:
				color = PoolColorArray([Color(0.0, 0.7, 0.0)])
			else:
				color = PoolColorArray([Color(0.0, 0.5, 1.0)])
			var hex_points = grid.get_hex_points(x, y)
			draw_polygon(hex_points, color)
			# Draw the border
			for i in range(1, 6):
				draw_line(hex_points[i - 1], hex_points[i], Color(0.0, 0.0, 0.0))
			draw_line(hex_points[5], hex_points[0], Color(0.0, 0.0, 0.0))
#			draw_string(font, grid.get_hex_center(x, y), y_grid_display[y] + str(x))
			draw_string(font, grid.get_hex_center(x, y), str(x) + ',' + str(y))

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print('Click! Mouse position:', event.position)
		var on_hex = grid.get_hex_from_coords(event.position)
		print('On hex:', on_hex)
		print('Hex neighbors:', grid.get_all_hex_neighbors(on_hex[0], on_hex[1]))
		var ship_at_hex = get_ship_at_hex(on_hex[0], on_hex[1])
		if ship_at_hex != null:
			print('Ship at hex: ', ship_at_hex.desc)
			print('Occupied hexes: ', ship_at_hex.get_occupied_hexes())
			if event.button_index == BUTTON_RIGHT:
				ship_at_hex.rotate(60)
		print('========================')
	elif event is InputEventMouseMotion:
		update()

func get_ship_at_hex(x, y):
	for ship in ships:
		var occupied_hexes = ship.get_occupied_hexes()
		if occupied_hexes != null and [x, y] in occupied_hexes:
			return ship
	return null
