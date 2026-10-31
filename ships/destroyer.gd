class_name Destroyer
extends Ship

const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const ASW_STRIKE_DESC := (
	"Select a hex on opponent's board; if the hex or any of its direct neighbors contacts"
	+ " an enemy submarine, sink it instantly (does not affect ships)"
)
const LAY_MINE_DESC := (
	"Select a hex on opponent's board to place a mine; if any ships move over that tile, "
	+ "they will take a hit in a random hex"
)

@onready var sh60: SH60 = $SH60


func _ready() -> void:
	super()
	sh60.ship = self
	len_fore = 1
	len_aft = 1
	ship_type = "destroyer"
	hit_hexes = [false, false, false]
	ship_name = "Destroyer"
	weapon = "Anti-Ship Missile"
	special = SpecialAbility.new(2, "ASW Strike", ASW_STRIKE_DESC, 1)
	secondary = SpecialAbility.new(3, "Lay Mine", LAY_MINE_DESC, 0)
	move_sound = preload("res://audio/smallship.ogg")


func fire(target: Vector2i) -> void:
	super(target)
	sh60.instant_recall()
	var missile: Missile = MISSILE_SCENE.instantiate()
	missile.scale = Vector2(2, 2)
	missile.intercepted = intercepted
	missile.ciws_at = ciws_at
	spawn(missile)
	missile.launch(
		global_position + Vector2(0, -25).rotated(rotation), target, global_rotation_degrees
	)
	await missile.done


func use_special(target: Vector2i) -> void:
	super(target)
	sh60.instant_recall()
	await sh60.bomb(target)


func use_secondary(target: Vector2i) -> void:
	super(target)
	sh60.instant_recall()
	if ghost:
		# Replays don't give away where the mine went: just circle the middle
		# of the opponent's side
		await sh60.patrol(Vector2i(grid.columns_of(1 - player.player_num)[7], 7))
	else:
		await sh60.mine(target)
