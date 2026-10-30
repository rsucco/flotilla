extends GutTest

var grid: Grid


func before_each() -> void:
	grid = Grid.new()


func test_side_of() -> void:
	assert_eq(grid.side_of(Vector2i(0, 0)), 0)
	assert_eq(grid.side_of(Vector2i(14, 7)), 0)
	assert_eq(grid.side_of(Vector2i(Grid.NO_MANS_LAND, 7)), -1)
	assert_eq(grid.side_of(Vector2i(16, 7)), 1)
	assert_eq(grid.side_of(Vector2i(30, 14)), 1)
	assert_eq(grid.side_of(Grid.OFF_GRID), -1)


func test_neighbor_off_board_edge_is_off_grid() -> void:
	assert_eq(grid.get_hex_neighbor(Vector2i(0, 0), 0), Grid.OFF_GRID)
	assert_eq(grid.get_hex_neighbor(Vector2i(30, 14), 180), Grid.OFF_GRID)


func test_neighbor_into_no_mans_land_is_off_grid() -> void:
	assert_eq(grid.get_hex_neighbor(Vector2i(14, 7), 120), Grid.OFF_GRID)


func test_neighbor_directions_wrap() -> void:
	var hex := Vector2i(5, 5)
	assert_eq(grid.get_hex_neighbor(hex, 360), grid.get_hex_neighbor(hex, 0))
	assert_eq(grid.get_hex_neighbor(hex, -60), grid.get_hex_neighbor(hex, 300))


func test_neighbor_of_off_grid_is_off_grid() -> void:
	assert_eq(grid.get_hex_neighbor(Grid.OFF_GRID, 0), Grid.OFF_GRID)


func test_distance_one_is_six_neighbors_without_center() -> void:
	var hex := Vector2i(5, 5)
	var neighbors := grid.get_all_hex_neighbors(hex, 1)
	assert_eq(neighbors.size(), 6)
	assert_false(neighbors.has(hex))


func test_distance_two_includes_center() -> void:
	var hex := Vector2i(5, 5)
	assert_true(grid.get_all_hex_neighbors(hex, 2).has(hex))


func test_hex_from_center_round_trips() -> void:
	for hex in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(Grid.NO_MANS_LAND, 9), Vector2i(30, 14)]:
		assert_eq(grid.get_hex_from_coords(grid.get_hex_center(hex)), hex)


func test_last_event_ignores_non_hit_events() -> void:
	var tile := Tile.new()
	assert_eq(tile.get_last_event(), [])
	tile.history.append([1, "Hit, Destroyer"])
	assert_eq(tile.get_last_event(), [1, "Hit"])
	tile.history.append([2, "Mine laid"])
	assert_eq(tile.get_last_event(), [])
