extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_Hotseat_pressed():
	get_tree().change_scene("res://Root.tscn")

func _on_Exit_pressed():
	get_tree().quit()
