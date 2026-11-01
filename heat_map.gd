class_name HeatMap
extends RefCounted
# Where the opponent's ships probably are, worked out only from what a player
# could know: the tile history on the opponent's side, copies of their ships
# that gave themselves away, and their fleet's makeup (the fleet panel). For
# every surviving ship it weighs each way the ship could lie, then adds up how
# likely each hex is to hold a ship. Used by AIPlayer.
#
# Everything comes from the ships' own data (size, AP), so rule changes carry
# over; the constants below are rough judgement, not tuning.

const DIRECTIONS: Array[int] = [0, 60, 120, 180, 240, 300]
# What's left of a sighting after each of the opponent's turns, as their
# ships may have moved since
const FADE := 0.5
# Likewise for a miss. Slower: a ship moves only a few hexes a turn, so most
# of the water we've cleared stays clear.
const MISS_FADE := 0.8
# How much likelier a ship is to lie near where a ship like it was seen, when
# it may have been another of its kind
const SIGHTING := 20.0

# Each hex and radius's area, deduped: board geometry, the same every game
static var _areas := {}

# Hex -> expected number of the opponent's ships on it, and of submarines
var heat := {}
var sub_heat := {}
# Hexes hit this turn that are still afloat: firing there again does nothing
var fresh_hits: Array[Vector2i] = []

var _grid: Grid
var _side: int
var _turn: int
# Hex -> what's left of the evidence that it's empty (0 = just missed)
var _empty := {}
var _no_sub := {}
# [ship name ("" if unknown), hex, turns ago], newest first once read
var _sightings: Array[Array] = []
# Ship name -> hexes hit, to tell which can no longer move
var _hits := {}
# Ship name -> how many of them are afloat
var _alike := {}


# `ships` are the opponent's surviving ships, read only for their type, size
# and AP; `copies` are copies of them that gave themselves away
func _init(grid: Grid, side: int, ships: Array[Ship], copies: Array[Ship], turn: int) -> void:
	_grid = grid
	_side = side
	_turn = turn
	for x: int in grid.columns_of(side):
		for y in Grid.ROWS:
			heat[Vector2i(x, y)] = 0.0
			sub_heat[Vector2i(x, y)] = 0.0
			_read_history(Vector2i(x, y))
	for copy in copies:
		if is_instance_valid(copy):
			# Copies are duplicates, which don't keep script variables like the name
			var named := ships.filter(
				func(s: Ship) -> bool: return s.scene_file_path == copy.scene_file_path
			)
			var ship_name: String = named[0].ship_name if not named.is_empty() else ""
			_sightings.append([ship_name, grid.get_hex_from_coords(copy.position), 0])
	_sightings.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	for ship in ships:
		_alike[ship.ship_name] = _alike.get(ship.ship_name, 0) + 1
	for ship in ships:
		_add(ship)


func _read_history(hex: Vector2i) -> void:
	for event: Array in _grid.tile(hex).history:
		var age: int = _turn - event[0]
		var text: String = event[1]
		if text in ["Miss", "Miss (Salvo)", "Miss (Nuclear Strike)"]:
			_empty[hex] = _faded(age)
		elif text == "Miss (ASW Strike)":
			_no_sub[hex] = _faded(age)
		elif text == "Miss (Blocked by Armor)":
			_sightings.append(["Battleship", hex, age])
		elif text == "Miss (CIWS intercepted hit)":
			_sightings.append(["", hex, age])
		elif text in ["Submarine used Sonar Pulse", "Miss (Silent Service)"]:
			_sightings.append(["Submarine", hex, age])
		elif text.begins_with("Hit, "):
			var ship_name := text.trim_prefix("Hit, ").get_slice(" (", 0)
			_sightings.append([ship_name, hex, age])
			if not _hits.has(ship_name):
				_hits[ship_name] = []
			if not _hits[ship_name].has(hex):
				_hits[ship_name].append(hex)
			# Batteries have HP, so take hit after hit on the same hex
			if age == 0 and ship_name != "Coastal Battery":
				fresh_hits.append(hex)
		elif text.contains(" revealed by "):
			_sightings.append([text.get_slice(" revealed by ", 0), hex, age])
		elif text.begins_with("Sunk, ") or text.begins_with("Destroyed, "):
			# Gone: the hexes are open water again
			_empty[hex] = _faded(age)
			fresh_hits.erase(hex)
			_hits.erase(text.get_slice(", ", 1))


