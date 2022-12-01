extends Node2D


# Declare member variables here
var grid
var font
var hex_size

# Called when the node enters the scene tree for the first time.
func _ready():
	font = DynamicFont.new()
	font.font_data = load("res://opensans.ttf")
	font.size = 10
	hex_size = 50
	# Create 31x15 grid, 15x15 for each player and a 1x15 no-man's-land
	grid = []
	for x in range(31):
		var new_column = []
		for _y in range(30):
			if x == 15:
				new_column.append(Tile.new(true))
			else:
				new_column.append(Tile.new())
		grid.append(new_column)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _draw():
	var mouse_hex = get_hex_from_coords(get_viewport().get_mouse_position())
	for x in range(31):
		for y in range(15):
			var color
			if mouse_hex == [x, y]:
				color = PoolColorArray([Color(1.0, 0.0, 0.0)])
			elif grid[x][y].land:
				color = PoolColorArray([Color(0.0, 0.7, 0.0)])
			else:
				color = PoolColorArray([Color(0.0, 0.0, 0.7)])
			var hex_points = get_hex_points(x, y)
			draw_polygon(hex_points, color)
			# Draw the border
			for i in range(1, 6):
				draw_line(hex_points[i - 1], hex_points[i], Color(0.0, 0.0, 0.0))
			draw_line(hex_points[5], hex_points[0], Color(0.0, 0.0, 0.0))
			draw_string(font, get_hex_center(x, y), str(x) + ',' + str(y))

func _input(event):
	if event is InputEventMouseButton:
		print('Click! Mouse position:', event.position)
		print('On hex:', get_hex_from_coords(event.position))
		print('Hex neighbors:', callv("get_all_hex_neighbors", get_hex_from_coords(event.position)))
	elif event is InputEventMouseMotion:
		update()

# Returns a list of hexes that border a given hex
func get_all_hex_neighbors(x, y):
	var hex_neighbors = []
	for direction in [0, 60, 120, 180, 240, 300]:
		var hex_neighbor = get_hex_neighbor(x, y, direction)
		if hex_neighbor != [-1, -1]:
			hex_neighbors.append(hex_neighbor)
	return hex_neighbors

# Returns the hex that borders a given hex in a given direction in degrees
# Returns [-1, -1] for out of bounds
func get_hex_neighbor(x, y, direction):
	var oddq_direction_differences = [ \
		[[ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0], [-1, -1]], \
		[[ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1], [-1,  0]], \
	]
	var parity = x & 1
	var diff = oddq_direction_differences[parity][direction / 60]
	var neighbor_x = x + diff[0]
	var neighbor_y = y + diff[1]
	if neighbor_y in range(15) and (neighbor_x in range(14) or neighbor_x in range(16, 31)):
		return [neighbor_x, neighbor_y]
	return [-1, -1]

# Returns which hex is at the mouse_pos coordinates
func get_hex_from_coords(mouse_pos):
	for x in range(31):
		for y in range(15):
			if Geometry.is_point_in_polygon(mouse_pos, get_hex_points(x, y)):
				return [x, y]
	return [-1, -1]

# Get the center point of the hexagon at x, y
func get_hex_center(x, y):
	var hex_center = Vector2(hex_size + hex_size * 0.75 * x, hex_size + hex_size * y / sqrt(3) * 1.5)
	# Offset odd columns
	if x % 2 != 0:
		hex_center += Vector2(0, hex_size / sqrt(3) * 0.75)
	return hex_center

# Get the six points defining the hexagon at x, y
func get_hex_points(x, y):
	var hex_center = get_hex_center(x, y)
	var points = []
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = PI / 180 * angle_deg
		points.append(hex_center + Vector2(hex_size / 2 * cos(angle_rad), hex_size / 2 * sin(angle_rad)))
	return points
