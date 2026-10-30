class_name PassiveAbility
extends RefCounted

var name: String
var desc: String


func _init(ability_name: String = "None", ability_desc: String = "") -> void:
	name = ability_name
	desc = ability_desc