# 0 when it's this turn's news, rising towards 1 as it goes stale
func _faded(age: int) -> float:
	return 1.0 - pow(MISS_FADE, age)


# Spreads one ship over the hexes it could be on. If its sightings rule out
# everywhere (say it was repaired and moved off), they're left out.
func _add(ship: Ship, sightings: bool = true) -> void:
	var size := ship.len_aft + ship.len_fore + 1
	# Batteries never move, nor do ships over half damaged
	var fixed: bool = ship is CoastalBattery or _hits.get(ship.ship_name, []).size() * 2 > size
	var placements: Array[Array] = []
	var weights: Array[float] = []
	var total := 0.0
	for x: int in _grid.columns_of(_side):
		for y in Grid.ROWS:
			for dir in DIRECTIONS:
				var hexes := _hexes_at(Vector2i(x, y), dir, ship)
				if hexes.is_empty():
					continue
				var weight := _weigh(hexes, ship, fixed, sightings)
				if weight > 0.0:
					placements.append(hexes)
					weights.append(weight)
					total += weight
	if total == 0.0:
		if sightings:
			_add(ship, false)
		return
	var is_sub := ship is Submarine
	for i in placements.size():
		for hex: Vector2i in placements[i]:
			heat[hex] += weights[i] / total
			if is_sub:
				sub_heat[hex] += weights[i] / total


# The hexes `ship` would cover centred on `center` facing `dir`, or none if it
# couldn't lie there (off our side, or on land; batteries only on land)
func _hexes_at(center: Vector2i, dir: int, ship: Ship) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = [center]
	var h := center
	for _i in ship.len_aft:
		h = _grid.get_hex_neighbor(h, dir + 180)
		hexes.append(h)
	h = center
	for _i in ship.len_fore:
		h = _grid.get_hex_neighbor(h, dir)
		hexes.append(h)
	var on_land := ship is CoastalBattery
	for hex in hexes:
		if _grid.side_of(hex) != _side or _grid.tile(hex).island != on_land:
			return []
	return hexes


# A ship moves at most a hex per AP, so once seen it's within its AP times the
# turns since. If it may have been another of its kind, that's just likelier.
func _weigh(hexes: Array[Vector2i], ship: Ship, fixed: bool, sightings: bool) -> float:
	var weight := 1.0
	for hex in hexes:
		weight *= _empty.get(hex, 1.0)
		if ship is Submarine:
			weight *= _no_sub.get(hex, 1.0)
	if not sightings:
		return weight
	# Its latest sighting, and any of ships unknown
	var seen := false
	for sighting in _sightings:
		var named: bool = sighting[0] == ship.ship_name
		if (named and seen) or (not named and sighting[0] != ""):
			continue
		seen = seen or named
		var age: int = 0 if fixed else sighting[2]
		var within := false
		for hex in hexes:
			if Grid.distance(hex, sighting[1]) <= ship.default_ap * age:
				within = true
				break
		if named and _alike[ship.ship_name] == 1:
			if not within:
				return 0.0
		elif within:
			weight *= 1.0 + SIGHTING * pow(FADE, age)
	return weight


# Sum of `values` over `hex` and everything within `radius` of it
func area(values: Dictionary, hex: Vector2i, radius: int) -> float:
	var key := Vector3i(hex.x, hex.y, radius)
	if not _areas.has(key):
		var hexes: Array[Vector2i] = [hex]
		for h in _grid.get_all_hex_neighbors(hex, radius):
			if not hexes.has(h):
				hexes.append(h)
		_areas[key] = hexes
	var total := 0.0
	for h: Vector2i in _areas[key]:
		total += values.get(h, 0.0)
	return total


# Sum of heat along the row through `hex`
func row(hex: Vector2i) -> float:
	var total := 0.0
	for x: int in _grid.columns_of(_side):
		total += heat[Vector2i(x, hex.y)]
	return total
