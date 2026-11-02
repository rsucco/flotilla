class_name LocalPlayer
extends Player

# The ship whose info the GUI should show (null clears it)
signal ship_shown(ship: Ship)
# Button name -> whether it can be pressed
signal buttons_changed(enabled: Dictionary)
# How far through End Turn's hold, 0 to 1 (0 once let go or done)
signal end_turn_holding(fraction: float)

const TILE_HIST_HOVER_TIME := 0.5
# Ships with no AP left; opaque, since translucent means revealed
const DONE_TINT := Color(0.7, 0.7, 0.7)
const ACTION_BUTTONS: Array[String] = [
	"Fire", "Special", "Secondary", "NextShip", "Forward", "Reverse", "Port", "Starboard"
]
const ATTACK_BUTTONS: Array[String] = ["Fire", "Special", "Secondary", "NextShip", "EndTurn"]
# Input actions (keyboard and controller) -> the button each one presses
const SHORTCUTS := {
	"action_fire": "Fire",
	"action_special": "Special",
	"action_secondary": "Secondary",
	"action_forward": "Forward",
	"action_reverse": "Reverse",
	"action_port": "Port",
	"action_starboard": "Starboard",
	"action_next_ship": "NextShip",
}
# How long End Turn must be held, so it isn't pressed by accident
const END_TURN_HOLD := 1.0

var aiming := {"fire": false, "special": false, "secondary": false, "recon": false, "unrep": false}
var ships_with_moves: Array[Ship] = []
var targeting_hex_range := -1
var current_on_hex := Grid.OFF_GRID
var on_hex_time := 0.0
# Only the player whose move it is responds to the action buttons
var awaiting_move := false
# Set by Root
var tile_history: TileHistory
# Sharing the screen with another local player, so our fleet hides between turns
var hot_seat := true
var pips: APPips
# Which buttons can be pressed, as last sent to the GUI; shortcuts follow them
var enabled := {}
var end_turn_held := 0.0
# The hex under the last mouse event, from the mouse or the HexCursor
var pointer_hex := Grid.OFF_GRID


func _init(num: int) -> void:
	super(num)


func _ready() -> void:
	buttons_changed.connect(func(now: Dictionary) -> void: enabled.merge(now, true))
	pips = APPips.new()
	pips.ships = ships
	# Above the ships
	pips.z_index = 2
	pips.visible = false
	add_child(pips)


func _unhandled_input(event: InputEvent) -> void:
	# Only on our turn (after any replay)
	if not active:
		return
	if not (event is InputEventMouse):
		_shortcut(event)
		return
	var on_hex := grid.get_hex_from_coords(event.position)
	pointer_hex = on_hex
	var side := grid.side_of(on_hex)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(on_hex)
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


# What a click on `on_hex` does: selects our ship there, or uses the shot or
# ability being aimed
func _click(on_hex: Vector2i) -> void:
	var side := grid.side_of(on_hex)
	if side == player_num:
		var ship := get_ship_at_hex(on_hex)
		if aiming["unrep"]:
			# UNREP targets an adjacent friendly ship instead of selecting it
			_act("special", on_hex)
		elif ship != null and not animation_playing:
			_select_ship(ship)
	elif side == 1 - player_num:
		# If aiming a shot or ability, use it
		for kind in ["fire", "special", "secondary"]:
			if aiming[kind]:
				_act(kind, on_hex)


