extends PopupPanel

signal rematch

func update_winner(winner):
	get_node("VBoxContainer/Label").text = "Player " + winner + " wins!\n"

func _on_Quit_pressed():
	get_tree().quit()

func _on_Title_pressed():
	get_tree().change_scene("res://TitleScreen.tscn")

func _on_Rematch_pressed():
	get_tree().reload_current_scene()
