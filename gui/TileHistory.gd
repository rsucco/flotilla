extends PanelContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func show_history(hex):
	var new_position = get_parent().grid.get_hex_center(hex[0], hex[1]) + Vector2(40, -60)
	if new_position[0] + rect_size[0] > 800:
		new_position -= Vector2(200, 0)
	rect_position = new_position
	var hex_events = get_parent().grid.grid[hex[0]][hex[1]].history.duplicate()
	if len(hex_events) == 0:
		self.visible = false
		return
	hex_events.invert()
	get_node('VBoxContainer/TileHistory').text = ''
	for hex_event in hex_events:
		get_node('VBoxContainer/TileHistory').text += 'Turn ' + str(hex_event[0]) + \
			': ' + hex_event[1] + "\n"

func show():
	get_parent().move_child(self, len(get_parent().get_children()))
	self.modulate = Color.transparent
	self.visible = true
	var tween = Tween.new()
	tween.interpolate_property(self, 'modulate', Color.transparent, Color(1.0, 1.0, 1.0, 0.85), 0.3)
	add_child(tween)
	tween.start()
