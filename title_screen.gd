extends Node2D

const HOW_TO_PLAY_SCENE := preload("res://gui/how_to_play.tscn")


func _on_Hotseat_pressed() -> void:
	get_tree().change_scene_to_file("res://root.tscn")


func _on_how_to_play_pressed() -> void:
	$TextureRect.add_child(HOW_TO_PLAY_SCENE.instantiate())


func _on_Exit_pressed() -> void:
	get_tree().quit()
