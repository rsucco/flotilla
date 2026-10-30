class_name SupplyTender
extends Ship

const REPAIR_SOUND := preload("res://audio/repair.wav")

var dc_timer := -1


func _ready() -> void:
	super()
	len_fore = 1
	len_aft = 1
	ship_type = "supply_tender"
	hit_hexes = [false, false, false]
	ship_name = "Supply Tender"
	weapon = "None"
	special = SpecialAbility.new(3, "UNREP", "Completely heals an adjacent ship")
	passive = PassiveAbility.new("Damage Control", "Heals one hex every 10 turns if damaged")
	drawback = Drawback.new("Flammable Cargo", "Lose 2 AP per turn if damaged")
	move_sound = preload("res://audio/smallship.ogg")


func can_fire(_target: Vector2i = Vector2i.ZERO) -> bool:
	return false


func new_turn() -> void:
	super()
	if not hit_hexes.has(true):
		return
	# Drawback - Flammable Cargo: lose 2 AP per turn if damaged
	print("drawback - flammable cargo")
	ap = 2
	# Passive - Damage Control: heal one hex every 10 turns if damaged
	if dc_timer == -1:
		dc_timer = 10
	elif dc_timer == 0:
		dc_timer = 10
		hit_hexes[hit_hexes.rfind(true)] = false
		print("passive - damage control")
	else:
		dc_timer -= 1


# Our other ships touching any of the tender's hexes
func adjacent_ships() -> Array[Ship]:
	var found: Array[Ship] = []
	for h in get_occupied_hexes():
		for neighbor in grid.get_all_hex_neighbors(h):
			var ship := player.get_ship_at_hex(neighbor)
			if ship != null and ship != self and not found.has(ship):
				found.append(ship)
	return found


# UNREP needs something to heal
func can_special() -> bool:
	return super() and not adjacent_ships().is_empty()


# Heals the adjacent ship at `target`
func use_special(target: Vector2i) -> void:
	super(target)
	Sfx.play(self, REPAIR_SOUND)
	player.get_ship_at_hex(target).heal()
