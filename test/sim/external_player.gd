extends AIPlayer
# A player played from outside the game, by an agent, through files in `dir`
# (for balance passes, fl-gm5.2). Each time it needs a decision it writes
# `state_<seat>.json` and waits for `plan_<seat>.json`.
# Setup: a state with "phase": "fleet", answered with
#   {"Battleship": 2, "Corvette": 1, ...}
# then one with "phase": "placement" (which also lists what was rejected, up
# to TRIES times), answered with
#   {"<id>": {"centre": [x, y], "facing": 60}, ...}
# A fleet outside the rules is replaced as the AI would choose, and ships
# still not placed go where the AI would put them.
# As each turn starts the state is only what a player could know (its own
# fleet, the board's history, the islands, the opponent's fleet by type),
# answered with a list of moves:
#   [{"ship": "<id>", "action": "fire", "target": [x, y]}, ...]
# (actions: forward, reverse, port, starboard, fire, special, secondary; the
# tender's special targets one of our ships). It plays them in order,
# skipping any it can't make, then ends the turn. The next state says how
# each went, and why any couldn't be made. When the game's over it writes the state with "over" set.
# test/sim/turn.sh is the agent's side of this.

# Goes at placing ships before the AI places the rest
const TRIES := 3

var dir: String
# Each ship's id, the same all game (a title may have accents to get wrong)
var _ids := {}
var _plan: Array = []
var _planned_turn := -1
# How the last plan's moves went, for the next state
var _report: Array[String] = []


func _init(num: int, from: String) -> void:
	super(num)
	dir = from


func get_ship_selection() -> Dictionary:
	var fallback := super()
	var chosen: Variant = await _ask(
		{
			"phase": "fleet",
			"you": player_num,
			"budget": SELECTION.POINTS_BUDGET,
			"most_of_a_type": SELECTION.MAX_PER_TYPE,
			"costs": SELECTION.POINT_VALUES,
			"your_islands": grid.get_num_island_tiles(player_num),
			"islands": _pairs(grid.get_islands()),
			"your_columns": grid.columns_of(player_num),
			"rows": Grid.ROWS,
		}
	)
	var fleet := _legal_fleet(chosen)
	return fleet if not fleet.is_empty() else fallback


func _legal_fleet(chosen: Variant) -> Dictionary:
	if not chosen is Dictionary:
		return {}
	var fleet := {}
	var points := 0
	for ship_type: String in chosen:
		if (
			not SELECTION.POINT_VALUES.has(ship_type)
			or int(chosen[ship_type]) > SELECTION.MAX_PER_TYPE
		):
			return {}
		fleet[ship_type] = int(chosen[ship_type])
		points += fleet[ship_type] * SELECTION.POINT_VALUES[ship_type]
	var batteries: int = fleet.get("CoastalBattery", 0)
	if points > SELECTION.POINTS_BUDGET or batteries > grid.get_num_island_tiles(player_num):
		return {}
	return fleet


func place_ships(counts: Dictionary) -> void:
	var waiting: Array[Ship] = []
	for ship_type: String in counts:
		for i in counts[ship_type]:
			var ship: Ship = (
				load("res://ships/" + ship_type.to_snake_case() + ".tscn").instantiate()
			)
			adopt(ship)
			# In the fleet straight away, or adopt() would give out names twice
			ships.append(ship)
			_ids[ship] = "%s_%d" % [ship_type.to_snake_case(), i + 1]
			waiting.append(ship)
	var rejected: Array[String] = []
	for _try in TRIES:
		if waiting.is_empty():
			break
		var plan: Variant = await _ask(_placement_state(waiting, rejected))
		rejected.clear()
		for ship: Ship in waiting.duplicate():
			var spot: Variant = plan.get(_ids[ship]) if plan is Dictionary else null
			if _try_spot(ship, spot):
				waiting.erase(ship)
			else:
				rejected.append("%s: %s" % [_ids[ship], JSON.stringify(spot)])
	for ship in waiting:
		await _place(ship)
	fleet_size = ships.size()


func _try_spot(ship: Ship, spot: Variant) -> bool:
	if not spot is Dictionary or not spot.has("centre") or not spot.has("facing"):
		return false
	var at := Vector2i(int(spot.centre[0]), int(spot.centre[1]))
	var facing := int(spot.facing)
	if facing not in DIRECTIONS or not ship.can_place(at, facing):
		return false
	ship.set_grid_position(at, facing)
	ship.visible = false
	return true


func _placement_state(waiting: Array[Ship], rejected: Array[String]) -> Dictionary:
	var to_place := []
	for ship in waiting:
		var info := {"id": _ids[ship], "type": ship.ship_name}
		info.hexes_ahead_of_centre = ship.len_fore
		info.hexes_behind_centre = ship.len_aft
		to_place.append(info)
	var placed := []
	for ship in ships:
		if waiting.has(ship):
			continue
		placed.append({"id": _ids[ship], "hexes": _pairs(ship.get_occupied_hexes())})
	return {
		"phase": "placement",
		"you": player_num,
		"your_columns": grid.columns_of(player_num),
		"rows": Grid.ROWS,
		"islands": _pairs(grid.get_islands()),
		"to_place": to_place,
		"placed": placed,
		"rejected": rejected,
	}


