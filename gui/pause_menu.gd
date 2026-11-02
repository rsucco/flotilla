class_name PauseMenu
extends CanvasLayer
# Esc menu. Pauses the game and covers the board, so the other hot-seat player
# can't see your fleet while it's open.

signal replay_requested
signal concede_requested
signal save_requested(slot: String)
signal opened

const HOW_TO_PLAY_SCENE := preload("res://gui/how_to_play.tscn")
const SETTINGS_SCENE := preload("res://gui/settings.tscn")

# Set once both fleets are placed; there's nothing to replay before that
var can_replay := false:
	set(value):
		can_replay = value
		replay.disabled = not value
# Set by Root as the menu opens: only mid-turn, when it's clear who's conceding
var can_concede := false:
	set(value):
		can_concede = value
		concede.disabled = not value
# Set by Root as the menu opens: only mid-turn, with nothing in flight
var can_save := false:
	set(value):
		can_save = value
		save_game.disabled = not value
var pending: Callable
# Where No returns to
var back: Control

@onready var panel: Control = $Panel
@onready var main: Control = $Panel/Main
@onready var confirm: Control = $Panel/Confirm
@onready var replay: Button = $Panel/Main/Replay
@onready var concede: Button = $Panel/Main/Concede
@onready var save_game: Button = $Panel/Main/SaveGame
@onready var saves: Control = $Panel/Saves
@onready var heading: Label = $Panel/Main/Label
@onready var question: Label = $Panel/Confirm/Label


func _ready() -> void:
	# Closing the tab is the way to quit on Web
	$Panel/Main/Quit.visible = not OS.has_feature("web")
	replay.disabled = not can_replay


# Esc or Start opens it; once open, either one or ui_cancel goes back
func _unhandled_input(event: InputEvent) -> void:
	var menu := event.is_action_pressed("action_menu")
	if not (menu or (visible and event.is_action_pressed("ui_cancel"))):
		return
	get_viewport().set_input_as_handled()
	if saves.visible:
		_on_saves_back_pressed()
	elif visible:
		close()
	else:
		open()


func open() -> void:
	heading.text = "Paused"
	main.visible = true
	confirm.visible = false
	saves.visible = false
	visible = true
	get_tree().paused = true
	opened.emit()
	Focus.first(main)


func close() -> void:
	visible = false
	get_tree().paused = false


# Asks before running something that throws the current game away, or from
# the slot list, before overwriting a save
func ask(action: Callable, text: String = "Abandon this game?", from: Control = main) -> void:
	pending = action
	back = from
	question.text = text
	from.visible = false
	confirm.visible = true
	# The safe answer first
	$Panel/Confirm/Buttons/No.grab_focus(true)


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
	overlay.tree_exited.connect(
		func() -> void:
			panel.visible = true
			if is_inside_tree():
				Focus.first(main)
	)
	add_child(overlay)


# Lists the slots, each with what's in it now
func _on_save_game_pressed() -> void:
	var slots := $Panel/Saves/Slots
	for button in slots.get_children():
		button.free()
	for slot in SaveGame.SLOTS:
		var button := Button.new()
		button.text = SaveGame.describe(slot)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		slots.add_child(button)
	main.visible = false
	saves.visible = true
	Focus.first(saves)


func _on_slot_pressed(slot: String) -> void:
	if SaveGame.read(slot).is_empty():
		_save(slot)
	else:
		ask(_save.bind(slot), "Overwrite %s?" % SaveGame.NAMES[slot], saves)


func _save(slot: String) -> void:
	save_requested.emit(slot)
	heading.text = "Saved to " + SaveGame.NAMES[slot]
	_on_saves_back_pressed()


func _on_saves_back_pressed() -> void:
	saves.visible = false
	main.visible = true
	Focus.first(main)


func _on_concede_pressed() -> void:
	ask(func() -> void: concede_requested.emit(), "Concede the game?")


func _on_title_pressed() -> void:
	ask(get_tree().change_scene_to_file.bind("res://title_screen.tscn"))


func _on_quit_pressed() -> void:
	ask(Sfx.quit.bind(get_tree()))


func _on_yes_pressed() -> void:
	if back == saves:
		_on_no_pressed()
	else:
		# The pause would otherwise carry over into the next scene
		get_tree().paused = false
	pending.call()


func _on_no_pressed() -> void:
	back.visible = true
	confirm.visible = false
	Focus.first(back)
