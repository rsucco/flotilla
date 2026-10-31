class_name Player
extends Control

signal made_move
# A ship of ours sank
signal fleet_changed
# An attack on the opponent: before its animation, just before the opponent
# resolves it, and once resolved (the turn replay records them)
signal attack_started(ship: Ship, kind: String, target: Vector2i)
signal attack_landed
signal attack_resolved
# One of our ships set off an opponent's mine at `hex`
signal mine_blast(hex: Vector2i)

# Abilities that can damage ships, which count toward the hit rate
const DAMAGING_ABILITIES: Array[String] = ["Salvo", "Nuclear Strike", "ASW Strike"]

var player_num: int
var ships: Array[Ship] = []
var temp_revealed_ships: Array[Ship] = []
var selected_ship: Ship
var grid: Grid
# Where our ships put projectiles and other effects
var effects: Node2D
# Set by Root once both players exist
var opponent: Player
# For the victory screen
var fleet_size := 0
var attacks := 0
var hits := 0
# Whether our cruisers will shoot down the attack being made on us
var intercepting := false
# The cruiser that made the last intercept
var interceptor: Ship


func _init(num: int) -> void:
	player_num = num


func _exit_tree() -> void:
	# Copies aren't in the tree until new_turn() adopts them, so a game that
	# ends first must free them itself
	for revealed in temp_revealed_ships:
		if is_instance_valid(revealed) and not revealed.is_inside_tree():
			revealed.free()


func has_moves() -> bool:
	# Don't make any more moves if the opponent is defeated
	if opponent.ships.is_empty():
		return false
	return ships.any(func(s: Ship) -> bool: return s.ap > 0)


func new_turn() -> void:
	for ship in ships:
		ship.new_turn()
		# After new_turn so it also overrides the carrier's extra fire action
		if ship.jammed:
			print("ew strike - jammed")
			ship.fire_remaining = 0
			ship.jammed = false
	for revealed in temp_revealed_ships:
		show_revealed(revealed)


# Shows a copy of an opponent's ship that gave itself away (the turn replay
# may already have shown it)
func show_revealed(ship: Ship) -> void:
	if not ship.is_inside_tree():
		adopt(ship)
	ship.visible = true
	ship.modulate = Color(1.0, 1.0, 1.0, 0.8)


func finish_turn() -> void:
	for revealed in temp_revealed_ships:
		if is_instance_valid(revealed):
			revealed.queue_free()
	temp_revealed_ships.clear()
	selected_ship = null


# Damage on our ships still afloat, to tell whether an attack hit
func damage_taken() -> int:
	var total := 0
	for ship in ships:
		total += ship.hit_hexes.count(true)
		if ship is CoastalBattery:
			total += 5 - (ship as CoastalBattery).hp
	return total


# Adds one of our ships (or a copy of an opponent's) with what it needs
func adopt(ship: Ship) -> void:
	ship.player = self
	ship.grid = grid
	ship.effects = effects
	ship.sank.connect(_on_ship_sank.bind(ship))
	ship.mine_hit.connect(mine_blast.emit)
	add_child(ship)


func _on_ship_sank(ship: Ship) -> void:
	ships.erase(ship)
	fleet_changed.emit()


func get_ship_at_hex(hex: Vector2i) -> Ship:
	for ship in ships:
		if ship.get_occupied_hexes().has(hex):
			return ship
	return null


func get_hover_hexes(hex: Vector2i) -> Array[Vector2i]:
	return [hex]


# Resolves a shot at one of our hexes; returns the ship hit, or null on a miss
func receive_fire(hex: Vector2i, from_ship: Ship) -> Ship:
	var target := get_ship_at_hex(hex)
	if target == null:
		grid.log_event(hex, "Miss")
		return null
	if intercepting:
		intercepting = false
		grid.log_event(hex, "Miss (CIWS intercepted hit)")
		return null
	target.hit(hex, from_ship)
	return target


# Passive - Missile Defense: decides as an attack starts whether our cruisers
# will shoot it down, so the missile can be seen dying on its way in. Missiles
# (from destroyers, cruisers and carriers) on a ship can be intercepted, and
# so can a Nuclear Strike.
func roll_intercept(from_ship: Ship, kind: String, hex: Vector2i) -> bool:
	intercepting = false
	if kind == "fire" and from_ship.ship_type in ["destroyer", "cruiser", "carrier"]:
		intercepting = get_ship_at_hex(hex) != null and cruiser_intercepts(hex, 0.5)
	elif kind == "special" and from_ship.special.name == "Nuclear Strike":
		intercepting = cruiser_intercepts(hex, 0.25)
	return intercepting


