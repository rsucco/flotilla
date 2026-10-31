extends Control
# Volumes and fullscreen, over the title screen or the Esc menu. Changes apply
# as they're made and are saved on closing.

@onready var sliders: Dictionary[StringName, HSlider] = {
	&"Master": %Master,
	&"Music": %Music,
	&"Effects": %Effects,
}
@onready var fullscreen: CheckButton = %Fullscreen


func _ready() -> void:
	for bus in sliders:
		sliders[bus].value = Settings.get_volume(bus)
		sliders[bus].value_changed.connect(
			func(value: float) -> void: Settings.set_volume(bus, value)
		)
	# Hear the new level on letting go
	sliders[&"Effects"].drag_ended.connect(func(_changed: bool) -> void: $Sample.play())
	fullscreen.visible = not OS.has_feature("mobile")
	fullscreen.button_pressed = Settings.is_fullscreen()
	fullscreen.toggled.connect(Settings.set_fullscreen)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Settings.save()
	queue_free()
