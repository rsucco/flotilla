class_name Drawback
extends RefCounted

var name: String
var desc: String


func _init(drawback_name: String = "None", drawback_desc: String = "") -> void:
	name = drawback_name
	desc = drawback_desc
