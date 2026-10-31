extends Node2D

const HOW_TO_PLAY_SCENE := preload("res://gui/how_to_play.tscn")
const SETTINGS_SCENE := preload("res://gui/settings.tscn")


func _ready() -> void:
	# Once per run, as the game starts
	if Settings.config == null:
		Settings.load_settings()


func _on_Hotseat_pressed() -> void:
	Root.title_music_at = $Music.get_playback_position()
	get_tree().change_scene_to_file("res://root.tscn")


func _on_how_to_play_pressed() -> void:
	$TextureRect.add_child(HOW_TO_PLAY_SCENE.instantiate())


func _on_settings_pressed() -> void:
	$TextureRect.add_child(SETTINGS_SCENE.instantiate())


func _on_Exit_pressed() -> void:
	get_tree().quit()
