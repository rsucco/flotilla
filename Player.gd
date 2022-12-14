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
	# Don't make any more moves if the opponent is defeated
	if len(get_parent().players[abs(player_num - 1)].ships) < 1:
		return false
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

# Receive a shot at a given hex, return null for a miss or the ship that was hit for a hit
func receive_fire(x, y, from_ship):
	var ship_at_hex = get_ship_at_hex(x, y)
	if ship_at_hex != null:
		# Cruiser missile defense has a 50% chance of intercepting incoming fire from
		# missile-based weapons (cruisers, destroyers, aircraft carriers) within 2 hexes
		var hit_countered = false
		if from_ship.ship_type in ['destroyer', 'cruiser', 'carrier']:
			for hex in get_parent().grid.get_all_hex_neighbors(x, y, 2):
				var potential_cruiser = get_ship_at_hex(hex[0], hex[1])
				if potential_cruiser != null and potential_cruiser.ship_type == 'cruiser':
					randomize()
					if rand_range(0, 1) > 0.5:
						hit_countered = true
						ship_at_hex = null
						print('passive - missile defense')
					break
		if !hit_countered:
			ship_at_hex.hit([x, y], from_ship)
	return ship_at_hex
