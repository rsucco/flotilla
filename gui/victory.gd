extends PanelContainer


func update_winner(winner: String) -> void:
	$VBoxContainer/Label.text = "Player " + winner + " wins!\n"


func _on_Quit_pressed() -> void:
	get_tree().quit()


func _on_Title_pressed() -> void:
	get_tree().change_scene_to_file("res://title_screen.tscn")


func _on_Rematch_pressed() -> void:
	get_tree().reload_current_scene()
