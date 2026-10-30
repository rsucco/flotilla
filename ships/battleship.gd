class_name Battleship
extends Ship

const PROJECTILE_SCENE := preload("res://ships/projectiles/battleship_projectile.tscn")
const TURRET_SOUND := preload("res://audio/artillery_rotate.wav")
const ARMOR_SOUND := preload("res://audio/plink.wav")
const SALVO_DESC := (
	"Shoot one central hex and damage whatever it contains as well as all of its "
	+ "immediate neighbors; if central hex is a damaged hex, sink the enemy ship instantly"
)

var next_turret := 0

@onready var turrets: Array[Sprite2D] = [$Turret0, $Turret1, $Turret2, $Turret3]


func _ready() -> void:
	super()
	len_fore = 1
	len_aft = 2
	ship_type = "battleship"
	hit_hexes = [false, false, false, false]
	ship_name = "Battleship"
	weapon = "Big Gun"
	special = SpecialAbility.new(2, "Salvo", SALVO_DESC, 1)
	passive = PassiveAbility.new("Armor", "Armor grants 25% chance of hits not counting")
	move_sound = preload("res://audio/bigship.ogg")


func fire(target: Vector2i) -> void:
	super(target)
	await point_turrets(target)
	var turret := turrets[next_turret]
	next_turret = (next_turret + 1) % turrets.size()
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	root.add_child(projectile)
	projectile.launch(
		turret.global_position + Vector2(0, -20).rotated(turret.global_rotation), target
	)
	await projectile.done


# Passive - Armor: 25% chance of a hit not counting
func hit(hit_hex: Vector2i, from_ship: Ship) -> void:
	if randf() > 0.25:
		super(hit_hex, from_ship)
	else:
		Sfx.play(self, ARMOR_SOUND)
		log_event(hit_hex, "Miss (Blocked by Armor)")


func use_special(target: Vector2i) -> void:
	super(target)
	await point_turrets(target)
	var targets := root.grid.get_all_hex_neighbors(target, special.aoe)
	# The first and last turrets both shoot at the center hex
	targets.push_front(target)
	targets.append(target)
	# Divert shots to the center hex if they'd otherwise go out of bounds
	while targets.size() < 8:
		targets.append(target)
	var last: Projectile
	# Each turret fires two barrels, offset left and right
	for i in turrets.size():
		var turret := turrets[i]
		for barrel in 2:
			var offset := Vector2(-5 if barrel == 0 else 5, -20).rotated(turret.global_rotation)
			last = PROJECTILE_SCENE.instantiate()
			root.add_child(last)
			last.launch(turret.global_position + offset, targets[i * 2 + barrel])
		# Stagger fire times slightly
		await get_tree().create_timer(0.075, false).timeout
	await last.done


# Rotates all turrets toward the target together
func point_turrets(target: Vector2i) -> void:
	var sound := Sfx.play(self, TURRET_SOUND)
	var center := root.grid.get_hex_center(target)
	for turret in turrets.slice(0, -1):
		aim_turret(turret, center, 1.0)
	await aim_turret(turrets[-1], center, 1.0)
	sound.queue_free()
