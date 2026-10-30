class_name Grid
extends RefCounted

# 31x15 board: columns 0-14 are player 0, 15 is no-man's-land, 16-30 are player 1
const COLUMNS := 31
const ROWS := 15
const NO_MANS_LAND := 15
const OFF_GRID := Vector2i(-1, -1)
const ISLAND_CHANCE := 0.02

# Neighbor offsets for odd-q offset coordinates, indexed by column parity,
# then by direction (0, 60, ..., 300 degrees)
const ODDQ_DIRECTIONS: Array[Array] = [
	[
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(-1, -1)
	],
	[
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0)
	],
]

var hex_size: float
# Indexed [x][y]
var tiles: Array[Array] = []


func _init(size: float = 50.0) -> void:
	hex_size = size
	for x in COLUMNS:
		var column: Array[Tile] = []
		for _y in ROWS:
			if x == NO_MANS_LAND:
				column.append(Tile.new(true))
			else:
				column.append(Tile.new(false, randf() < ISLAND_CHANCE))
		tiles.append(column)


func tile(hex: Vector2i) -> Tile:
	return tiles[hex.x][hex.y]


# Returns which player's side a hex is on, or -1 for no-man's-land/off-grid
func side_of(hex: Vector2i) -> int:
	if hex.x < 0 or hex.x >= COLUMNS or hex.x == NO_MANS_LAND:
		return -1
	return 0 if hex.x < NO_MANS_LAND else 1


# Columns belonging to a player's side
func columns_of(player: int) -> Array:
	return range(player * 16, player * 16 + 15)


func get_num_island_tiles(player: int) -> int:
	var count := 0
	for x: int in columns_of(player):
		for y in ROWS:
			if tile(Vector2i(x, y)).island:
				count += 1
	return count


func get_islands() -> Array[Vector2i]:
	var islands: Array[Vector2i] = []
	for x in COLUMNS:
		for y in ROWS:
			if tiles[x][y].island:
				islands.append(Vector2i(x, y))
	return islands


# Replaces the random islands, e.g. to replay a board
func set_islands(islands: Array[Vector2i]) -> void:
	for x in COLUMNS:
		for y in ROWS:
			tiles[x][y].island = islands.has(Vector2i(x, y))


# Returns the endpoints of every in-bounds walk of exactly `distance` steps.
# Distance 1 is the six neighbors (excluding the hex itself); distance 2+
# includes the hex itself and duplicates, so callers dedupe.
func get_all_hex_neighbors(hex: Vector2i, distance: int = 1) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	if hex.x < 0 or hex.y < 0:
		return neighbors
	if distance == 0:
		neighbors.append(hex)
		return neighbors
	for direction in range(0, 360, 60):
		var neighbor := get_hex_neighbor(hex, direction)
		if neighbor != OFF_GRID:
			neighbors.append_array(get_all_hex_neighbors(neighbor, distance - 1))
	return neighbors


# Returns the hex bordering `hex` in a direction in degrees (multiple of 60),
# or OFF_GRID if that's off the board or in no-man's-land
func get_hex_neighbor(hex: Vector2i, direction: int) -> Vector2i:
	if hex == OFF_GRID:
		return OFF_GRID
	@warning_ignore("integer_division")
	var offset: Vector2i = ODDQ_DIRECTIONS[hex.x & 1][posmod(direction, 360) / 60]
	var neighbor := hex + offset
	if neighbor.y < 0 or neighbor.y >= ROWS or side_of(neighbor) == -1:
		return OFF_GRID
	return neighbor


# Returns the hex under a screen position, or OFF_GRID
func get_hex_from_coords(pos: Vector2) -> Vector2i:
	for x in COLUMNS:
		for y in ROWS:
			var hex := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(pos, get_hex_points(hex)):
				return hex
	return OFF_GRID


func get_hex_center(hex: Vector2i) -> Vector2:
	var center := Vector2(73 + hex_size * 0.75 * hex.x, hex_size + hex_size * hex.y / sqrt(3) * 1.5)
	# Offset odd columns
	if hex.x % 2 != 0:
		center.y += hex_size / sqrt(3) * 0.75
	return center


func get_hex_points(hex: Vector2i) -> PackedVector2Array:
	var center := get_hex_center(hex)
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60 * i)
		points.append(center + Vector2(cos(angle), sin(angle)) * hex_size / 2)
	return points
