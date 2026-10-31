class_name LocalPlayer
extends Player

# The ship whose info the GUI should show (null clears it)
signal ship_shown(ship: Ship)
# Button name -> whether it can be pressed
signal buttons_changed(enabled: Dictionary)

const TILE_HIST_HOVER_TIME := 0.5
# Ships with no AP left; opaque, since translucent means revealed
const DONE_TINT := Color(0.55, 0.55, 0.55)
const ACTION_BUTTONS: Array[String] = [
	"Fire", "Special", "Secondary", "NextShip", "Forward", "Reverse", "Port", "Starboard"
]
const ATTACK_BUTTONS: Array[String] = ["Fire", "Special", "Secondary", "NextShip", "EndTurn"]

var aiming := {"fire": false, "special": false, "secondary": false, "recon": false, "unrep": false}
var ships_with_moves: Array[Ship] = []
var targeting_hex_range := -1
var current_on_hex := Grid.OFF_GRID
var on_hex_time := 0.0
var animation_playing := false
# Only the player whose move it is responds to the action buttons
var awaiting_move := false
# From the start of our turn (after any replay) to its end
var active := false
# Set by Root
var tile_history: TileHistory
# Whether to watch the opponent's turn replay at the next swap
var watch_replay := true


func _init(num: int) -> void:
	super(num)


func _unhandled_input(event: InputEvent) -> void:
	# Only pay attention to the mouse, and only on our turn (after any replay)
	if not active or not (event is InputEventMouse):
		return
	var on_hex := grid.get_hex_from_coords(event.position)
	var side := grid.side_of(on_hex)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if side == player_num:
				var ship := get_ship_at_hex(on_hex)
				if aiming["unrep"]:
					# UNREP targets an adjacent friendly ship instead of selecting it
					if ship in (selected_ship as SupplyTender).adjacent_ships():
						_special(on_hex)
				elif ship != null and not animation_playing:
					_select_ship(ship)
			elif side == 1 - player_num:
				# If aiming a shot or ability, use it
				if aiming["fire"]:
					_fire(on_hex)
				elif aiming["special"]:
					_special(on_hex)
				elif aiming["secondary"]:
					_secondary(on_hex)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_select_ship(null)
	elif event is InputEventMouseMotion:
		# Either side: ours shows what the opponent has fired at us
		if side != -1:
			# Restart the history popup timer when moving to a new hex
			if on_hex != current_on_hex:
				current_on_hex = on_hex
				if on_hex_time < TILE_HIST_HOVER_TIME:
					on_hex_time = 0
		else:
			current_on_hex = Grid.OFF_GRID
			tile_history.visible = false


func _process(delta: float) -> void:
	if current_on_hex != Grid.OFF_GRID:
		on_hex_time += delta
	else:
		on_hex_time = 0
	# Show the history popup after hovering over the same hex for a moment
	if on_hex_time > TILE_HIST_HOVER_TIME and active and current_on_hex != Grid.OFF_GRID:
		tile_history.show_history(current_on_hex, player_num)
		# show_history() hides the popup for hexes with nothing to show
		if (
			not tile_history.visible
			and not tile_history.events_for(current_on_hex, player_num).is_empty()
		):
			tile_history.fade_in()


# A GUI button (by name) was pressed
func press(action: String) -> void:
	if not awaiting_move:
		return
	match action:
		"Fire":
			_aim_fire()
		"Special":
			_aim_special()
		"Secondary":
			_aim_secondary()
		"NextShip":
			_next_ship()
		"EndTurn":
			_end_turn()
		"Forward":
			_forward()
		"Port":
			_port()
		"Starboard":
			_starboard()
		"Reverse":
			_reverse()


func _set_aiming(mode: String, hex_range: int) -> void:
	for key: String in aiming:
		aiming[key] = key == mode
	targeting_hex_range = hex_range


func _aim_fire() -> void:
	if selected_ship != null and selected_ship.can_fire():
		_set_aiming("fire", 0)


func _aim_special() -> void:
	if selected_ship == null or not selected_ship.can_special():
		return
	# UNREP aims at an adjacent ship on our own grid
	if selected_ship.ship_type == "supply_tender":
		_set_aiming("unrep", 0)
		return
	_set_aiming("special", selected_ship.special.aoe)
	# Recon Flight targets a whole row
	aiming["recon"] = selected_ship.special.name == "Recon Flight"


func _aim_secondary() -> void:
	if selected_ship != null and selected_ship.can_secondary():
		_set_aiming("secondary", selected_ship.secondary.aoe)


func _set_attack_buttons_disabled(disabled: bool) -> void:
	var enabled := {}
	for button in ATTACK_BUTTONS:
		enabled[button] = not disabled
	buttons_changed.emit(enabled)


func _fire(hex: Vector2i) -> void:
	if selected_ship != null and selected_ship.can_fire(hex):
		_attack("fire", hex)


func _special(hex: Vector2i) -> void:
	if selected_ship != null and selected_ship.can_special():
		_attack("special", hex)


func _secondary(hex: Vector2i) -> void:
	if selected_ship != null and selected_ship.can_secondary():
		_attack("secondary", hex)


