extends PanelContainer
# The rules in brief, from the title screen. Each ship's own details are in
# ship selection.


func _on_back_pressed() -> void:
	queue_free()
