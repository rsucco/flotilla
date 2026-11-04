extends GutTest
# Ships leave a wake as they move, but only where the viewer can see them: a
# wake would give away a hidden ship, or a cloaked one mid-turn

const ROOT_SCENE := preload("res://game/root.tscn")

var game: Root
var p0: Player


func before_each() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	p0 = game.players[0]
	for column: Array in game.grid.tiles:
		for tile: Tile in column:
			tile.island = false


func spawn(hex: Vector2i) -> Ship:
	var ship: Ship = load("res://ships/cruiser.tscn").instantiate()
	p0.adopt(ship)
	ship.set_grid_position(hex, 0)
	p0.ships.append(ship)
	ship.ap = 4
	return ship


func wakes(ship: Ship) -> int:
	return ship.get_children().filter(func(n: Node) -> bool: return n is Wake).size()


func test_a_ship_in_view_leaves_a_wake() -> void:
	var ship := spawn(Vector2i(5, 7))
	ship.visible = true
	ship.forward()
	assert_eq(wakes(ship), 1, "while it moves")
	await wait_seconds(5.0)
	assert_eq(wakes(ship), 0, "gone once it's faded")


func test_turning_too() -> void:
	var ship := spawn(Vector2i(5, 7))
	ship.visible = true
	ship.port()
	assert_eq(wakes(ship), 1)


func test_none_for_a_hidden_or_cloaked_ship() -> void:
	var hidden := spawn(Vector2i(5, 7))
	hidden.visible = false
	hidden.forward()
	assert_eq(wakes(hidden), 0, "hidden")
	var cloaked := spawn(Vector2i(9, 7))
	cloaked.visible = true
	cloaked.cloaked = true
	cloaked.forward()
	assert_eq(wakes(cloaked), 0, "cloaked, mid-turn")


func test_none_while_being_placed() -> void:
	var ship := spawn(Vector2i(5, 7))
	ship.visible = true
	ship.placing = true
	ship.turn_by(60)
	assert_eq(wakes(ship), 0, "not under way yet")
	ship.placing = false
