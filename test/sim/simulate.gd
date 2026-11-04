extends SceneTree
# Plays one game of the AI against itself, each side with a persona, and
# appends what happened as a line of JSON to a file, for balance passes
# (fl-gm5). Headless and sped up:
#   godot --headless --path . -s res://test/sim/simulate.gd -- \
#     <out.jsonl> <seed> <persona> <persona>
# test/sim/run.sh plays many in parallel.

const SELECTION := preload("res://gui/ship_selection.gd")
const SPEED := 20.0
# A game still going after this many turns counts as a draw
const MOST_TURNS := 40
# A fleet down to this share of its points is in its endgame
const ENDGAME := 0.25
# Fleets by their AIPlayer.FLEETS index: classic, gun line, carrier group,
# wolfpack, fortress
const PERSONAS := {
	# The AI as it ships: any fleet, its own judgement
	"standard": {},
	# Keeps out of trouble, values knowing where things are, mends
	"turtle":
	{
		"fleets": [4, 0],
		"shelled": 0.5,
		"spotted": 2.5,
		"unrep_value": 0.8,
		"values": {"Sonar Pulse": 0.5, "Recon Flight": 0.5},
	},
	# Big guns, stands its ground
	"brawler": {"fleets": [1], "shelled": 0.05, "spotted": 0.3, "values": {"Salvo": 1.6}},
	# Carriers, scouting and jamming
	"airboss":
	{"fleets": [2], "values": {"Recon Flight": 0.8, "EW Strike": 0.6, "Sonar Pulse": 0.4}},
	# Submarines, nukes and hunting the other side's subs
	"wolfpack":
	{"fleets": [3], "values": {"Nuclear Strike": 1.8, "ASW Strike": 2.5, "Sonar Pulse": 0.5}},
}

var game: Root
# Every ship at the start: [ship, its record]
var fleet: Array[Array] = []
# The attack under way: who made it, and the other side's ships and hits
# before it landed
var attacker: Ship
var before := {}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	seed(int(args[1]))
	var names: Array = [args[2], args[3]]
	Engine.time_scale = SPEED
	SaveGame.dir = "user://sim_saves"
	Root.mode = Root.Mode.SIMULATION
	Root.personas.clear()
	for persona_name: String in names:
		var persona: Dictionary = PERSONAS[persona_name].duplicate(true)
		if persona.has("fleets"):
			persona.fleets = persona.fleets.map(
				func(i: int) -> Dictionary: return AIPlayer.FLEETS[i]
			)
		Root.personas.append(persona)
	game = load("res://game/root.tscn").instantiate()
	root.add_child(game)
	for player in game.players:
		player.attack_started.connect(_on_attack_started)
		player.attack_resolved.connect(_on_attack_resolved)
	while game.current_turn < 1:
		await process_frame
	for player in game.players:
		for ship in player.ships:
			var points: int = SELECTION.POINT_VALUES[ship.ship_type.to_pascal_case()]
			var record := {
				"side": player.player_num,
				"type": ship.ship_type,
				"points": points,
				"kills": 0,
				"hits": 0,
				"sunk": 0,
				"by": "",
			}
			fleet.append([ship, record])
	# Each side's share of its points left, at the start of each turn
	var left: Array = [[], []]
	var turn := 0
	while not _ended() and game.current_turn <= MOST_TURNS:
		if game.current_turn != turn:
			turn = game.current_turn
			print(
				"turn ",
				turn,
				": ",
				game.players[0].ships.size(),
				" v ",
				game.players[1].ships.size()
			)
			for side in 2:
				left[side].append(snappedf(_share_left(side), 0.01))
		await process_frame
	var winner := -1
	if _ended():
		winner = 0 if game.players[0].can_fight() else 1
	# Sunk with no attack to blame: a mine
	for entry in fleet:
		if entry[1].sunk == 0 and _gone(entry[0]):
			entry[1].sunk = game.current_turn
		if entry[1].sunk != 0 and entry[1].by == "":
			entry[1].by = "mine"
	var result := {
		"seed": int(args[1]),
		"personas": names,
		"fleets": [_makeup(0), _makeup(1)],
		"winner": winner,
		"turns": game.current_turn,
		"left": left,
		"endgame": _endgame(left, winner),
		"ships": fleet.map(func(entry: Array) -> Dictionary: return entry[1]),
	}
	var file := FileAccess.open(out, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(out, FileAccess.WRITE)
	file.seek_end()
	file.store_line(JSON.stringify(result))
	file.close()
	print(
		(
			"%s vs %s: %s in %d turns"
			% [
				names[0],
				names[1],
				"draw" if winner == -1 else names[winner] + " won",
				game.current_turn
			]
		)
	)
	quit()


func _ended() -> bool:
	return not game.players[0].can_fight() or not game.players[1].can_fight()


func _share_left(side: int) -> float:
	var total := 0.0
	var afloat := 0.0
	for entry in fleet:
		if entry[1].side == side:
			total += entry[1].points
			if entry[1].sunk == 0:
				afloat += entry[1].points
	return afloat / total


func _makeup(side: int) -> Dictionary:
	var counts := {}
	for entry in fleet:
		if entry[1].side == side:
			counts[entry[1].type] = counts.get(entry[1].type, 0) + 1
	return counts


# The turn the loser fell to ENDGAME of its points, and how many turns it
# lasted after
func _endgame(left: Array, winner: int) -> Dictionary:
	if winner == -1:
		return {}
	var shares: Array = left[1 - winner]
	for turn in shares.size():
		if shares[turn] <= ENDGAME:
			return {"from": turn + 1, "lasted": shares.size() - turn - 1}
	return {"from": shares.size(), "lasted": 0}


func _on_attack_started(ship: Ship, _kind: String, _target: Vector2i) -> void:
	attacker = ship
	before.clear()
	for entry in fleet:
		if entry[1].side != ship.player.player_num and entry[1].sunk == 0:
			before[entry[0]] = (entry[0] as Ship).hit_hexes.count(true)


func _on_attack_resolved() -> void:
	var by: Dictionary = _record(attacker)
	for entry in fleet:
		if not before.has(entry[0]):
			continue
		if not _gone(entry[0]):
			by.hits += (entry[0] as Ship).hit_hexes.count(true) - int(before[entry[0]])
		elif entry[1].sunk == 0:
			entry[1].sunk = game.current_turn
			entry[1].by = attacker.ship_type
			by.kills += 1
	# Sinkings outside an attack (mines) are noticed as the turn goes on
	for entry in fleet:
		if entry[1].sunk == 0 and _gone(entry[0]):
			entry[1].sunk = game.current_turn


# Sunk, and maybe freed already (so not to be held as a Ship)
func _gone(ship: Variant) -> bool:
	return not is_instance_valid(ship) or (ship as Ship).sunk


func _record(ship: Ship) -> Dictionary:
	for entry in fleet:
		if entry[0] == ship:
			return entry[1]
	# A copy (a revealed one), or one we never saw: counted nowhere
	return {"kills": 0, "hits": 0}
