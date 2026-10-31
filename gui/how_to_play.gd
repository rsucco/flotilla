extends PanelContainer
# The rules in brief, from the title screen or the Esc menu. Each ship's own
# details are in ship selection.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _on_back_pressed() -> void:
	queue_free()
