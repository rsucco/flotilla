class_name PauseMenu
extends CanvasLayer
# Esc menu. Pauses the game and covers the board, so the other hot-seat player
# can't see your fleet while it's open.

signal replay_requested
signal concede_requested

const HOW_TO_PLAY_SCENE := preload("res://gui/how_to_play.tscn")
const SETTINGS_SCENE := preload("res://gui/settings.tscn")

# Set once both fleets are placed; there's nothing to replay before that
var can_replay := false:
	set(value):
		can_replay = value
		replay.disabled = not value
# Set by Root: the player (1 or 2) whose turn it is, who may concede, or 0
# when it's not clear who's at the screen (setup, swaps and replays)
var conceder := 0:
	set(value):
		conceder = value
		concede.disabled = value == 0
		concede.text = "Concede" if value == 0 else "Concede (Player %d)" % value
var pending: Callable

@onready var panel: Control = $Panel
@onready var main: Control = $Panel/Main
@onready var confirm: Control = $Panel/Confirm
@onready var replay: Button = $Panel/Main/Replay
@onready var concede: Button = $Panel/Main/Concede
@onready var question: Label = $Panel/Confirm/Label


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
func ask(action: Callable, text: String = "Abandon this game?") -> void:
	pending = action
	question.text = text
	main.visible = false
	confirm.visible = true


func _on_resume_pressed() -> void:
	close()


func _on_new_game_pressed() -> void:
	ask(get_tree().reload_current_scene)


func _on_replay_pressed() -> void:
	ask(func() -> void: replay_requested.emit())


func _on_how_to_play_pressed() -> void:
	_show_overlay(HOW_TO_PLAY_SCENE)


func _on_settings_pressed() -> void:
	_show_overlay(SETTINGS_SCENE)


# In place of the menu, which comes back when the overlay closes itself
func _show_overlay(scene: PackedScene) -> void:
	var overlay := scene.instantiate()
	panel.visible = false
	overlay.tree_exited.connect(func() -> void: panel.visible = true)
	add_child(overlay)


func _on_concede_pressed() -> void:
	ask(func() -> void: concede_requested.emit(), "Concede the game?")


func _on_title_pressed() -> void:
	ask(get_tree().change_scene_to_file.bind("res://title_screen.tscn"))


func _on_quit_pressed() -> void:
	ask(Sfx.quit.bind(get_tree()))


func _on_yes_pressed() -> void:
	# The pause would otherwise carry over into the next scene
	get_tree().paused = false
	pending.call()


func _on_no_pressed() -> void:
	main.visible = true
	confirm.visible = false
