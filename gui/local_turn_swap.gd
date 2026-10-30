extends PanelContainer

# Emitted with whether the player wants to watch the opponent's turn replay
signal swap_done(watch_replay: bool)

@onready var watch: CheckBox = $VBoxContainer/WatchReplay


func offer_replay(available: bool, default: bool) -> void:
	watch.visible = available
	watch.button_pressed = default


func _on_OK_pressed() -> void:
	swap_done.emit(watch.button_pressed)
	queue_free()
