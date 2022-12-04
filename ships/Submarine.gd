extends Ship

class_name Destroyer

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'submarine'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Submarine'
	self.weapon = 'Torpedo'
	self.special = 'Nuclear Strike (10 turns)'
	self.secondary = 'Sonar Pulse (1 turn)'
	self.passive = 'Can only be hit by surface units on center hex'
	self.drawback = 'Sink instantly when hit in center hex or when hit by ASW Strike, mine, or another sub'
