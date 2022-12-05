extends Control

class_name Player

signal ships_selected
signal ships_placed
var player_num
var ships = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(num):
	player_num = num
