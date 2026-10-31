class_name SH60
extends Node2D

signal done
signal landed

const SPEED := 150.0
const IDLE_ROTOR_SPEED := 3.0
const FLYING_ROTOR_SPEED := 35.0
const PROJECTILE_SCENE := preload("res://ships/projectiles/projectile.tscn")
const ROTOR_SOUND := preload("res://audio/seahawk.wav")
const DROP_SOUND := preload("res://audio/depth_charge_mine.wav")
const PATROL_RADIUS := 90.0

var rotor_speed := IDLE_ROTOR_SPEED
var flying := false
var bombing := false
var mining := false
var patrolling := false
var target_hex: Vector2i
var dest: Vector2
var audio_player: AudioStreamPlayer2D
# Set by the ship that carries it
var ship: Ship

@onready var path: Path2D = $Path2D
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var chassis: Sprite2D = $Path2D/PathFollow2D/Chassis
@onready var rotor: Sprite2D = $Path2D/PathFollow2D/Chassis/Rotor


func _ready() -> void:
	audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = ROTOR_SOUND
	add_child(audio_player)


func _process(delta: float) -> void:
	rotor.rotation += rotor_speed * delta
	if not flying:
		# Spin down, then stop the sound once the rotors are idle
		if rotor_speed > IDLE_ROTOR_SPEED:
			rotor_speed -= delta * 15
			audio_player.volume_db -= 0.05
		elif audio_player.playing:
			audio_player.stop()
		return

	# Spin up before moving
	if rotor_speed < FLYING_ROTOR_SPEED:
		rotor_speed += delta * 30
	else:
		path_follow.progress += SPEED * delta
		if patrolling:
			# Face along the loop (the chassis sprite's nose is -y)
			var ahead := path.curve.sample_baked(path_follow.progress + 10)
			var heading := (ahead - path_follow.position).angle() + PI / 2
			chassis.rotation = lerp_angle(chassis.rotation, heading, delta * 5)

	if path_follow.position.distance_to(dest) < 20 and (bombing or mining):
		var dropping_charge := bombing
		bombing = false
		mining = false
		turn_chassis((path_follow.position - position).angle() - PI / 2, 1.0)
		if dropping_charge:
			var projectile: Projectile = PROJECTILE_SCENE.instantiate()
			ship.spawn(projectile)
			projectile.launch(path_follow.global_position, target_hex)
			await projectile.done
		Sfx.play(self, DROP_SOUND)
		done.emit()

	if path_follow.progress >= path.curve.get_baked_length():
		path_follow.progress = 0
		flying = false
		patrolling = false
		turn_chassis(0.0, 0.5)
		landed.emit()


func turn_chassis(angle: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(chassis, "rotation", angle, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


# Lands immediately (e.g. when the destroyer fires), finishing any drop
func instant_recall() -> void:
	if not flying:
		return
	if bombing:
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		ship.spawn(projectile)
		projectile.launch(ship.grid.get_hex_center(target_hex), target_hex)
		await projectile.done
	done.emit()
	audio_player.stop()
	path_follow.progress = 0
	flying = false
	bombing = false
	mining = false
	rotor_speed = IDLE_ROTOR_SPEED
	chassis.global_rotation = ship.global_rotation


func fly_to(target: Vector2i) -> void:
	target_hex = target
	dest = to_local(ship.grid.get_hex_center(target))
	var curve := Curve2D.new()
	curve.add_point(chassis.position)
	curve.add_point(dest)
	curve.add_point(chassis.position)
	_take_off(curve)


# Flies a loop around `center` and back without dropping anything; returns
# once landed
func patrol(center: Vector2i) -> void:
	var middle := to_local(ship.grid.get_hex_center(center))
	# Out along one tangent to the circle, once around its far side clockwise,
	# and home along the other tangent, like a balloon on a string
	var home := middle.direction_to(chassis.position).angle()
	var spread := acos(PATROL_RADIUS / middle.distance_to(chassis.position))
	var arc := TAU - 2 * spread
	# Bézier handle length for an arc drawn in 8 pieces
	var handle := PATROL_RADIUS * 4.0 / 3.0 * tan(arc / 32)
	var curve := Curve2D.new()
	curve.add_point(chassis.position)
	for i in 9:
		var angle := home + spread + arc * i / 8
		# Direction of travel, clockwise on screen
		var ahead := Vector2.from_angle(angle + PI / 2) * handle
		curve.add_point(middle + Vector2.from_angle(angle) * PATROL_RADIUS, -ahead, ahead)
	curve.add_point(chassis.position)
	_take_off(curve)
	patrolling = true
	await landed


func _take_off(curve: Curve2D) -> void:
	path.curve = curve
	path_follow.progress = 0
	chassis.z_index = 1
	audio_player.volume_db = 0.0
	audio_player.play()
	turn_chassis((position - curve.get_point_position(1)).angle() - PI / 2, 1.0)
	flying = true


# Mining and bombing return once the drop has happened
func mine(target: Vector2i) -> void:
	fly_to(target)
	mining = true
	await done


func bomb(target: Vector2i) -> void:
	fly_to(target)
	bombing = true
	await done
