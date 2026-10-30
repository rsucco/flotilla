class_name TileHistory
extends PanelContainer

@onready var root: Root = get_parent()
@onready var label: Label = $VBoxContainer/TileHistory


func show_history(hex: Vector2i) -> void:
	var new_position := root.grid.get_hex_center(hex) + Vector2(40, -60)
	if new_position.x + size.x > 800:
		new_position.x -= 200
	position = new_position
	var events := root.grid.tile(hex).history.duplicate()
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
