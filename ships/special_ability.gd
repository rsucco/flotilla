class_name SpecialAbility
extends RefCounted

var cooldown_current: int
var cooldown_interval: int
var name: String
var desc: String
var aoe: int


func _init(
	cooldown: int = -1,
	ability_name: String = "None",
	ability_desc: String = "",
	ability_aoe: int = 0
) -> void:
	cooldown_current = cooldown
	cooldown_interval = cooldown
	name = ability_name
	desc = ability_desc
	aoe = ability_aoe
