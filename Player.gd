extends Control

class_name Player

signal ships_selected
signal ships_placed
signal made_move
const intercept_sound = preload('res://audio/ciws.wav')
var player_num
var ships = []
var temp_revealed_ships = []
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
	for revealed_ship in temp_revealed_ships:
		add_child(revealed_ship)
		revealed_ship.visible = true
		revealed_ship.modulate = Color(1.0, 1.0, 1.0, 0.8)

# End of turn cleanup
func finish_turn():
	for revealed_ship in temp_revealed_ships:
		if is_instance_valid(revealed_ship):
			revealed_ship.queue_free()
	temp_revealed_ships = []
	selected_ship = null

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
						# Play sound
						var audio_player = AudioStreamPlayer2D.new()
						add_child(audio_player)
						audio_player.stream = intercept_sound
						audio_player.play()
						yield(audio_player, 'finished')
						audio_player.queue_free()
					# Effect does not stack
					break
		if !hit_countered:
			ship_at_hex.hit([x, y], from_ship)
		else:
			get_parent().grid.grid[x][y].history.append([get_parent().current_turn, 'Missile Defense intercepted hit'])
	else:
		get_parent().grid.grid[x][y].history.append([get_parent().current_turn, 'Miss'])
	return ship_at_hex

func receive_special(x, y, from_ship, secondary = false):
	var ability
	var hits = []
	if secondary:
		ability = from_ship.secondary
	else:
		ability = from_ship.special
	match ability.name:
		'ASW Strike':
			# ASW Strike instantly sinks any submarines on a hex or its direct neighbors
			var affected_hexes = get_parent().grid.get_all_hex_neighbors(x, y, ability.aoe)
			affected_hexes.append([x, y])
			var sunk_hexes = []
			for hex in affected_hexes:
				var ship_at_hex = get_ship_at_hex(hex[0], hex[1])
				if ship_at_hex != null and ship_at_hex.ship_type == 'submarine':
					for sub_hex in ship_at_hex.get_occupied_hexes():
						sunk_hexes.append(sub_hex)
					ship_at_hex.sink()
				else:
					if !sunk_hexes.has(hex):
						get_parent().grid.grid[hex[0]][hex[1]].history.append([get_parent().current_turn, 'Miss (ASW Strike)'])

		'Lay Mine':
			# Lay Mine lays a mine, duh
			get_parent().grid.grid[x][y].is_mined = true
			get_parent().grid.grid[x][y].history.append([get_parent().current_turn, 'Mine laid'])

		'Sonar Pulse':
			# Sonar Pulse reveals all ships around a hex and its direct neighbors and also reveals the submarine
			var revealed_ship = from_ship.duplicate()
			temp_revealed_ships.append(revealed_ship)
			from_ship.revealed_buddy = revealed_ship
			for sub_hex in from_ship.get_occupied_hexes():
				get_parent().grid.grid[sub_hex[0]][sub_hex[1]].history.append([get_parent().current_turn, 'Submarine used Sonar Pulse'])
			var revealed_ships = []
			for hex in get_parent().grid.get_all_hex_neighbors(x, y, ability.aoe):
				var ship_at_hex = get_ship_at_hex(hex[0], hex[1])
				if ship_at_hex != null and ship_at_hex.ship_type != 'coastal_battery' \
				and not ship_at_hex in revealed_ships:
					ship_at_hex.visible = true
					ship_at_hex.modulate = Color(1.0, 1.0, 1.0, 0.8)
					revealed_ships.append(ship_at_hex)
					for ship_hex in ship_at_hex.get_occupied_hexes():
						get_parent().grid.grid[ship_hex[0]][ship_hex[1]].history.append([get_parent().current_turn, ship_at_hex.ship_name + ' revealed by Sonar Pulse'])

		'Nuclear Strike':
			# Nuclear Strike instantly destroys anything it hits hex dead-on (including Coastal Batteries); otherwise hits normally in AOE

			var affected_hexes = get_parent().grid.get_all_hex_neighbors(x, y, ability.aoe)
			var checked_hexes = []
			var dead_center = get_ship_at_hex(x, y)
			if dead_center != null:
				for hex in dead_center.get_occupied_hexes():
					checked_hexes.append(hex)
				dead_center.sink()
			for hex in affected_hexes:
				if !checked_hexes.has(hex):
					checked_hexes.append(hex)
					var ship_at_hex = get_ship_at_hex(hex[0], hex[1])
					if ship_at_hex != null:
						ship_at_hex.hit(hex, from_ship)
					else:
						get_parent().grid.grid[hex[0]][hex[1]].history.append([get_parent().current_turn, 'Miss (Nuclear Strike)'])

		'EW Strike':
			# EW Strike either adds 5 turns to ability cooldown or resets it to default, whichever is less
			var struck_ships = []
			for hex in get_parent().grid.get_all_hex_neighbors(x, y, ability.aoe):
				var ship_at_hex = get_ship_at_hex(hex[0], hex[1])
				if ship_at_hex != null and not ship_at_hex in struck_ships:
					if ship_at_hex.special.name != 'None':
						ship_at_hex.special.cooldown_current = min(ship_at_hex.special.cooldown_current + 5, ship_at_hex.special.cooldown_interval)
					if ship_at_hex.secondary.name != 'None':
						ship_at_hex.secondary.cooldown_current = min(ship_at_hex.secondary.cooldown_current + 5, ship_at_hex.secondary.cooldown_interval)
					struck_ships.append(ship_at_hex)

		'Salvo':
			# Salvo instantly sinks anything when it hits a damaged hex dead-on (including a damaged Coastal Battery); otherwise hits normally in AOE
			var dead_center = get_ship_at_hex(x, y)
			var search_hexes = get_parent().grid.get_all_hex_neighbors(x, y, ability.aoe)
			if dead_center != null:
				if dead_center.is_hex_hit([x, y]):
					for hex in dead_center.get_occupied_hexes():
						search_hexes.erase(hex)
					dead_center.sink()
				else:
					dead_center.hit([x, y], from_ship)
			else:
				get_parent().grid.grid[x][y].history.append([get_parent().current_turn, 'Miss (Salvo)'])
			for hex in search_hexes:
				var ship_at_hex = get_ship_at_hex(hex[0], hex[1])
				if ship_at_hex != null:
					ship_at_hex.hit(hex, from_ship)
				else:
					get_parent().grid.grid[hex[0]][hex[1]].history.append([get_parent().current_turn, 'Miss (Salvo)'])

		'Recon Flight':
			var revealed_ships = []
			for i in range(abs(get_parent().player_up - 1) * 16, abs(get_parent().player_up - 1) * 16 + 15):
				var ship_at_hex = get_ship_at_hex(i, y)
				if ship_at_hex != null and ship_at_hex.ship_type != 'submarine' \
				and not ship_at_hex in revealed_ships:
					ship_at_hex.visible = true
					ship_at_hex.modulate = Color(1.0, 1.0, 1.0, 0.8)
					revealed_ships.append(ship_at_hex)
					for ship_hex in ship_at_hex.get_occupied_hexes():
						get_parent().grid.grid[ship_hex[0]][ship_hex[1]].history.append([get_parent().current_turn, ship_at_hex.ship_name + ' revealed by Recon Flight'])

	return hits
