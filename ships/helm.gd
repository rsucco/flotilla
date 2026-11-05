class_name Helm
# What room a ship has to manoeuvre: whether hexes are free for it, where a
# placement would leave it stuck, and why a move can't be made. Apart from
# Ship, which has as many public methods as gdlint allows.

const MOVES: Array[String] = ["forward", "reverse", "port", "starboard"]


# True if none of the hexes are land or occupied by another of our ships
static func is_clear(ship: Ship, hexes: Array[Vector2i]) -> bool:
	for h in hexes:
		var other := ship.player.get_ship_at_hex(h)
		if ship.grid.tile(h).island or (other != null and other != ship):
			return false
	return true


# True if a ship placed at `at`, facing `dir`, could both turn and get under
# way, as far as the ships placed so far allow
static func has_room(ship: Ship, at: Vector2i, dir: int) -> bool:
	var turns: bool = (
		_fits(ship, ship.hexes_at(at, dir - 60)) or _fits(ship, ship.hexes_at(at, dir + 60))
	)
	var moves: bool = false
	for heading in [dir, dir + 180]:
		moves = moves or _fits(ship, ship.hexes_at(ship.grid.get_hex_neighbor(at, heading), dir))
	return turns and moves


# True if the ship has nowhere to go whatever its AP
static func is_boxed_in(ship: Ship) -> bool:
	if ship is CoastalBattery or ship.is_immobilized():
		return false
	return MOVES.all(func(m: String) -> bool: return not _fits(ship, _hexes_after(ship, m)))


# Why `ship` can't make a move, for the player; "" if it can
static func refusal(ship: Ship, move: String) -> String:
	if ship is CoastalBattery:
		return "Stationary"
	if ship.is_immobilized():
		return "Immobilized: more than half damaged"
	var hexes := _hexes_after(ship, move)
	if hexes.has(Grid.OFF_GRID):
		return "Off the board"
	if not is_clear(ship, hexes):
		return "Blocked by an island or one of our ships"
	var cost: int = {"forward": 1, "reverse": 4}.get(move, 2)
	return "Not enough AP" if ship.ap < cost else ""


static func _fits(ship: Ship, hexes: Array[Vector2i]) -> bool:
	return not hexes.has(Grid.OFF_GRID) and is_clear(ship, hexes)


static func _hexes_after(ship: Ship, move: String) -> Array[Vector2i]:
	match move:
		"forward":
			return ship.hexes_at(
				ship.grid.get_hex_neighbor(ship.hex, ship.direction), ship.direction
			)
		"reverse":
			var back: Vector2i = ship.grid.get_hex_neighbor(ship.hex, ship.direction + 180)
			return ship.hexes_at(back, ship.direction)
		"port":
			return ship.hexes_at(ship.hex, ship.direction - 60)
	return ship.hexes_at(ship.hex, ship.direction + 60)
