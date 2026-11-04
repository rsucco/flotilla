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
# How few ships a fleet is down to before it can't hide (see give_away())
const LAST_FEW := 2
# Ships without a name from our navy are numbered by type (up to five of each)
const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V"]

var player_num: int
# Which of Navies.ALL we command, chosen with our fleet
var navy := ""
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
var conceded := false
# From an attack's start until the opponent has resolved it
var animation_playing := false
# From the start of our turn (after any replay) to its end
var active := false
# Whether to watch the opponent's turn replay at the next swap
var watch_replay := true


func _init(num: int) -> void:
	player_num = num


func _exit_tree() -> void:
	# Copies aren't in the tree until new_turn() adopts them, so a game that
	# ends first must free them itself
	for revealed in temp_revealed_ships:
		if is_instance_valid(revealed) and not revealed.is_inside_tree():
			revealed.free()


# Down to its last few ships, a fleet can't hide: as each of the opponent's
# turns starts, each of its ships gives away a contact on a patch of hexes
# around it (a submarine's wider)
func give_away() -> void:
	if ships.size() > LAST_FEW:
		return
	for ship in ships:
		for hex in grid.contact(ship.get_occupied_hexes(), 2 if ship is Submarine else 1):
			grid.log_event(hex, "Contact")


# Whether we've still a ship that can attack: a fleet of only supply tenders
# (or none at all) has lost
func can_fight() -> bool:
	return ships.any(func(ship: Ship) -> bool: return ship.weapon != "None")


func has_moves() -> bool:
	# Don't make any more moves if the opponent is defeated
	if conceded or not opponent.can_fight():
		return false
	return ships.any(func(s: Ship) -> bool: return s.ap > 0)


func new_turn() -> void:
	for ship in ships:
		ship.new_turn()
		# After new_turn so it also overrides the carrier's extra fire action
		ship.jammed_this_turn = ship.jammed
		if ship.jammed:
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


# Our navy's flag, or null without a navy (in tests)
func ensign() -> Texture2D:
	return Navies.ensign(navy) if not navy.is_empty() else null


# What to call us: our navy's name
func navy_name() -> String:
	return Navies.ALL[navy].name if not navy.is_empty() else "Player " + str(player_num + 1)


# The ships we bring, by PascalCase ship type -> count
func get_ship_selection() -> Dictionary:
	return {}


# Builds our fleet for the start of the game. `counts` is keyed by PascalCase
# ship type (ship selection node names).
func place_ships(counts: Dictionary) -> void:
	for ship_type: String in counts:
		for _i in counts[ship_type]:
			var ship: Ship = (
				load("res://ships/" + ship_type.to_snake_case() + ".tscn").instantiate()
			)
			adopt(ship)
			await _place(ship)
			ships.append(ship)
	fleet_size = ships.size()


# Puts `ship` somewhere Ship.can_place() allows. Each kind of player decides
# where: by input, by an AI, or from the network.
func _place(_ship: Ship) -> void:
	pass


# Whether our `ship` may make a move this turn: "forward", "reverse", "port",
# "starboard", or "fire", "special" or "secondary" at `target`. Whatever the
# moves come from (input, an AI, the network), they're checked here.
func can_perform(ship: Ship, action: String, target: Vector2i = Grid.OFF_GRID) -> bool:
	if not ships.has(ship):
		return false
	var at_opponent := grid.side_of(target) == opponent.player_num
	var legal := false
	match action:
		"forward":
			legal = ship.can_move()
		"reverse":
			legal = ship.can_move(true)
		"port":
			legal = ship.can_rotate(-60)
		"starboard":
			legal = ship.can_rotate(60)
		"fire":
			legal = at_opponent and ship.can_fire(target)
		"special":
			# UNREP heals one of our ships next to the tender
			if ship is SupplyTender:
				var tender := ship as SupplyTender
				legal = tender.can_special() and get_ship_at_hex(target) in tender.adjacent_ships()
			else:
				legal = at_opponent and ship.can_special()
		"secondary":
			legal = at_opponent and ship.can_secondary()
	return legal


# Makes a move that can_perform() allows. An attack plays its animation, then
# the opponent resolves it, and returns once it has.
func perform(ship: Ship, action: String, target: Vector2i = Grid.OFF_GRID) -> void:
	match action:
		"forward":
			ship.forward()
		"reverse":
			ship.reverse()
		"port":
			ship.port()
		"starboard":
			ship.starboard()
		_:
			await _attack(ship, action, target)


# Ends every ship's turn
func end_turn() -> void:
	for ship in ships:
		ship.ap = 0


# Recorded for the opponent's turn replay
func _attack(ship: Ship, kind: String, hex: Vector2i) -> void:
	animation_playing = true
	ship.intercepted = opponent.roll_intercept(ship, kind, hex)
	ship.ciws_at = opponent.interceptor.global_position if ship.intercepted else Vector2.INF
	attack_started.emit(ship, kind, hex)
	match kind:
		"fire":
			await ship.fire(hex)
		"special":
			await ship.use_special(hex)
		"secondary":
			await ship.use_secondary(hex)
	attack_landed.emit()
	var damage := opponent.damage_taken()
	var afloat := opponent.ships.size()
	if kind == "fire":
		opponent.receive_fire(hex, ship)
	else:
		opponent.receive_special(hex, ship, kind == "secondary")
	attack_resolved.emit()
	var ability := ship.special if kind == "special" else ship.secondary
	if kind == "fire" or ability.name in DAMAGING_ABILITIES:
		attacks += 1
		if opponent.damage_taken() > damage or opponent.ships.size() < afloat:
			hits += 1
	animation_playing = false


# Carries on with a turn from a saved game, with the AP it was saved with
func resume_turn() -> void:
	pass


# Starts choosing our next move, emitting made_move once it's been made
func get_move() -> void:
	pass


# Gives up, ending the turn (and the game)
func concede() -> void:
	conceded = true
	made_move.emit()


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
	if ship.title.is_empty():
		var taken: Array[String] = []
		taken.assign(ships.map(func(s: Ship) -> String: return s.title))
		if not navy.is_empty():
			ship.title = Navies.ship_title(navy, ship.ship_name, taken)
		# Batteries (and any ship without a navy, in tests) are just numbered
		if ship.title.is_empty():
			var alike := ships.filter(func(s: Ship) -> bool: return s.ship_name == ship.ship_name)
			ship.title = ship.ship_name + " " + NUMERALS[alike.size()]


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
			if grid.dice.roll() >= chance:
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
			# Reveals ships around the hex, and gives away the submarine's rough
			# position: a patch around it, not the submarine itself
			for h in grid.contact(from_ship.get_occupied_hexes(), 1):
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
					# Sunk by this hit (say, a Fragile corvette): its other
					# hexes aren't misses
					if ship.sunk:
						checked.append_array(ship.get_occupied_hexes())
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
			var sunk_hexes: Array[Vector2i] = []
			for h in search:
				if sunk_hexes.has(h):
					continue
				var ship := get_ship_at_hex(h)
				if ship != null:
					ship.hit(h, from_ship)
					# Sunk by this hit: its other hexes aren't misses
					if ship.sunk:
						sunk_hexes.append_array(ship.get_occupied_hexes())
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
		grid.log_event(h, ship.called() + event)
