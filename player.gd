class_name Player
extends Control

signal made_move

const INTERCEPT_SOUND := preload("res://audio/ciws.wav")
# Abilities that can damage ships, which count toward the hit rate
const DAMAGING_ABILITIES: Array[String] = ["Salvo", "Nuclear Strike", "ASW Strike"]

var player_num: int
var ships: Array[Ship] = []
var temp_revealed_ships: Array[Ship] = []
var selected_ship: Ship
var root: Root
# For the victory screen
var fleet_size := 0
var attacks := 0
var hits := 0


func _init(num: int) -> void:
	player_num = num


# Subclasses must call super() first
func _ready() -> void:
	root = get_parent()


func opponent() -> Player:
	return root.players[1 - player_num]


func has_moves() -> bool:
	# Don't make any more moves if the opponent is defeated
	if opponent().ships.is_empty():
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
		add_child(revealed)
		revealed.visible = true
		revealed.modulate = Color(1.0, 1.0, 1.0, 0.8)


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


func get_ship_at_hex(hex: Vector2i) -> Ship:
	for ship in ships:
		if ship.get_occupied_hexes().has(hex):
			return ship
	return null


func get_hover_hexes(hex: Vector2i) -> Array[Vector2i]:
	return [hex]


func log_event(hex: Vector2i, event: String) -> void:
	root.grid.tile(hex).history.append([root.current_turn, event])


# Resolves a shot at one of our hexes; returns the ship hit, or null on a miss
func receive_fire(hex: Vector2i, from_ship: Ship) -> Ship:
	var target := get_ship_at_hex(hex)
	if target == null:
		log_event(hex, "Miss")
		return null
	# Missile-based weapons (cruisers, destroyers, carriers) can be intercepted
	if from_ship.ship_type in ["destroyer", "cruiser", "carrier"] and cruiser_intercepts(hex, 0.5):
		log_event(hex, "Miss (CIWS intercepted hit)")
		return null
	target.hit(hex, from_ship)
	return target


# Passive - Missile Defense: rolls to intercept an attack on `hex` if one of
# our cruisers is within two hexes. Multiple cruisers don't stack.
func cruiser_intercepts(hex: Vector2i, chance: float) -> bool:
	for h in root.grid.get_all_hex_neighbors(hex, 2):
		var cruiser := get_ship_at_hex(h)
		if cruiser != null and cruiser.ship_type == "cruiser":
			if randf() >= chance:
				return false
			print("passive - missile defense")
			Sfx.play(self, INTERCEPT_SOUND)
			return true
	return false


func receive_special(hex: Vector2i, from_ship: Ship, use_secondary: bool = false) -> void:
	var ability := from_ship.secondary if use_secondary else from_ship.special
	match ability.name:
		"ASW Strike":
			# Instantly sinks any submarines on the hex or its direct neighbors
			var affected := root.grid.get_all_hex_neighbors(hex, ability.aoe)
			affected.append(hex)
			var sunk_hexes: Array[Vector2i] = []
			for h in affected:
				var ship := get_ship_at_hex(h)
				if ship != null and ship.ship_type == "submarine":
					sunk_hexes.append_array(ship.get_occupied_hexes())
					ship.sink()
				elif not sunk_hexes.has(h):
					log_event(h, "Miss (ASW Strike)")

		"Lay Mine":
			root.grid.tile(hex).is_mined = true
			log_event(hex, "Mine laid")

		"Sonar Pulse":
			# Reveals ships around the hex, and also reveals the submarine
			var revealed_sub: Ship = from_ship.duplicate()
			temp_revealed_ships.append(revealed_sub)
			from_ship.revealed_buddy = revealed_sub
			for h in from_ship.get_occupied_hexes():
				log_event(h, "Submarine used Sonar Pulse")
			var searched := root.grid.get_all_hex_neighbors(hex, ability.aoe)
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
			if cruiser_intercepts(hex, 0.25):
				log_event(hex, "Miss (CIWS intercepted Nuclear Strike)")
				return
			var checked: Array[Vector2i] = []
			var dead_center := get_ship_at_hex(hex)
			if dead_center != null:
				checked.append_array(dead_center.get_occupied_hexes())
				dead_center.sink()
			for h in root.grid.get_all_hex_neighbors(hex, ability.aoe):
				if checked.has(h):
					continue
				checked.append(h)
				var ship := get_ship_at_hex(h)
				if ship != null:
					ship.hit(h, from_ship)
				else:
					log_event(h, "Miss (Nuclear Strike)")

		"EW Strike":
			# Prevents firing next turn, and adds 5 turns to ability cooldowns
			# or resets them, whichever is less
			var struck: Array[Ship] = []
			for h in root.grid.get_all_hex_neighbors(hex, ability.aoe):
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
			var search := root.grid.get_all_hex_neighbors(hex, ability.aoe)
			if dead_center == null:
				log_event(hex, "Miss (Salvo)")
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
					log_event(h, "Miss (Salvo)")

		"Recon Flight":
			# Reveals everything but submarines in the target row
			var revealed: Array[Ship] = []
			for x: int in root.grid.columns_of(player_num):
				var ship := get_ship_at_hex(Vector2i(x, hex.y))
				if ship != null and ship.ship_type != "submarine" and not revealed.has(ship):
					reveal(ship, " revealed by Recon Flight")
					revealed.append(ship)


func reveal(ship: Ship, event: String) -> void:
	ship.visible = true
	ship.modulate = Color(1.0, 1.0, 1.0, 0.8)
	for h in ship.get_occupied_hexes():
		log_event(h, ship.ship_name + event)
