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
		if ship.ap > 0:
			remaining = true
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

func get_hover_hexes(x, y):
	return [[x, y]]

# Receive a shot at a given hex, return true for a hit and false for a miss
func receive_fire(x, y):
	var ship_at_hex = get_ship_at_hex(x, y)
	if ship_at_hex != null:
		ship_at_hex.hit()
		return true
	else:
		return false
