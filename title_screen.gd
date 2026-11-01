extends Node2D

const HOW_TO_PLAY_SCENE := preload("res://gui/how_to_play.tscn")
const SETTINGS_SCENE := preload("res://gui/settings.tscn")
const LOAD_SCENE := preload("res://gui/load_game.tscn")


func _ready() -> void:
	# Once per run, as the game starts
	if Settings.config == null:
		Settings.load_settings()
		# The window's close button quits cleanly too
		get_tree().auto_accept_quit = false
		get_tree().root.close_requested.connect(Sfx.quit.bind(get_tree()))
	# Carries on with the latest save, autosave included
	var has_saves := SaveGame.latest() != ""
	$TextureRect/PanelContainer/Buttons/Continue.visible = has_saves
	$TextureRect/PanelContainer/Buttons/Load.disabled = not has_saves


func _on_Hotseat_pressed() -> void:
	Root.title_music_at = $Music.get_playback_position()
	get_tree().change_scene_to_file("res://root.tscn")


func _on_continue_pressed() -> void:
	_load(SaveGame.latest())


func _on_load_pressed() -> void:
	var dialog := LOAD_SCENE.instantiate()
	dialog.slot_chosen.connect(_load)
	$TextureRect.add_child(dialog)


func _load(slot: String) -> void:
	Root.loaded = SaveGame.read(slot)
	if Root.loaded.is_empty():
		return
	Root.title_music_at = $Music.get_playback_position()
	get_tree().change_scene_to_file("res://root.tscn")


func _on_how_to_play_pressed() -> void:
	$TextureRect.add_child(HOW_TO_PLAY_SCENE.instantiate())


func _on_settings_pressed() -> void:
	$TextureRect.add_child(SETTINGS_SCENE.instantiate())


func _on_Exit_pressed() -> void:
	Sfx.quit(get_tree())
