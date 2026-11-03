class_name HexCursor
extends Node
# The keyboard and controller's stand-in for the mouse over the board: the
# arrow keys or left stick step it a hex at a time, and each step sends the
# mouse motion a real mouse would, so hovering, aiming and placing work
# unchanged. Held, it steps again after a moment, then faster. It leaves the
# arrows to any dialog with focus. The d-pad moves it too, except while RT is
# held: then the d-pad steers the ship.

const FIRST_REPEAT := 0.3
const REPEAT := 0.08
const HELM: Array[String] = ["action_forward", "action_reverse", "action_port", "action_starboard"]

# Set by Root once the board exists
var grid: Grid
var hex := Vector2i(7, 7)
var _wait := 0.0
var _held := false


static func steering() -> bool:
	return Input.is_action_pressed("action_steer")


# Whether `event` presses `action`; the d-pad only steers while RT is held
static func presses(event: InputEvent, action: String) -> bool:
	if not event.is_action_pressed(action, false, true):
		return false
	return not (action in HELM and event is InputEventJoypadButton) or steering()


# Carries on from wherever the real mouse last was
func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse != null and grid != null:
		var at := grid.get_hex_from_coords(mouse.position)
		if at != Grid.OFF_GRID:
			hex = at


func _process(delta: float) -> void:
	var dir := Input.get_vector("cursor_left", "cursor_right", "cursor_up", "cursor_down")
	if grid == null or get_viewport().gui_get_focus_owner() != null or steering():
		dir = Vector2.ZERO
	steer(dir, delta)


# Steps along `dir` (the stick or arrow keys), held for another `delta` seconds
func steer(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		_held = false
		return
	_wait -= delta
	if _held and _wait > 0.0:
		return
	_wait = REPEAT if _held else FIRST_REPEAT
	_held = true
	var step := Vector2i(int(signf(dir.x)), 0)
	if absf(dir.y) > absf(dir.x):
		step = Vector2i(0, int(signf(dir.y)))
	move_to(hex + step)


# Points at `to` (kept on the board), as the mouse would
func move_to(to: Vector2i) -> void:
	hex = to.clamp(Vector2i.ZERO, Vector2i(Grid.COLUMNS - 1, Grid.ROWS - 1))
	var event := InputEventMouseMotion.new()
	event.position = grid.get_hex_center(hex)
	event.global_position = event.position
	get_viewport().push_input(event, true)
