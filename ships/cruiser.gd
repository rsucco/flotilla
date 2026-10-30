class_name Cruiser
extends Ship

const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const EW_SCENE := preload("res://ships/projectiles/ew_strike.tscn")
const EW_STRIKE_DESC := (
	"Select a hex on opponent's board; prevents all units within two hexes of central hex"
	+ " from firing next turn and either resets or adds five to their special ability "
	+ "cooldowns, whichever is less"
)
const MISSILE_DEFENSE_DESC := (
	"50% chance of intercepting incoming missile attacks within two hexes (chance is "
	+ "reduced to 25% for incoming nuclear strike)"
)

# Alternates between the fore and aft missile silos
var fore_silo := true


func _ready() -> void:
	super()
	len_fore = 1
	len_aft = 1
	ship_type = "cruiser"
	hit_hexes = [false, false, false]
	ship_name = "Cruiser"
	weapon = "Anti-Ship Missile"
	special = SpecialAbility.new(3, "EW Strike", EW_STRIKE_DESC, 2)
	passive = PassiveAbility.new("Missile Defense", MISSILE_DEFENSE_DESC)
	move_sound = preload("res://audio/smallship.ogg")


func fire(target: Vector2i) -> void:
	super(target)
	var missile: Missile = MISSILE_SCENE.instantiate()
	missile.scale = Vector2(2, 2)
	root.add_child(missile)
	var silo := Vector2(0, -24) if fore_silo else Vector2(0, 40)
	fore_silo = not fore_silo
	missile.launch(global_position + silo.rotated(rotation), target, global_rotation_degrees)
	await missile.done


func use_special(target: Vector2i) -> void:
	super(target)
	var ew: EWStrike = EW_SCENE.instantiate()
	root.add_child(ew)
	await ew.play(root.grid.get_hex_center(target))
