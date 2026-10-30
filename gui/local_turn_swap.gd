extends PanelContainer

signal swap_done


func _on_OK_pressed() -> void:
	swap_done.emit()
	queue_free()
