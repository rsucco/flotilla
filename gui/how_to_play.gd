extends PanelContainer
# The rules in brief, from the title screen or the Esc menu. Each ship's own
# details are in ship selection.

# Pixels per press of up or down
const SCROLL_STEP := 60


func _ready() -> void:
	Focus.first(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	# Up and down have no button to go to, so they scroll the rules
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		var down := event.is_action("ui_down")
		$Margin/VBoxContainer/Scroll.scroll_vertical += SCROLL_STEP if down else -SCROLL_STEP


func _on_back_pressed() -> void:
	queue_free()
