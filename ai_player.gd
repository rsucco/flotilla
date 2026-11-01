class_name AIPlayer
extends Player
# The computer opponent. It plays fair, knowing only what a player would (see
# HeatMap): it makes the attack it expects to do the most damage, then moves
# ships out of trouble, and the tender towards ships it can repair.

# Pauses before each attack and each move, so its turn can be followed
const ATTACK_PAUSE := 0.4
const MOVE_PAUSE := 0.15
const SELECTION := preload("res://gui/ship_selection.gd")
# Fleets to pick from, each within the points budget. Rough starting points
# for balance passes, not a final word.
const FLEETS: Array[Dictionary] = [
	# Classic: one of everything
	{
		"CoastalBattery": 1,
		"Corvette": 1,
		"Destroyer": 1,
		"Cruiser": 1,
		"Submarine": 1,
		"SupplyTender": 1,
		"Battleship": 1,
		"Carrier": 1,
	},
	# Gun line
	{"Battleship": 2, "Cruiser": 2, "Destroyer": 2, "Corvette": 2},
	# Carrier group
	{"Carrier": 2, "Cruiser": 1, "Destroyer": 1, "SupplyTender": 1, "Submarine": 1, "Corvette": 1},
	# Wolfpack
	{"Submarine": 3, "Destroyer": 2, "Battleship": 1, "Corvette": 2},
	# Fortress: batteries ashore, a tender to keep the rest afloat
	{
		"CoastalBattery": 2,
		"Battleship": 1,
		"Cruiser": 1,
		"SupplyTender": 1,
		"Destroyer": 1,
		"Submarine": 1,
		"Corvette": 2,
	},
]
const DIRECTIONS: Array[int] = [0, 60, 120, 180, 240, 300]
const MOVES: Array[String] = ["forward", "reverse", "port", "starboard"]
const ATTACKS: Array[String] = ["fire", "special", "secondary"]
# Rough worth of each ability against one expected ship in reach, next to
# firing at a hex (1 per expected ship). Judgement, not tuning: abilities
# that sink outright count double, ones that only reveal or hinder count less.
const VALUES := {
	"Salvo": 1.0,
	"Nuclear Strike": 1.0,
	"ASW Strike": 2.0,
	"EW Strike": 0.3,
	"Sonar Pulse": 0.25,
	"Recon Flight": 0.25,
	"Lay Mine": 0.1,
}
# Per damaged hex repaired
const UNREP_VALUE := 0.4
# How much a ship wants to get away from what the opponent knows: each recent
# shot landing within a hex, and each recent hit or reveal on the ship itself
const SHELLED := 0.2
const SPOTTED := 1.0


# One of the fleets, with any batteries we've no islands for swapped for
# corvettes (the same points)
func get_ship_selection() -> Dictionary:
	var fleet: Dictionary = FLEETS.pick_random().duplicate()
	var spare: int = fleet.get("CoastalBattery", 0) - grid.get_num_island_tiles(player_num)
	if spare > 0:
		fleet.CoastalBattery -= spare
		fleet.Corvette = fleet.get("Corvette", 0) + spare
	return fleet


# Anywhere it fits, hidden from the opponent
func _place(ship: Ship) -> void:
	var spots: Array[Array] = []
	for x: int in grid.columns_of(player_num):
		for y in Grid.ROWS:
			for dir in DIRECTIONS:
				if ship.can_place(Vector2i(x, y), dir):
					spots.append([Vector2i(x, y), dir])
	var spot: Array = spots.pick_random()
	ship.set_grid_position(spot[0], spot[1])
	ship.visible = false


func new_turn() -> void:
	super()
	_take_the_helm()


func resume_turn() -> void:
	_take_the_helm()


# Our turn plays out in front of the opponent with our ships cloaked
func _take_the_helm() -> void:
	for ship in ships:
		ship.cloaked = true
		ship.visible = true
	active = true


# Copies of the opponent's ships we've seen are for us to know about, not to
# put on the opponent's screen
func show_revealed(_ship: Ship) -> void:
	pass


func finish_turn() -> void:
	super()
	for ship in ships:
		ship.cloaked = false
		ship.visible = false
	active = false


func get_move() -> void:
	# Deferred: Root only starts waiting for made_move once this returns
	_move.call_deferred()


