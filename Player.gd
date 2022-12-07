extends Control

class_name Player

signal ships_selected
signal ships_placed
signal made_move
var player_num
var ships = []
var selected_ship = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(num):
	player_num = num

# Check whether the player has moves remaining
func has_moves():
	var remaining = false
	for ship in ships:
		print(ship.ap)
		if ship.ap > 0:
			remaining = true
	print(remaining)
	return remaining

# Start a new turn
func new_turn():
	for ship in self.ships:
		ship.new_turn()

func hide_ships():
	pass

func get_ship_at_hex(x, y):
	for ship in ships:
		var occupied_hexes = ship.get_occupied_hexes()
		if occupied_hexes != null and [x, y] in occupied_hexes:
			return ship
	return null