# Rolls to intercept an attack on `hex` if one of our cruisers is within two
# hexes. Multiple cruisers don't stack.
func cruiser_intercepts(hex: Vector2i, chance: float) -> bool:
	for h in grid.get_all_hex_neighbors(hex, 2):
		var cruiser := get_ship_at_hex(h)
		if cruiser != null and cruiser.ship_type == "cruiser":
			if randf() >= chance:
				return false
			print("passive - missile defense")
			interceptor = cruiser
			return true
	return false


func receive_special(hex: Vector2i, from_ship: Ship, use_secondary: bool = false) -> void:
	var ability := from_ship.secondary if use_secondary else from_ship.special
	match ability.name:
		"ASW Strike":
			# Instantly sinks any submarines on the hex or its direct neighbors
			var affected := grid.get_all_hex_neighbors(hex, ability.aoe)
			affected.append(hex)
			var sunk_hexes: Array[Vector2i] = []
			for h in affected:
				var ship := get_ship_at_hex(h)
				if ship != null and ship.ship_type == "submarine":
					sunk_hexes.append_array(ship.get_occupied_hexes())
					ship.sink()
				elif not sunk_hexes.has(h):
					grid.log_event(h, "Miss (ASW Strike)")

		"Lay Mine":
			grid.tile(hex).is_mined = true
			grid.log_event(hex, "Mine laid")

		"Sonar Pulse":
			# Reveals ships around the hex, and also reveals the submarine
			var revealed_sub: Ship = from_ship.duplicate()
			temp_revealed_ships.append(revealed_sub)
			from_ship.revealed_buddy = revealed_sub
			for h in from_ship.get_occupied_hexes():
				grid.log_event(h, "Submarine used Sonar Pulse")
			var searched := grid.get_all_hex_neighbors(hex, ability.aoe)
			searched.append(hex)
			var revealed: Array[Ship] = []
			for h in searched:
				var ship := get_ship_at_hex(h)
				if ship != null and ship.ship_type != "coastal_battery" and not revealed.has(ship):
					reveal(ship, " revealed by Sonar Pulse")
					revealed.append(ship)

		"Nuclear Strike":
			# Destroys anything it hits dead-on (including coastal batteries);
			# otherwise hits normally in the area of effect. An intercept
			# cancels the whole strike.
			if intercepting:
				intercepting = false
				grid.log_event(hex, "Miss (CIWS intercepted Nuclear Strike)")
				return
			var checked: Array[Vector2i] = []
			var dead_center := get_ship_at_hex(hex)
			if dead_center != null:
				checked.append_array(dead_center.get_occupied_hexes())
				dead_center.sink()
			for h in grid.get_all_hex_neighbors(hex, ability.aoe):
				if checked.has(h):
					continue
				checked.append(h)
				var ship := get_ship_at_hex(h)
				if ship != null:
					ship.hit(h, from_ship)
				else:
					grid.log_event(h, "Miss (Nuclear Strike)")

		"EW Strike":
			# Prevents firing next turn, and adds 5 turns to ability cooldowns
			# or resets them, whichever is less
			var struck: Array[Ship] = []
			for h in grid.get_all_hex_neighbors(hex, ability.aoe):
				var ship := get_ship_at_hex(h)
				if ship == null or struck.has(ship):
					continue
				for a in [ship.special, ship.secondary]:
					if a.name != "None":
						a.cooldown_current = mini(a.cooldown_current + 5, a.cooldown_interval)
				ship.jammed = true
				struck.append(ship)

		"Salvo":
			# Sinks anything when it hits a damaged hex dead-on; otherwise hits
			# normally in the area of effect
			var dead_center := get_ship_at_hex(hex)
			var search := grid.get_all_hex_neighbors(hex, ability.aoe)
			if dead_center == null:
				grid.log_event(hex, "Miss (Salvo)")
			elif dead_center.is_hex_hit(hex):
				for h in dead_center.get_occupied_hexes():
					search.erase(h)
				dead_center.sink()
			else:
				dead_center.hit(hex, from_ship)
			for h in search:
				var ship := get_ship_at_hex(h)
				if ship != null:
					ship.hit(h, from_ship)
				else:
					grid.log_event(h, "Miss (Salvo)")

		"Recon Flight":
			# Reveals everything but submarines in the target row
			var revealed: Array[Ship] = []
			for x: int in grid.columns_of(player_num):
				var ship := get_ship_at_hex(Vector2i(x, hex.y))
				if ship != null and ship.ship_type != "submarine" and not revealed.has(ship):
					reveal(ship, " revealed by Recon Flight")
					revealed.append(ship)


func reveal(ship: Ship, event: String) -> void:
	ship.visible = true
	ship.modulate = Color(1.0, 1.0, 1.0, 0.8)
	for h in ship.get_occupied_hexes():
		grid.log_event(h, ship.ship_name + event)
