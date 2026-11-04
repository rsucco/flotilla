extends AIPlayer
# A player played from outside the game, by an agent, through files in `dir`
# (for balance passes, fl-gm5.2). It sets up as the AI would. As each of its
# turns starts it writes `state_<seat>.json`: only what a player could know
# (its own fleet, the board's history, the islands, the opponent's fleet by
# type). It then waits for `plan_<seat>.json`, a list of moves:
#   [{"ship": "<id>", "action": "fire", "target": [x, y]}, ...]
# (actions: forward, reverse, port, starboard, fire, special, secondary; the
# tender's special targets one of our ships). It plays them in order,
# skipping any it can't make, then ends the turn. The next state says how
# each went. When the game's over it writes the state with "over" set.
# test/sim/turn.sh is the agent's side of this.

var dir: String
var _plan: Array = []
var _planned_turn := -1
# How the last plan's moves went, for the next state
var _report: Array[String] = []


func _init(num: int, from: String) -> void:
	super(num)
	dir = from


func get_move() -> void:
	_next.call_deferred()


func _next() -> void:
	if _planned_turn != grid.turn:
		_planned_turn = grid.turn
		_plan = await _ask()
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
		_report.append("can't: %s" % JSON.stringify(move))
	end_turn()
	made_move.emit()


# Writes what we know and waits for the agent's plan for this turn
func _ask() -> Array:
	var plan := "%s/plan_%d.json" % [dir, player_num]
	_write(_state())
	while not FileAccess.file_exists(plan):
		await get_tree().create_timer(0.25, true, false, true).timeout
	var text := FileAccess.get_file_as_string(plan)
	DirAccess.remove_absolute(plan)
	DirAccess.remove_absolute("%s/state_%d.json" % [dir, player_num])
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Array else []


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
		if ship.title == id:
			return ship
	return null


func _state() -> Dictionary:
	var fleet := []
	for ship in ships:
		fleet.append(
			{
				"id": ship.title,
				"type": ship.ship_name,
				"hexes":
				ship.get_occupied_hexes().map(func(h: Vector2i) -> Array: return [h.x, h.y]),
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
	var theirs := {}
	for ship in opponent.ships:
		theirs[ship.ship_name] = theirs.get(ship.ship_name, 0) + 1
	var history := {}
	for x in Grid.COLUMNS:
		for y in Grid.ROWS:
			var events: Array = grid.tile(Vector2i(x, y)).history
			if not events.is_empty():
				history["%d,%d" % [x, y]] = events
	return {
		"you": player_num,
		"turn": grid.turn,
		"your_columns": grid.columns_of(player_num),
		"their_columns": grid.columns_of(1 - player_num),
		"rows": Grid.ROWS,
		"islands": grid.get_islands().map(func(h: Vector2i) -> Array: return [h.x, h.y]),
		"your_fleet": fleet,
		"their_fleet": theirs,
		"history": history,
		"last_turn": _report,
	}


func _ability(ability: SpecialAbility) -> Variant:
	if ability.name.is_empty() or ability.name == "None":
		return null
	return {"name": ability.name, "turns_to_ready": ability.cooldown_current, "what": ability.desc}
