extends Node2D

signal done

const speed = 150
const idle_rotor_speed = 3
const flying_rotor_speed = 35
const projectile_node = preload('res://ships/projectiles/Projectile.tscn')

var path
var path_follow
var chassis
var rotor
var rotor_speed
var flying = false
var bombing = false
var mining = false
var hidden_from_player
var target_hex
var start_point
var dest

func _ready():
	path = $Path2D
	path_follow = $Path2D/PathFollow2D
	chassis = $Path2D/PathFollow2D/Chassis
	rotor = $Path2D/PathFollow2D/Chassis/Rotor
	rotor_speed = idle_rotor_speed

func _process(delta):
	if flying:
		# Spin up rotors
		if rotor_speed < flying_rotor_speed:
			rotor_speed += delta * 30
		else:
			path_follow.offset += speed * delta
		if path_follow.position.distance_to(dest) < 20 and (bombing or mining):
			var tween = Tween.new()
			tween.interpolate_property(chassis, 'rotation', chassis.rotation, path_follow.position.angle_to_point(position) - PI/2, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			add_child(tween)
			tween.start()
			if bombing:
				var projectile = projectile_node.instance()
				get_parent().root.add_child(projectile)
				projectile.init(path_follow.global_position, target_hex, -1)
				yield(projectile, 'done')
			bombing = false
			mining = false
			emit_signal('done')
		if path_follow.offset >= path.curve.get_baked_length():
			path_follow.offset = 0
			flying = false
			var tween = Tween.new()
			tween.interpolate_property(chassis, 'rotation', chassis.rotation, 0, 0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			add_child(tween)
			tween.start()
	else:
		# Spin down rotors
		if rotor_speed > idle_rotor_speed:
			rotor_speed -= delta * 15
	rotor.rotation += rotor_speed * delta

func fly_to(target_x, target_y, hidden_from = -1):
	target_hex = [target_x, target_y]
	hidden_from_player = hidden_from
	dest = to_local(get_parent().root.grid.get_hex_center(target_x, target_y))
	var flight_curve = Curve2D.new()
	flight_curve.add_point(chassis.position)
	flight_curve.add_point(dest)
	flight_curve.add_point(chassis.position)
	path.curve = flight_curve
	path_follow.offset = 0
	chassis.z_index = 1
	var tween = Tween.new()
	tween.interpolate_property(chassis, 'rotation', chassis.rotation, position.angle_to_point(dest) - PI/2, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()
	flying = true

func mine(target_x, target_y, hidden_from = -1):
	fly_to(target_x, target_y, hidden_from)
	mining = true

func bomb(target_x, target_y, hidden_from = -1):
	fly_to(target_x, target_y, hidden_from)
	bombing = true
