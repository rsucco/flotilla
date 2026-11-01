class_name SupplyTender
extends Ship

const REPAIR_SOUND := preload("res://audio/repair.wav")

# Turns until Damage Control next heals a hex, or -1 while undamaged
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
		# Counts afresh from the next damage, including after UNREP
		dc_timer = -1
		return
	# Passive - Damage Control: heal one hex every 10 turns if damaged
	if dc_timer == -1:
		dc_timer = 10
	dc_timer -= 1
	if dc_timer == 0:
		dc_timer = 10
		hit_hexes[hit_hexes.rfind(true)] = false
		# Smoke isn't tied to a hex, so put back what's still burning
		for smoke in smoke_nodes:
			smoke.queue_free()
		smoke_nodes.clear()
		for index in hit_hexes.size():
			if hit_hexes[index]:
				_add_smoke(index)
		print("passive - damage control")
	# Drawback - Flammable Cargo: lose 2 AP per turn if damaged
	if hit_hexes.has(true):
		print("drawback - flammable cargo")
		ap = 2


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
