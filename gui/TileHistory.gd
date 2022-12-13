extends PanelContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func show_history(hex):
	var hex_events = get_parent().grid.grid[hex[0]][hex[1]].history.duplicate()
	hex_events.invert()
	get_node('VBoxContainer/TileHistory').text = ''
	for hex_event in hex_events:
		get_node('VBoxContainer/TileHistory').text += 'Turn ' + str(hex_event[0]) + \
			': ' + hex_event[1] + "\n"

func show():
	self.modulate = Color.transparent
	self.visible = true
	var tween = Tween.new()
	tween.interpolate_property(self, 'modulate', Color.transparent, Color(1.0, 1.0, 1.0, 0.85), 0.3)
	add_child(tween)
	tween.start()
