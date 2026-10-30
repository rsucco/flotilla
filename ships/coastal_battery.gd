class_name CoastalBattery
extends Ship

const PROJECTILE_SCENE := preload("res://ships/projectiles/battleship_projectile.tscn")
const TURRET_SOUND := preload("res://audio/artillery_rotate.wav")

var hp := 5

@onready var turret: Sprite2D = $Turret
@onready var hp_bar: ProgressBar = $HPBar


func _ready() -> void:
	super()
	default_ap = 2
	len_fore = 0
	len_aft = 0
	ship_type = "coastal_battery"
	hit_hexes = [false]
	ship_name = "Coastal Battery"
	weapon = "Big Gun"
	passive = PassiveAbility.new("Fortified", "Must be hit five times to destroy")
	drawback = Drawback.new("Stationary", "Cannot move, reveals itself when firing")
	hit_sound = preload("res://audio/land_hit.wav")
	sink_sound = preload("res://audio/battery_destroyed.wav")


# Batteries track HP instead of hexes, so any lost HP counts as damage
func is_hex_hit(_h: Vector2i) -> bool:
	return hp < 5


# Drawback - Stationary
func can_move(_reverse: bool = false) -> bool:
	return false


func can_rotate(_offset: int) -> bool:
	return false


# Don't rotate during placement either
func turn_by(_offset: int) -> void:
	pass


func fire(target: Vector2i) -> void:
	super(target)
	# Drawback - Stationary: reveals itself to the opponent on their next turn
	var buddy: Ship = duplicate()
	player.opponent().temp_revealed_ships.append(buddy)
	revealed_buddy = buddy
	log_event(hex, "Coastal Battery revealed by firing")
	var sound := Sfx.play(self, TURRET_SOUND)
	await aim_turret(turret, root.grid.get_hex_center(target), 1.0)
	sound.queue_free()
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	root.add_child(projectile)
	projectile.launch(
		turret.global_position + Vector2(0, -20).rotated(turret.global_rotation), target
	)
	await projectile.done


# UNREP restores full HP
func heal() -> void:
	super()
	hp = 5
	hp_bar.value = hp


# Passive - Fortified: 5 HP rather than a set number of hexes to be hit
func hit(hit_hex: Vector2i, _from_ship: Ship) -> void:
	Sfx.play(self, hit_sound)
	hp -= 1
	hp_bar.value = hp
	log_event(hit_hex, "Hit, Coastal Battery (" + str(hp) + "HP)")
	if hp == 0:
		sink()
	else:
		print("passive - fortified")
