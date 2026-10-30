class_name TileHistory
extends PanelContainer

@onready var root: Root = get_parent()
@onready var label: Label = $VBoxContainer/TileHistory


# What `viewer` may see of a hex's history: mines the opponent laid on the
# viewer's side stay hidden
func events_for(hex: Vector2i, viewer: int) -> Array:
	var events: Array = root.grid.tile(hex).history.duplicate()
	if root.grid.side_of(hex) == viewer:
		events = events.filter(func(event: Array) -> bool: return event[1] != "Mine laid")
	return events


func show_history(hex: Vector2i, viewer: int) -> void:
	var center := root.grid.get_hex_center(hex)
	var new_position := center + Vector2(40, -60)
	# Flip to the hex's left if it would run off the screen
	if new_position.x + size.x > get_viewport_rect().size.x:
		new_position.x = center.x - 40 - size.x
	position = new_position
	var events := events_for(hex, viewer)
	if events.is_empty():
		visible = false
		return
	events.reverse()
	label.text = ""
	for event: Array in events:
		label.text += "Turn " + str(event[0]) + ": " + event[1] + "\n"


func fade_in() -> void:
	# Draw on top of everything else
	root.move_child(self, -1)
	modulate = Color.TRANSPARENT
	visible = true
	create_tween().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.85), 0.3)
