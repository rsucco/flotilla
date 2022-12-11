extends Object

class_name Tile

# Declare member variables here.
var no_mans_land
var island
var history

func _init(no_mans_land = false, island = false):
	self.no_mans_land = no_mans_land
	self.island = island
	self.history = [[0, 'jack shit happened']]
