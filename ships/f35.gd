class_name F35
extends Node2D

signal done

const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const JET_SOUND := preload("res://audio/f35.ogg")
const RECON_SOUND := preload("res://audio/recon.wav")

var speed := 0.0
var flying := false
var bombing := false
var reconning := false
var target_hex: Vector2i
var dest: Vector2
var audio_player: AudioStreamPlayer2D
# Set by the ship that carries it
var ship: Ship
var recon_audio_player: AudioStreamPlayer2D

@onready var path: Path2D = $Path2D
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var sprite: Sprite2D = $Path2D/PathFollow2D/Sprite2D


func _ready() -> void:
	audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = JET_SOUND
	add_child(audio_player)
	recon_audio_player = AudioStreamPlayer2D.new()
	recon_audio_player.stream = RECON_SOUND
	add_child(recon_audio_player)


func _process(delta: float) -> void:
	if not flying:
		return
	path_follow.progress += speed * delta
	# Start the camera sounds when nearing the start of a recon pass
	if (
		reconning
		and path_follow.position.distance_to(dest) < 100
		and not recon_audio_player.playing
	):
		recon_audio_player.play()
	if path_follow.position.distance_to(dest) < 70:
		if bombing:
			bombing = false
			var missile: Missile = MISSILE_SCENE.instantiate()
			ship.spawn(missile)
			missile.launch(path_follow.global_position, target_hex, 0.0, true)
			await missile.done
			done.emit()
		elif reconning:
			reconning = false
			done.emit()
	if path_follow.progress >= path.curve.get_baked_length():
		flying = false
		audio_player.stop()
		path_follow.progress = 0


# Flies out to `target` (and on to `target2` for a recon pass) and back
func fly_to(target: Vector2i, target2: Vector2i = Grid.OFF_GRID) -> void:
	dest = to_local(ship.grid.get_hex_center(target))
	# Construct a nice pretty Bézier curve to define the flight path
	var start_point := Vector2.ZERO
	var takeoff_point := Vector2(0, -200)
	var ingress_point := Vector2(0, -150)
	var egress_point := Vector2(0, 300)
	var land_point := Vector2(0, 150)
	var curve := Curve2D.new()
	curve.add_point(start_point)
	curve.add_point(takeoff_point, Vector2.ZERO, ingress_point)
	if target2 != Grid.OFF_GRID:
		var dest2 := to_local(ship.grid.get_hex_center(target2))
		var egress_point2 := (
			Vector2(250, 150) if target2.x > Grid.NO_MANS_LAND else Vector2(-250, 150)
		)
		curve.add_point(dest)
		curve.add_point(dest2, Vector2.ZERO, egress_point2)
	else:
		curve.add_point(dest, takeoff_point, egress_point)
	curve.add_point(land_point, egress_point)
	curve.add_point(start_point)
	path.curve = curve
	path_follow.progress = 0
	# PathFollow2D turns the sprite 90 degrees once it starts following
	sprite.rotation_degrees = 90
	sprite.z_index = 1
	audio_player.play()
	flying = true


# Returns once the missile has hit
func bomb(target: Vector2i) -> void:
	target_hex = target
	# Don't bother flying all the way to the farther columns
	var fake := target
	if fake.x > 17:
		fake.x -= 2
	elif fake.x < 13:
		fake.x += 2
	speed = 250.0
	fly_to(fake)
	bombing = true
	await done


# Flies the length of the target's row; returns once the pass has started
func recon(target: Vector2i) -> void:
	var start := Vector2i(16, target.y) if target.x > Grid.NO_MANS_LAND else Vector2i(14, target.y)
	var end := Vector2i(30, target.y) if target.x > Grid.NO_MANS_LAND else Vector2i(0, target.y)
	speed = 350.0
	fly_to(start, end)
	reconning = true
	await done
