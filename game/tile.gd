class_name Tile
extends RefCounted

var no_mans_land: bool
var island: bool
var is_mined := false
# Entries are [turn: int, event: String]
var history: Array[Array] = []


func _init(is_no_mans_land: bool = false, is_island: bool = false) -> void:
	no_mans_land = is_no_mans_land
	island = is_island


# Returns [turn, "Hit"/"Miss"/"Sunk"/"Miss (...)"] if the latest event is a
# hit or miss, otherwise an empty array
func get_last_event() -> Array:
	if history.is_empty():
		return []
	var last: Array = history[-1]
	var hit_or_miss: String = last[1].split(",")[0]
	# Batteries are destroyed rather than sunk, but marked the same
	if hit_or_miss == "Destroyed":
		hit_or_miss = "Sunk"
	if hit_or_miss in ["Hit", "Miss", "Sunk"] or hit_or_miss.begins_with("Miss ("):
		return [last[0], hit_or_miss]
	return []