func _move() -> void:
	var move := _best_attack()
	if move.is_empty():
		move = _best_move()
	await (
		get_tree()
		. create_timer(MOVE_PAUSE if move.is_empty() or move[1] in MOVES else ATTACK_PAUSE, false)
		. timeout
	)
	if move.is_empty():
		# Nothing worth doing with the AP left
		end_turn()
	else:
		await perform(move[0], move[1], move[2])
	made_move.emit()


# [ship, action, no target] for the move that most improves a ship's lot, or
# [] if none does
func _best_move() -> Array:
	var best := []
	var best_gain := 0.0
	for ship in ships:
		var here := _danger(ship, ship.get_occupied_hexes())
		for action in MOVES:
			if not can_perform(ship, action):
				continue
			var gain := here - _danger(ship, _hexes_after(ship, action))
			# Moving costs AP that could have gone elsewhere; reversing costs most
			gain -= 0.05 if action != "reverse" else 0.2
			if gain > best_gain:
				best = [ship, action, Grid.OFF_GRID]
				best_gain = gain
	return best


func _hexes_after(ship: Ship, action: String) -> Array[Vector2i]:
	match action:
		"forward":
			return ship.hexes_at(grid.get_hex_neighbor(ship.hex, ship.direction), ship.direction)
		"reverse":
			return ship.hexes_at(
				grid.get_hex_neighbor(ship.hex, ship.direction + 180), ship.direction
			)
		"port":
			return ship.hexes_at(ship.hex, ship.direction - 60)
	return ship.hexes_at(ship.hex, ship.direction + 60)


# How much trouble `ship` would be in on `hexes`, judged by what the opponent
# has seen of our side lately. The tender is drawn to damaged ships instead.
func _danger(ship: Ship, hexes: Array[Vector2i]) -> float:
	var danger := 0.0
	for hex in hexes:
		for near: Vector2i in grid.get_all_hex_neighbors(hex) + [hex]:
			for event: Array in grid.tile(near).history:
				if grid.turn - event[0] > 1:
					continue
				var text: String = event[1]
				if text.begins_with("Hit") or text.contains(" revealed by "):
					danger += SPOTTED if near == hex and ship.get_occupied_hexes().has(hex) else 0.0
				if text.begins_with("Miss") or text.begins_with("Hit"):
					danger += SHELLED
	if ship is SupplyTender and ship.special.cooldown_current <= 1:
		for other in ships:
			if other != ship and other.hit_hexes.has(true):
				for hex in hexes:
					for h in other.get_occupied_hexes():
						if Grid.distance(hex, h) == 1:
							return danger - UNREP_VALUE * other.hit_hexes.count(true)
	return danger


# [ship, action, target] for the attack worth the most, or [] if none is legal
func _best_attack() -> Array:
	var map := HeatMap.new(
		grid, opponent.player_num, opponent.ships, temp_revealed_ships, grid.turn
	)
	var best := []
	var best_score := -1.0
	for ship in ships:
		for kind in ATTACKS:
			if kind == "special" and ship is SupplyTender:
				for near in (ship as SupplyTender).adjacent_ships():
					var score := near.hit_hexes.count(true) * UNREP_VALUE
					if score > maxf(best_score, 0.0) and can_perform(ship, kind, near.hex):
						best = [ship, kind, near.hex]
						best_score = score
				continue
			for hex: Vector2i in map.heat:
				# A hair of noise, so ties don't always go the same way
				var score := _score(map, ship, kind, hex) + randf() * 0.001
				if score > maxf(best_score, 0.001) and can_perform(ship, kind, hex):
					best = [ship, kind, hex]
					best_score = score
	return best


func _score(map: HeatMap, ship: Ship, kind: String, hex: Vector2i) -> float:
	if kind == "fire":
		return 0.0 if hex in map.fresh_hits else map.heat[hex]
	var ability := ship.special if kind == "special" else ship.secondary
	var worth: float = VALUES.get(ability.name, 0.5)
	match ability.name:
		"Salvo":
			# Dead-on a damaged hex sinks the ship
			var sinks := 2.0 if hex in map.fresh_hits else 0.0
			return worth * map.area(map.heat, hex, ability.aoe) + sinks
		"Nuclear Strike":
			# Dead-on sinks whatever it hits
			return worth * (map.area(map.heat, hex, ability.aoe) + map.heat[hex])
		"ASW Strike":
			return worth * map.area(map.sub_heat, hex, ability.aoe)
		"Recon Flight":
			return worth * map.row(hex)
	return worth * map.area(map.heat, hex, ability.aoe)
