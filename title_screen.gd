extends Node2D


func _on_Hotseat_pressed() -> void:
	get_tree().change_scene_to_file("res://root.tscn")


func _on_Exit_pressed() -> void:
	get_tree().quit()
