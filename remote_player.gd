class_name RemotePlayer
extends HiddenPlayer
# The player at the other end of a LAN game. What they do arrives over the
# link and plays out here, as the AI's turn does. The host has the last word:
# it checks each of the guest's moves and rolls the dice for every move, and
# both games play each move from that seed. Our own player's moves go out
# through relay() and tell(), and setup through share_islands(), send_fleet()
# and send_placements(). Each move carries a checksum of the game as its
# sender had it, to catch the two drifting apart.

# A message arrived for _take()
signal arrived

var link: Link
# Whether this game is the host's
var hosting := false
var _inbox: Array[Dictionary] = []
# Where each of our ships goes, as sent from the other end
var _placements: Array = []


func _init(num: int, with: Link, host: bool) -> void:
	super(num)
	link = with
	hosting = host


func _ready() -> void:
	link.received.connect(
		func(message: Dictionary) -> void:
			_inbox.append(message)
			arrived.emit()
	)
	# Every frame, even under the Esc menu (which pauses the tree), or the
	# connection would time out
	get_tree().process_frame.connect(link.poll)


func _exit_tree() -> void:
	super()
	get_tree().process_frame.disconnect(link.poll)
	link.close()


# The host's islands, which the guest's board takes
func share_islands() -> void:
	# Nothing goes out before the hello, which checks we're the same build
	if not link.linked:
		await link.connected
	if hosting:
		link.send({"type": "islands", "islands": grid.get_islands()})
	else:
		var islands: Array[Vector2i] = []
		islands.assign((await _take(["islands"])).islands)
		grid.set_islands(islands)


# Our player's navy and ships
func send_fleet(counts: Dictionary) -> void:
	link.send({"type": "fleet", "navy": opponent.navy, "counts": counts})


# Theirs. A navy both chose at once is the host's, so the host waits for the
# guest to choose again.
func get_ship_selection() -> Dictionary:
	var fleet := await _take(["fleet"])
	while hosting and fleet.navy == opponent.navy:
		fleet = await _take(["fleet"])
	navy = fleet.navy
	return fleet.counts


# Where our player put each ship, and what it's called
func send_placements() -> void:
	var spots := opponent.ships.map(
		func(ship: Ship) -> Array: return [ship.hex, ship.direction, ship.title]
	)
	link.send({"type": "placed", "ships": spots})


func place_ships(counts: Dictionary) -> void:
	_placements = (await _take(["placed"])).ships
	await super(counts)


func _place(ship: Ship) -> void:
	var spot: Array = _placements.pop_front()
	ship.title = spot[2]
	if not ship.can_place(spot[0], spot[1]):
		push_error("They placed a ship where it can't go")
	ship.set_grid_position(spot[0], spot[1])
	ship.visible = false


# Our player makes a move: by way of the host, which checks it and rolls the
# dice for it
func relay(ship: Ship, action: String, target: Vector2i) -> void:
	var move := {
		"type": "move",
		"ship": opponent.ships.find(ship),
		"action": action,
		"target": target,
		"sum": checksum(),
	}
	if hosting:
		move.seed = randi()
		link.send(move)
	else:
		move.type = "ask"
		link.send(move)
		move = await _take(["move"])
	grid.dice.reseed(move.seed)
	await opponent.perform(ship, action, target)


# Our player ends their turn ("end"), or gives up ("concede")
func tell(type: String) -> void:
	link.send({"type": type, "sum": checksum()})


func get_move() -> void:
	# Deferred: Root only starts waiting for made_move once this returns
	_play.call_deferred()


func _play() -> void:
	var move := await _take(["ask" if hosting else "move", "end", "concede"])
	if move.sum != checksum():
		push_error("Out of sync with the other game")
	match move.type:
		"end":
			end_turn()
		"concede":
			# Emits made_move itself
			concede()
			return
		_:
			var ship: Ship = ships[move.ship] if move.ship in range(ships.size()) else null
			if hosting:
				if not can_perform(ship, move.action, move.target):
					push_error("They asked for a move they can't make")
					return
				move.type = "move"
				move.seed = randi()
				link.send(move)
			grid.dice.reseed(move.seed)
			await perform(ship, move.action, move.target)
	made_move.emit()


# The next message, which should be one of `types`, once it's arrived
func _take(types: Array[String]) -> Dictionary:
	while _inbox.is_empty():
		await arrived
	var message: Dictionary = _inbox.pop_front()
	if not message.get("type") in types:
		push_error("Expected %s from the other game, not %s" % [types, message.get("type")])
	return message


# The game as both sides should have it: fleets, the board's history and mines
func checksum() -> int:
	var state := []
	var both: Array[Player] = [self, opponent]
	if player_num == 1:
		both.reverse()
	for player in both:
		for ship in player.ships:
			var ship_state := SaveGame.ship_state(ship)
			# How it's shown, which differs from one screen to the other
			ship_state.erase("shown")
			ship_state.erase("turrets")
			state.append(ship_state)
	for x in Grid.COLUMNS:
		for y in Grid.ROWS:
			var tile := grid.tile(Vector2i(x, y))
			state.append([tile.history, tile.is_mined])
	return hash(state)
