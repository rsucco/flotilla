extends PopupPanel

signal swap_done

func _on_OK_pressed():
	emit_signal('swap_done')
	queue_free()
