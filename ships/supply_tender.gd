class_name SupplyTender
extends Ship

const REPAIR_SOUND := preload("res://audio/repair.wav")
# How far away a ship UNREP can heal can be
const UNREP_REACH := 2

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
	special = SpecialAbility.new(
		3, "UNREP", "Completely heals one of our ships within %d hexes" % UNREP_REACH
	)
	passive = (PassiveAbility.new(
		"Resupply",
		(
			"Ships next to it count their cooldowns down an extra turn; heals one hex"
			+ " every 10 turns if damaged"
		)
	))
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
		var healed := hit_hexes.rfind(true)
		hit_hexes[healed] = false
		smoke_nodes[healed].queue_free()
		smoke_nodes.erase(healed)
		print("passive - damage control")
	# Drawback - Flammable Cargo: lose 2 AP per turn if damaged
	if hit_hexes.has(true):
		print("drawback - flammable cargo")
		ap = 2


# Our other ships with a hex within `reach` of one of the tender's (1: those
# touching it)
func ships_within(reach: int) -> Array[Ship]:
	var found: Array[Ship] = []
	for ship in player.ships:
		if ship == self:
			continue
		for h in get_occupied_hexes():
			if ship.get_occupied_hexes().any(
				func(o: Vector2i) -> bool: return Grid.distance(h, o) <= reach
			):
				found.append(ship)
				break
	return found


# UNREP needs something to heal
func can_special() -> bool:
	return super() and not ships_within(UNREP_REACH).is_empty()


# Heals the ship at `target`, within reach
func use_special(target: Vector2i) -> void:
	super(target)
	Sfx.play(self, REPAIR_SOUND)
	player.get_ship_at_hex(target).heal()
