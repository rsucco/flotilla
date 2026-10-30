class_name Carrier
extends Ship

@onready var f35: F35 = $F35


func _ready() -> void:
	super()
	len_fore = 2
	len_aft = 2
	ship_type = "carrier"
	hit_hexes = [false, false, false, false, false]
	ship_name = "Aircraft Carrier"
	weapon = "F-35 Strike"
	special = SpecialAbility.new(2, "Recon Flight", "Reveals one row of hexes on opponent's board")
	passive = PassiveAbility.new(
		"Flight Ops", "Can take two attack moves in one turn instead of moving"
	)
	drawback = Drawback.new(
		"Degraded Runway", "If two or more hexes are damaged, can only take one attack move"
	)
	move_sound = preload("res://audio/bigship.ogg")


func new_turn() -> void:
	super()
	# Drawback - Degraded Runway: loses Flight Ops with two or more damaged hexes
	if hit_hexes.count(true) < 2:
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
