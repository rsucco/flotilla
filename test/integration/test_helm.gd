extends GutTest
# Why a ship can't move, and where the AI won't leave one stuck

const ROOT_SCENE := preload("res://game/root.tscn")

var game: Root
var p0: LocalPlayer


func before_each() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	p0 = game.players[0]
	for column: Array in game.grid.tiles:
		for tile: Tile in column:
			tile.island = false


func spawn(type: String, hex: Vector2i, dir: int = 0) -> Ship:
	var ship: Ship = load("res://ships/" + type + ".tscn").instantiate()
	p0.adopt(ship)
	ship.set_grid_position(hex, dir)
	p0.ships.append(ship)
	return ship


func test_refused_moves_say_why() -> void:
	var carrier := spawn("carrier", Vector2i(7, 2))
	carrier.ap = 4
	assert_eq(Helm.refusal(carrier, "forward"), "Off the board")
	assert_eq(Helm.refusal(carrier, "reverse"), "")
	carrier.ap = 1
	assert_eq(Helm.refusal(carrier, "reverse"), "Not enough AP")
	carrier.ap = 4
	spawn("corvette", Vector2i(7, 5))
	assert_eq(Helm.refusal(carrier, "reverse"), "Blocked by an island or one of our ships")
	carrier.hit_hexes = [true, true, true, false, false]
	assert_eq(Helm.refusal(carrier, "forward"), "Immobilized: more than half damaged")


# Every move Helm calls free is one the ship can make
func test_refusal_agrees_with_the_ship() -> void:
	var carrier := spawn("carrier", Vector2i(1, 7))
	carrier.ap = 4
	assert_eq(Helm.refusal(carrier, "forward") == "", carrier.can_move())
	assert_eq(Helm.refusal(carrier, "reverse") == "", carrier.can_move(true))
	assert_eq(Helm.refusal(carrier, "port") == "", carrier.can_rotate(-60))
	assert_eq(Helm.refusal(carrier, "starboard") == "", carrier.can_rotate(60))


func test_a_battery_says_its_stationary() -> void:
	game.grid.tile(Vector2i(5, 7)).island = true
	var battery := spawn("coastal_battery", Vector2i(5, 7))
	assert_eq(Helm.refusal(battery, "forward"), "Stationary")
	assert_false(Helm.is_boxed_in(battery))


func test_a_ship_along_the_edge_has_no_room() -> void:
	var carrier := spawn("carrier", Vector2i(0, 7))
	assert_false(Helm.has_room(carrier, Vector2i(0, 7), 0), "can't turn off the board")
	assert_true(Helm.has_room(carrier, Vector2i(7, 7), 0), "open water")


func test_a_ship_hemmed_in_on_every_side_is_boxed_in() -> void:
	var carrier := spawn("carrier", Vector2i(0, 2))
	assert_false(Helm.is_boxed_in(carrier), "it can still back away")
	spawn("corvette", Vector2i(0, 5))
	assert_true(Helm.is_boxed_in(carrier), "not now")
	assert_false(Helm.is_boxed_in(spawn("corvette", Vector2i(7, 7))))


func test_the_ai_places_ships_with_room() -> void:
	var ai := AIPlayer.new(0)
	ai.grid = game.grid
	ai.opponent = game.players[1]
	add_child_autofree(ai)
	for _i in 20:
		var carrier: Ship = load("res://ships/carrier.tscn").instantiate()
		ai.adopt(carrier)
		ai._place(carrier)
		assert_true(Helm.has_room(carrier, carrier.hex, carrier.direction))
		carrier.free()