func _pairs(hexes: Array[Vector2i]) -> Array:
	return hexes.map(func(h: Vector2i) -> Array: return [h.x, h.y])


func get_move() -> void:
	_next.call_deferred()


func _next() -> void:
	if _planned_turn != grid.turn:
		_planned_turn = grid.turn
		var plan: Variant = await _ask(_state())
		_plan = plan if plan is Array else []
		_report.clear()
	while not _plan.is_empty():
		var move: Dictionary = _plan.pop_front()
		var ship := _ship(str(move.get("ship", "")))
		var action := str(move.get("action", ""))
		var at: Array = move.get("target", [-1, -1])
		var target := Vector2i(int(at[0]), int(at[1])) if at.size() == 2 else Grid.OFF_GRID
		if ship != null and can_perform(ship, action, target):
			_report.append("done: %s" % JSON.stringify(move))
			await perform(ship, action, target)
			made_move.emit()
			return
		_report.append("can't (%s): %s" % [_why(ship, action, target), JSON.stringify(move)])
	end_turn()
	made_move.emit()


func _why(ship: Ship, action: String, target: Vector2i) -> String:
	if ship == null or not (action in Helm.MOVES or action in ATTACKS):
		return "no such ship or action"
	if action in Helm.MOVES:
		return Helm.refusal(ship, action)
	if ship.ap < 2:
		return "not enough AP"
	return _why_no_attack(ship, action, target)


func _why_no_attack(ship: Ship, action: String, target: Vector2i) -> String:
	var ability := ship.special if action == "special" else ship.secondary
	var reason := "not allowed against that target"
	if ship is SupplyTender:
		reason = "needs one of our ships within %d hexes" % SupplyTender.REACH
	elif grid.side_of(target) != opponent.player_num:
		reason = "target isn't on their side of the board"
	if action == "fire":
		if ship.weapon == "None":
			reason = "unarmed"
		elif ship.jammed_this_turn:
			reason = "jammed by EW Strike"
		elif ship.fire_remaining < 1:
			reason = "no fire actions left"
	elif ability.name == "None" or ability.name.is_empty():
		reason = "no such ability"
	elif ability.cooldown_current > 0:
		reason = "on cooldown for %d more turns" % ability.cooldown_current
	return reason


# Writes `state` and waits for the agent's answer
func _ask(state: Dictionary) -> Variant:
	var plan := "%s/plan_%d.json" % [dir, player_num]
	_write(state)
	while not FileAccess.file_exists(plan):
		await get_tree().create_timer(0.25, true, false, true).timeout
	var text := FileAccess.get_file_as_string(plan)
	DirAccess.remove_absolute(plan)
	DirAccess.remove_absolute("%s/state_%d.json" % [dir, player_num])
	return JSON.parse_string(text)


# The game's over: says so, with who won
func tell_over(winner: int) -> void:
	var state := _state()
	state.over = true
	state.won = winner == player_num
	_write(state)


func _write(state: Dictionary) -> void:
	var path := "%s/state_%d.json" % [dir, player_num]
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


func _ship(id: String) -> Ship:
	for ship in ships:
		if _ids[ship] == id:
			return ship
	return null


func _state() -> Dictionary:
	var fleet := []
	for ship in ships:
		(
			fleet
			. append(
				{
					"id": _ids[ship],
					"name": ship.title,
					"type": ship.ship_name,
					"hexes": _pairs(ship.get_occupied_hexes()),
					"centre": [ship.hex.x, ship.hex.y],
					"facing": posmod(ship.direction, 360),
					"damaged": ship.hit_hexes,
					"ap": ship.ap,
					"attacks_left": ship.fire_remaining,
					"weapon": ship.weapon,
					"special": _ability(ship.special),
					"secondary": _ability(ship.secondary),
					"passive": "%s: %s" % [ship.passive.name, ship.passive.desc],
					"drawback": "%s: %s" % [ship.drawback.name, ship.drawback.desc],
				}
			)
		)
	var theirs := {}
	for ship in opponent.ships:
		theirs[ship.ship_name] = theirs.get(ship.ship_name, 0) + 1
	var history := {}
	for x in Grid.COLUMNS:
		for y in Grid.ROWS:
			var events: Array = grid.tile(Vector2i(x, y)).history
			# As the game's own tile history: their mines on our side stay hidden
			if grid.side_of(Vector2i(x, y)) == player_num:
				events = events.filter(func(e: Array) -> bool: return e[1] != "Mine laid")
			if not events.is_empty():
				history["%d,%d" % [x, y]] = events
	return {
		"you": player_num,
		"turn": grid.turn,
		"your_columns": grid.columns_of(player_num),
		"their_columns": grid.columns_of(1 - player_num),
		"rows": Grid.ROWS,
		"islands": _pairs(grid.get_islands()),
		"your_fleet": fleet,
		"their_fleet": theirs,
		"history": history,
		"last_turn": _report,
	}


func _ability(ability: SpecialAbility) -> Variant:
	if ability.name.is_empty() or ability.name == "None":
		return null
	return {"name": ability.name, "turns_to_ready": ability.cooldown_current, "what": ability.desc}
