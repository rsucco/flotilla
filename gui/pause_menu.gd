class_name PauseMenu
extends CanvasLayer
# Esc menu. Pauses the game and covers the board, so the other hot-seat player
# can't see your fleet while it's open.

signal replay_requested

# Set once both fleets are placed; there's nothing to replay before that
var can_replay := false:
	set(value):
		can_replay = value
		replay.disabled = not value
var pending: Callable

@onready var main: Control = $Panel/Main
@onready var confirm: Control = $Panel/Confirm
@onready var replay: Button = $Panel/Main/Replay


func _ready() -> void:
	# Closing the tab is the way to quit on Web
	$Panel/Main/Quit.visible = not OS.has_feature("web")
	replay.disabled = not can_replay


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


func open() -> void:
	main.visible = true
	confirm.visible = false
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


# Asks before running something that throws the current game away
func ask(action: Callable) -> void:
	pending = action
	main.visible = false
	confirm.visible = true


func _on_resume_pressed() -> void:
	close()


func _on_new_game_pressed() -> void:
	ask(get_tree().reload_current_scene)


func _on_replay_pressed() -> void:
	ask(func() -> void: replay_requested.emit())


func _on_title_pressed() -> void:
	ask(get_tree().change_scene_to_file.bind("res://title_screen.tscn"))


func _on_quit_pressed() -> void:
	ask(get_tree().quit)


func _on_yes_pressed() -> void:
	# The pause would otherwise carry over into the next scene
	get_tree().paused = false
	pending.call()


func _on_no_pressed() -> void:
	main.visible = true
	confirm.visible = false
