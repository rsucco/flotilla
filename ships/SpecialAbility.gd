extends Object

class_name SpecialAbility

var cooldown_current
var cooldown_interval
var name
var desc
var aoe

func _init(cooldown = -1, ability_name = 'None', ability_desc = '', ability_aoe = 0):
	self.cooldown_current = cooldown
	self.cooldown_interval = cooldown
	self.name = ability_name
	self.desc = ability_desc
	self.aoe = ability_aoe
