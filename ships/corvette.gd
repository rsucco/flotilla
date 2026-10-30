class_name Corvette
extends Ship

const PROJECTILE_SCENE := preload("res://ships/projectiles/battleship_projectile.tscn")
const FIRE_SOUND := preload("res://audio/corvette.wav")

@onready var turret: Sprite2D = $Turret


func _ready() -> void:
	super()
	len_fore = 0
	len_aft = 1
	ship_type = "corvette"
	hit_hexes = [false, false]
	ship_name = "Corvette"
	weapon = "Deck Gun"
	passive = PassiveAbility.new(
		"Littoral Ops", "Gains an extra move if starting next to an island tile"
	)
	drawback = Drawback.new("Fragile", "Has a 75% chance of sinking if hit in either hex")
	move_sound = preload("res://audio/smallship.ogg")


# Passive - Littoral Ops: extra AP if starting the turn next to an island
func new_turn() -> void:
	super()
	for h in get_occupied_hexes():
		for neighbor in root.grid.get_all_hex_neighbors(h):
			if root.grid.tile(neighbor).island:
				print("passive - littoral ops")
				ap = 5
				break


# Drawback - Fragile: 75% chance of sinking if hit in either hex
func hit(hit_hex: Vector2i, from_ship: Ship) -> void:
	var already_hit := is_hex_hit(hit_hex)
	super(hit_hex, from_ship)
	if already_hit or sunk:
		return
	if randf() < 0.75:
		print("drawback - fragile")
		sink()


func fire(target: Vector2i) -> void:
	super(target)
	await aim_turret(turret, root.grid.get_hex_center(target), 0.5)
	var projectile: BattleshipProjectile = PROJECTILE_SCENE.instantiate()
	projectile.scale = Vector2(0.5, 0.5)
	root.add_child(projectile)
	projectile.launch(
		turret.global_position + Vector2(0, -20).rotated(turret.global_rotation), target, FIRE_SOUND
	)
	await projectile.done
