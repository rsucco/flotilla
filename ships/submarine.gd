class_name Submarine
extends Ship

const TORPEDO_SCENE := preload("res://ships/projectiles/torpedo.tscn")
const NUKE_SCENE := preload("res://ships/projectiles/nuke.tscn")
const PULSE_SCENE := preload("res://ships/projectiles/sonar_pulse.tscn")
const SONAR_SOUND := preload("res://audio/sonar.wav")
const NUCLEAR_STRIKE_DESC := (
	"Select a hex on opponent's board; instantly sinks any unit it hits directly and "
	+ "damages all hexes within two hexes of central hex"
)
const SONAR_PULSE_DESC := (
	"Select a hex on opponent's board; reveals ships and submarines on that hex and its "
	+ "direct neighbors and also reveals the location of the submarine"
)
const CRUSHING_DEPTHS_DESC := (
	"Sinks instantly when hit in center hex by surface unit, or when hit in any hex by "
	+ "ASW Strike, mine, or another sub"
)


func _ready() -> void:
	super()
	len_fore = 1
	len_aft = 1
	ship_type = "submarine"
	hit_hexes = [false, false, false]
	ship_name = "Submarine"
	weapon = "Torpedo"
	special = SpecialAbility.new(6, "Nuclear Strike", NUCLEAR_STRIKE_DESC, 2)
	secondary = SpecialAbility.new(1, "Sonar Pulse", SONAR_PULSE_DESC, 1)
	passive = PassiveAbility.new("Silent Service", "Can only be hit by surface units on center hex")
	drawback = Drawback.new("Crushing Depths", CRUSHING_DEPTHS_DESC)
	sink_sound = preload("res://audio/sub_destroyed.wav")
	move_sound = preload("res://audio/sub_movement.ogg")


func hit(hit_hex: Vector2i, from_ship: Ship) -> void:
	# Drawback - Crushing Depths: sinks when hit in the center hex, or in any
	# hex by another sub (mines count as hits from the sub itself)
	if hit_hex == hex or from_ship.ship_type == "submarine":
		print("drawback - crushing depths")
		sink()
	else:
		# Passive - Silent Service: off-center hits from surface units don't count
		log_event(hit_hex, "Miss (Silent Service)")
		print("passive - silent service")


# Can't shoot at land. The default target is in no-man's-land, so the
# button check (no target yet) only considers AP and fire actions.
func can_fire(target: Vector2i = Vector2i(Grid.NO_MANS_LAND, 0)) -> bool:
	return super(target) and not root.grid.tile(target).island


func fire(target: Vector2i) -> void:
	super(target)
	var torpedo: Torpedo = TORPEDO_SCENE.instantiate()
	root.add_child(torpedo)
	torpedo.launch(global_position - Vector2(0, 42).rotated(rotation), target, global_rotation)
	await torpedo.done


func use_special(target: Vector2i) -> void:
	super(target)
	var nuke: Missile = NUKE_SCENE.instantiate()
	nuke.scale = Vector2(2, 2)
	root.add_child(nuke)
	nuke.launch(
		global_position + Vector2(0, -25).rotated(rotation), target, global_rotation_degrees
	)
	await nuke.done


func use_secondary(target: Vector2i) -> void:
	super(target)
	Sfx.play(self, SONAR_SOUND)
	var pulse: SonarPulse = PULSE_SCENE.instantiate()
	root.add_child(pulse)
	await pulse.play(root.grid.get_hex_center(target))