# Plays the attack's animation, then has the opponent resolve it. Recorded
# for the opponent's turn replay.
func _attack(kind: String, hex: Vector2i) -> void:
	var ship := selected_ship
	animation_playing = true
	_set_attack_buttons_disabled(true)
	ship.intercepted = opponent.roll_intercept(ship, kind, hex)
	attack_started.emit(ship, kind, hex)
	match kind:
		"fire":
			await ship.fire(hex)
		"special":
			await ship.use_special(hex)
		"secondary":
			await ship.use_secondary(hex)
	_set_attack_buttons_disabled(false)
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
	_finish_action()


func _finish_action() -> void:
	if selected_ship != null:
		_update_buttons(selected_ship)
		ship_shown.emit(selected_ship)
	animation_playing = false
	made_move.emit()


# Selects the next ship with AP left, coming back around to this one later
func _next_ship() -> void:
	if selected_ship == ships_with_moves[0]:
		ships_with_moves.push_back(ships_with_moves.pop_front())
	_select_ship(ships_with_moves[0])


# Ends every ship's turn
func _end_turn() -> void:
	for ship in ships:
		ship.ap = 0
	made_move.emit()


func _forward() -> void:
	if selected_ship != null and selected_ship.can_move():
		selected_ship.forward()
		_finish_action()


func _reverse() -> void:
	if selected_ship != null and selected_ship.can_move(true):
		selected_ship.reverse()
		_finish_action()


func _port() -> void:
	if selected_ship != null and selected_ship.can_rotate(-60):
		selected_ship.port()
		_finish_action()


func _starboard() -> void:
	if selected_ship != null and selected_ship.can_rotate(60):
		selected_ship.starboard()
		_finish_action()


func get_hover_hexes(hex: Vector2i) -> Array[Vector2i]:
	var side := grid.side_of(hex)
	# On our half, don't bother with area of effect
	if side == player_num:
		return [hex]
	# No-man's-land or off the board
	if side == -1 or targeting_hex_range == -1:
		return []
	# Recon Flight covers the entire row
	if aiming["recon"]:
		var row: Array[Vector2i] = []
		for x: int in grid.columns_of(side):
			row.append(Vector2i(x, hex.y))
		return row
	var hexes := grid.get_all_hex_neighbors(hex, targeting_hex_range)
	hexes.append(hex)
	return hexes


func _select_ship(ship: Ship) -> void:
	_set_aiming("", -1)
	if ship != null:
		# Move the ship to the front of the line if it still has moves
		if not ships_with_moves.is_empty() and ships_with_moves[0] != ship and ship.ap > 0:
			ships_with_moves.erase(ship)
			ships_with_moves.push_front(ship)
		_update_buttons(ship)
	else:
		var enabled := {}
		for button in ACTION_BUTTONS:
			enabled[button] = false
		buttons_changed.emit(enabled)
	selected_ship = ship
	ship_shown.emit(ship)


func _update_buttons(ship: Ship) -> void:
	(
		buttons_changed
		. emit(
			{
				"Forward": ship.can_move(),
				"Reverse": ship.can_move(true),
				"Port": ship.can_rotate(-60),
				"Starboard": ship.can_rotate(60),
				"Fire": ship.can_fire(),
				"Special": ship.can_special(),
				"Secondary": ship.can_secondary(),
				"NextShip": true,
				"EndTurn": true,
			}
		)
	)


# `counts` is keyed by PascalCase ship type (ship selection node names)
func place_ships(counts: Dictionary) -> void:
	for ship_type: String in counts:
		for _i in counts[ship_type]:
			var ship: Ship = (
				load("res://ships/" + ship_type.to_snake_case() + ".tscn").instantiate()
			)
			adopt(ship)
			ship.place()
			await ship.placed
			ships.append(ship)
	fleet_size = ships.size()
	# Hide ships from the next player
	for ship in ships:
		ship.visible = false


func get_ship_selection() -> Dictionary:
	var dialog: Control = preload("res://gui/ship_selection.tscn").instantiate()
	dialog.get_node("VBoxContainer/Label").text = (
		"Player " + str(player_num + 1) + ", choose your ships:"
	)
	add_child(dialog)
	dialog.set_island_tiles(grid.get_num_island_tiles(player_num))
	return await dialog.confirmed


func new_turn() -> void:
	super()
	for ship in ships:
		ship.visible = true
	ships_with_moves = ships.duplicate()
	_select_ship(ships_with_moves[0])
	on_hex_time = 0
	active = true


# Testing cheat (Root's C key): every ability of ours ready now
func ready_abilities() -> void:
	for ship in ships:
		ship.special.cooldown_current = 0
		ship.secondary.cooldown_current = 0
	if selected_ship != null and not animation_playing:
		_update_buttons(selected_ship)
		ship_shown.emit(selected_ship)


func finish_turn() -> void:
	super()
	_select_ship(null)
	active = false
	for ship in ships:
		ship.visible = false
	# Its history is about the opponent's fleet
	tile_history.visible = false
	buttons_changed.emit({"EndTurn": false})


func get_move() -> void:
	_set_aiming("", -1)
	# Drop ships that are out of moves or have been sunk
	ships_with_moves = ships_with_moves.filter(
		func(s: Ship) -> bool: return ships.has(s) and s.ap > 0
	)
	for ship in ships:
		ship.modulate = Color.WHITE if ship.ap > 0 else DONE_TINT
	_select_ship(ships_with_moves[0])
	awaiting_move = true


func disconnect_buttons() -> void:
	awaiting_move = false
