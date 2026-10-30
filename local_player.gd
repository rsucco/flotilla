class_name LocalPlayer
extends Player

const TILE_HIST_HOVER_TIME := 0.5
const ATTACK_BUTTONS: Array[String] = ["Fire", "Special", "Secondary", "NextShip", "EndTurn"]

var aiming := {"fire": false, "special": false, "secondary": false, "recon": false, "unrep": false}
var ships_with_moves: Array[Ship] = []
var targeting_hex_range := -1
var current_on_hex := Grid.OFF_GRID
var on_hex_time := 0.0
var animation_playing := false
# Only the player whose move it is responds to the action buttons
var awaiting_move := false
var tile_history: TileHistory
# Whether to watch the opponent's turn replay at the next swap
var watch_replay := true


func _init(num: int) -> void:
	super(num)


func _ready() -> void:
	super()
	tile_history = root.get_node("TileHistory")
	for button: Button in get_tree().get_nodes_in_group("action_buttons"):
		button.pressed.connect(_button_pressed.bind(button))
	# Not an action button: it works with no ship selected
	var end_turn: Button = root.gui.find_child("EndTurn")
	end_turn.pressed.connect(_button_pressed.bind(end_turn))


func _unhandled_input(event: InputEvent) -> void:
	# Only pay attention to the mouse, and only on our turn (after any replay)
	if root.player_up != player_num or root.swapping or not (event is InputEventMouse):
		return
	var on_hex := root.grid.get_hex_from_coords(event.position)
	var side := root.grid.side_of(on_hex)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if side == player_num:
				var ship := get_ship_at_hex(on_hex)
				if aiming["unrep"]:
					# UNREP targets an adjacent friendly ship instead of selecting it
					if ship in (selected_ship as SupplyTender).adjacent_ships():
						_special(on_hex)
				elif ship != null and root.current_turn != 0 and not animation_playing:
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
	elif event is InputEventMouseMotion and root.current_turn > 0:
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
	if (
		on_hex_time > TILE_HIST_HOVER_TIME
		and root.current_turn > 0
		and root.player_up == player_num
		and current_on_hex != Grid.OFF_GRID
	):
		tile_history.show_history(current_on_hex, player_num)
		# show_history() hides the popup for hexes with nothing to show
		if (
			not tile_history.visible
			and not tile_history.events_for(current_on_hex, player_num).is_empty()
		):
			tile_history.fade_in()


func _button_pressed(button: Button) -> void:
	if not awaiting_move:
		return
	match button.name:
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
	for button in ATTACK_BUTTONS:
		root.gui.disable_button(button, disabled)


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
	root.turn_replay.begin(ship, kind, hex)
	match kind:
		"fire":
			await ship.fire(hex)
		"special":
			await ship.use_special(hex)
		"secondary":
			await ship.use_secondary(hex)
	_set_attack_buttons_disabled(false)
	root.turn_replay.land()
	if kind == "fire":
		opponent().receive_fire(hex, ship)
	else:
		opponent().receive_special(hex, ship, kind == "secondary")
	root.turn_replay.end()
	_finish_action()


func _finish_action() -> void:
	if selected_ship != null:
		_update_buttons(selected_ship)
		root.gui.update_ship_info(selected_ship)
	animation_playing = false
	made_move.emit()


# Ends the selected ship's turn
func _next_ship() -> void:
	if selected_ship != null:
		selected_ship.ap = 0
		made_move.emit()


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
	var side := root.grid.side_of(hex)
	# On our half, don't bother with area of effect
	if side == player_num:
		return [hex]
	# No-man's-land or off the board
	if side == -1 or targeting_hex_range == -1:
		return []
	# Recon Flight covers the entire row
	if aiming["recon"]:
		var row: Array[Vector2i] = []
		for x: int in root.grid.columns_of(side):
			row.append(Vector2i(x, hex.y))
		return row
	var hexes := root.grid.get_all_hex_neighbors(hex, targeting_hex_range)
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
		for button: Button in get_tree().get_nodes_in_group("action_buttons"):
			button.disabled = true
	selected_ship = ship
	root.gui.update_ship_info(ship)


func _update_buttons(ship: Ship) -> void:
	root.gui.disable_button("Forward", not ship.can_move())
	root.gui.disable_button("Reverse", not ship.can_move(true))
	root.gui.disable_button("Port", not ship.can_rotate(-60))
	root.gui.disable_button("Starboard", not ship.can_rotate(60))
	root.gui.disable_button("Fire", not ship.can_fire())
	root.gui.disable_button("Special", not ship.can_special())
	root.gui.disable_button("Secondary", not ship.can_secondary())
	root.gui.disable_button("NextShip", false)
	root.gui.disable_button("EndTurn", false)


# `counts` is keyed by PascalCase ship type (ship selection node names)
func place_ships(counts: Dictionary) -> void:
	for ship_type: String in counts:
		for _i in counts[ship_type]:
			var ship: Ship = (
				load("res://ships/" + ship_type.to_snake_case() + ".tscn").instantiate()
			)
			add_child(ship)
			ship.place()
			await ship.placed
			ships.append(ship)
	# Hide ships from the next player
	for ship in ships:
		ship.visible = false


func get_ship_selection() -> Dictionary:
	var dialog: Control = preload("res://gui/ship_selection.tscn").instantiate()
	dialog.get_node("VBoxContainer/Label").text = (
		"Player " + str(player_num + 1) + ", choose your ships:"
	)
	add_child(dialog)
	dialog.set_island_tiles(root.grid.get_num_island_tiles(player_num))
	return await dialog.confirmed


func new_turn() -> void:
	super()
	for ship in ships:
		ship.visible = true
	ships_with_moves = ships.duplicate()
	_select_ship(ships_with_moves[0])
	on_hex_time = 0


func finish_turn() -> void:
	super()
	for ship in ships:
		ship.visible = false
	# Its history is about the opponent's fleet
	tile_history.visible = false
	root.gui.disable_button("EndTurn")


func get_move() -> void:
	_set_aiming("", -1)
	# Drop ships that are out of moves or have been sunk
	ships_with_moves = ships_with_moves.filter(
		func(s: Ship) -> bool: return ships.has(s) and s.ap > 0
	)
	_select_ship(ships_with_moves[0])
	awaiting_move = true


func disconnect_buttons() -> void:
	awaiting_move = false
