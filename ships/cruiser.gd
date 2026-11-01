class_name Cruiser
extends Ship

const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const EW_SCENE := preload("res://ships/projectiles/ew_strike.tscn")
const EW_STRIKE_DESC := (
	"Select a hex on opponent's board; prevents all units within two hexes of central hex"
	+ " from firing next turn and either resets or adds five to their special and "
	+ "secondary ability cooldowns, whichever is less"
)
const MISSILE_DEFENSE_DESC := (
	"50% chance of intercepting incoming missile attacks within two hexes (chance is "
	+ "reduced to 25% for incoming nuclear strike)"
)
# How fast the CIWS mount turns, in radians per second: fast enough to be on
# target before the tracers show, from when it's first heard
const CIWS_SLEW := TAU * 4

# Alternates between the fore and aft missile silos
var fore_silo := true
# The missile the CIWS is shooting at, if any
var tracking: Missile

@onready var ciws: Sprite2D = $CIWS


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


# Follows the missile until it's been shot down, then turns back to the bow
func _process(delta: float) -> void:
	var aim := 0.0
	if is_instance_valid(tracking) and not tracking.fading:
		# The mount's sprite points up (-y)
		aim = ciws.global_position.direction_to(tracking.global_position).angle() + PI / 2
		aim = wrapf(aim - global_rotation, -PI, PI)
	ciws.rotation = rotate_toward(ciws.rotation, aim, CIWS_SLEW * delta)


# Shown in the defender's replay: the CIWS turning to shoot `missile` down
func track(missile: Missile) -> void:
	tracking = missile


func fire(target: Vector2i) -> void:
	super(target)
	var missile: Missile = MISSILE_SCENE.instantiate()
	missile.scale = Vector2(2, 2)
	missile.intercepted = intercepted
	missile.ciws_at = ciws_at
	missile.ciws_shown = ghost
	spawn(missile)
	var silo := Vector2(0, -24) if fore_silo else Vector2(0, 40)
	fore_silo = not fore_silo
	missile.launch(global_position + silo.rotated(rotation), target, global_rotation_degrees)
	await missile.done


func use_special(target: Vector2i) -> void:
	super(target)
	var ew: EWStrike = EW_SCENE.instantiate()
	spawn(ew)
	await ew.play(grid.get_hex_center(target))
