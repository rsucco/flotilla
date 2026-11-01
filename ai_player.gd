class_name AIPlayer
extends Player
# The computer opponent. For now it plays at random: a stand-in while the
# single-player game is built around it (the real one is fl-aqz.5).

# A pause before each move, so its turn can be followed
const THINK_TIME := 0.5
const SELECTION := preload("res://gui/ship_selection.gd")
const DIRECTIONS: Array[int] = [0, 60, 120, 180, 240, 300]
const MOVES: Array[String] = ["forward", "reverse", "port", "starboard"]
const ATTACKS: Array[String] = ["fire", "special", "secondary"]


# One of each ship, as the selection dialog's Classic button picks
func get_ship_selection() -> Dictionary:
	var counts := {}
	for ship_type: String in SELECTION.POINT_VALUES:
		counts[ship_type] = 1
	return counts


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
	await get_tree().create_timer(THINK_TIME, false).timeout
	var attacks := _legal(ATTACKS)
	var moves := _legal(MOVES)
	# Rather attack than wander
	var choices := attacks if not attacks.is_empty() and randf() < 0.7 else attacks + moves
	if choices.is_empty():
		# Ships with AP but nothing they can do
		end_turn()
	else:
		var move: Array = choices.pick_random()
		await perform(move[0], move[1], move[2])
	made_move.emit()


# [ship, action, target] for each legal move among `actions`, with a random
# target for attacks
func _legal(actions: Array[String]) -> Array[Array]:
	var legal: Array[Array] = []
	for ship in ships:
		for action in actions:
			var target := _random_target(ship, action)
			if can_perform(ship, action, target):
				legal.append([ship, action, target])
	return legal


func _random_target(ship: Ship, action: String) -> Vector2i:
	if action in MOVES:
		return Grid.OFF_GRID
	# UNREP heals one of ours
	if action == "special" and ship is SupplyTender:
		var near := (ship as SupplyTender).adjacent_ships()
		return Grid.OFF_GRID if near.is_empty() else near.pick_random().hex
	var columns := grid.columns_of(opponent.player_num)
	return Vector2i(columns.pick_random(), randi_range(0, Grid.ROWS - 1))
