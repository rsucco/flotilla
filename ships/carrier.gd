class_name Carrier
extends Ship

@onready var f35: F35 = $F35


func _ready() -> void:
	super()
	f35.ship = self
	len_fore = 2
	len_aft = 2
	ship_type = "carrier"
	# Enough to move after both its attacks (Flight Ops)
	default_ap = 6
	hit_hexes = [false, false, false, false, false]
	ship_name = "Aircraft Carrier"
	weapon = "F-35 Strike"
	special = (SpecialAbility.new(
		2,
		"Recon Flight",
		(
			"Reveals the whole of any ship with a hex in two rows of opponent's board (the"
			+ " one chosen and the next), except for submarines"
		)
	))
	passive = PassiveAbility.new(
		"Flight Ops", "Can take two attack moves in one turn, with AP to spare for moving"
	)
	drawback = Drawback.new(
		"Degraded Runway", "If three or more hexes are damaged, can only take one attack move"
	)
	move_sound = preload("res://audio/bigship.ogg")


func new_turn() -> void:
	super()
	# Drawback - Degraded Runway: loses Flight Ops with three or more damaged hexes
	if hit_hexes.count(true) < 3:
		# Passive - Flight Ops: two fire actions per turn
		fire_remaining = 2
		print("passive - flight ops")
	else:
		print("drawback - degraded runway")


func fire(target: Vector2i) -> void:
	super(target)
	await f35.bomb(target)


func use_special(target: Vector2i) -> void:
	super(target)
	await f35.recon(target)