# Keyboard and controller: each shortcut does what its button would, when its
# button could be pressed. Exact matches, so Shift+Tab isn't also Tab.
func _shortcut(event: InputEvent) -> void:
	# Enter and Space click at the cursor. A does too when that means
	# something there (confirming an attack, picking our ship); else it's Fire.
	var on_ours := grid.side_of(pointer_hex) == player_num and get_ship_at_hex(pointer_hex) != null
	if (
		event.is_action_pressed("action_confirm")
		or (
			event.is_action_pressed("action_fire")
			and (aiming.values().has(true) or on_ours)
			and (event is InputEventJoypadButton)
		)
	):
		get_viewport().set_input_as_handled()
		_click(pointer_hex)
		return
	for action: String in SHORTCUTS:
		if event.is_action_pressed(action, false, true) and enabled.get(SHORTCUTS[action], false):
			get_viewport().set_input_as_handled()
			press(SHORTCUTS[action])
			return
	if event.is_action_pressed("action_previous_ship", false, true) and enabled.get("NextShip"):
		get_viewport().set_input_as_handled()
		_previous_ship()
	elif event.is_action_pressed("action_cancel"):
		get_viewport().set_input_as_handled()
		# Stop aiming first, then let go of the ship
		if aiming.values().has(true):
			_set_aiming("", -1)
		else:
			_select_ship(null)


func _process(delta: float) -> void:
	# End Turn by holding its shortcut down; once per hold, even across turns
	var was := end_turn_held
	if not Input.is_action_pressed("action_end_turn"):
		end_turn_held = 0.0
	elif active and awaiting_move and enabled.get("EndTurn", false):
		end_turn_held += delta
		if end_turn_held >= END_TURN_HOLD:
			end_turn_held = -INF
			press("EndTurn")
	if end_turn_held != was:
		end_turn_holding.emit(clampf(end_turn_held / END_TURN_HOLD, 0.0, 1.0))
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
			end_turn()
			_made_move()
		"Forward", "Reverse", "Port", "Starboard":
			_act(action.to_lower())


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


# The selected ship makes a move, if it may
func _act(action: String, target: Vector2i = Grid.OFF_GRID) -> void:
	if selected_ship == null or not can_perform(selected_ship, action, target):
		return
	var attack := action in ["fire", "special", "secondary"]
	if attack:
		_set_attack_buttons_disabled(true)
	await perform(selected_ship, action, target)
	if attack:
		_set_attack_buttons_disabled(false)
	if selected_ship != null:
		_update_buttons(selected_ship)
		ship_shown.emit(selected_ship)
	_made_move()


# Ignores the buttons until Root asks for our next move
func _made_move() -> void:
	awaiting_move = false
	made_move.emit()


# Selects the next ship with AP left, coming back around to this one later
func _next_ship() -> void:
	if selected_ship == ships_with_moves[0]:
		ships_with_moves.push_back(ships_with_moves.pop_front())
	_select_ship(ships_with_moves[0])


# The other way round: the last ship with AP left
func _previous_ship() -> void:
	ships_with_moves.push_front(ships_with_moves.pop_back())
	_select_ship(ships_with_moves[0])


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


func place_ships(counts: Dictionary) -> void:
	await super(counts)
	# Hide ships from the next player
	for ship in ships:
		ship.visible = not hot_seat


# Follows the mouse until clicked into place
func _place(ship: Ship) -> void:
	ship.place()
	await ship.placed


func get_ship_selection() -> Dictionary:
	var dialog: Control = preload("res://gui/ship_selection.tscn").instantiate()
	dialog.get_node("VBoxContainer/Label").text = (
		"Player " + str(player_num + 1) + ", choose your navy and ships:"
	)
	dialog.taken = opponent.navy
	add_child(dialog)
	dialog.set_island_tiles(grid.get_num_island_tiles(player_num))
	var counts: Dictionary = await dialog.confirmed
	navy = dialog.navy
	return counts


func new_turn() -> void:
	super()
	_take_the_helm()


# Carries on with a turn from a saved game, with the AP it was saved with
func resume_turn() -> void:
	for revealed in temp_revealed_ships:
		show_revealed(revealed)
	_take_the_helm()


# Shows our fleet and hands us the controls
func _take_the_helm() -> void:
	for ship in ships:
		ship.visible = true
	ships_with_moves = ships.filter(func(s: Ship) -> bool: return s.ap > 0)
	_select_ship(ships_with_moves[0])
	on_hex_time = 0
	active = true
	pips.visible = true


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
	pips.visible = false
	for ship in ships:
		ship.visible = not hot_seat
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
