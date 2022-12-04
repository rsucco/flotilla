extends Object

class_name Grid


# Declare member variables here
var grid
var hex_size

# Called when the node enters the scene tree for the first time.
func _init(hex_size = 50):
	self.hex_size = hex_size
	# Create 31x15 grid, 15x15 for each player and a 1x15 no-man's-land
	self.grid = []
	randomize()
	for x in range(31):
		var new_column = []
		for _y in range(30):
			if x == 15:
				# No-man's-land
				new_column.append(Tile.new(true))
			else:
				if rand_range(0, 1) > 0.02:
					# Ocean tile
					new_column.append(Tile.new())
				else:
					# Island tile
					new_column.append(Tile.new(false, true))
		self.grid.append(new_column)

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
func get_hex_neighbor(x, y, direction, length = 1):
	var oddq_direction_differences = [ \
		[[ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0], [-1, -1]], \
		[[ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1], [-1,  0]], \
	]
	var parity = x & 1
	while direction >= 360:
		direction -= 360
	var diff = oddq_direction_differences[parity][direction / 60]
	var neighbor_x = x + diff[0] * length
	var neighbor_y = y + diff[1] * length
	if neighbor_y in range(15) and (neighbor_x in range(15) or neighbor_x in range(16, 31)):
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
	var hex_center = Vector2(73 + hex_size * 0.75 * x, hex_size + hex_size * y / sqrt(3) * 1.5)
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
