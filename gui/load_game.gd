extends Control
# The saved games, autosave first, over the title screen. Empty slots can't be
# picked.

signal slot_chosen(slot: String)


func _ready() -> void:
	for slot in [SaveGame.AUTOSAVE] + SaveGame.SLOTS:
		var button := Button.new()
		button.text = SaveGame.describe(slot)
		button.disabled = SaveGame.read(slot).is_empty()
		button.pressed.connect(func() -> void: slot_chosen.emit(slot))
		%Slots.add_child(button)
	Focus.first(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
