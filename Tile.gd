extends Object

class_name Tile

# Declare member variables here.
var no_mans_land
var island
var history

func _init(no_mans_land = false, island = false):
	self.no_mans_land = no_mans_land
	self.island = island
	self.history = []

# Returns whether the last event was a hit/miss and how many turns ago
func get_last_event():
	for i in range(history.size() - 1, -1, -1):
		var hit_or_miss = history[i][1].split(',')[0]
		if hit_or_miss in ['Hit', 'Miss', 'Sunk']:
			return [history[i][0], hit_or_miss]
		else:
			return null
