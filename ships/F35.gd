extends Node2D

signal done

const projectile_node = preload('res://ships/projectiles/Missile.tscn')
const turn_speed = 2
const speed = 200
var flying = false
var bombing = false
var hidden_from_player
var dest_hex
var dest = null
var waypoints = []
var path
var path_follow
var sprite
var tween = Tween.new()
var flight_curve

# Called when the node enters the scene tree for the first time.
func _ready():
	path = $Path2D
	path_follow = $"Path2D/PathFollow2D"
	sprite = $"Path2D/PathFollow2D/Sprite"

func bomb(target_x, target_y, hidden_from = -1):
	hidden_from_player = hidden_from
	dest_hex = [target_x, target_y]
	# Don't bother flying all the way to the farther rows
	var fake_x = target_x
	if fake_x > 17:
		fake_x -= 2
	elif fake_x < 13:
		fake_x += 2
	dest = to_local(get_parent().root.grid.get_hex_center(fake_x, target_y))

	var start_point = Vector2(0, 0)
	var takeoff_point = Vector2(0, -200)
	var ingress_point = Vector2(0, -150)
	var egress_point = Vector2(0, 150)
	var land_point = Vector2(0, 150)
	# Construct a nice pretty Bézier curve to define the flight path
	flight_curve = Curve2D.new()
	flight_curve.add_point(start_point)
	flight_curve.add_point(takeoff_point, Vector2.ZERO, ingress_point)
	flight_curve.add_point(dest, takeoff_point, egress_point)
	flight_curve.add_point(land_point, egress_point, start_point)
	flight_curve.add_point(start_point)
	path.curve = flight_curve
	# Idk why tf it wants to rotate the sprite 90 degrees once it starts
	# following the path, but I'm sleepy and this fixes it
	sprite.rotation_degrees = 90
	flying = true
	bombing = true


func _process(delta):
	if flying:
		path_follow.offset += speed * delta
		if bombing and path_follow.position.distance_to(dest) < 70:
			var projectile = projectile_node.instance()
			get_parent().root.add_child(projectile)
			projectile.init(path_follow.global_position, dest_hex, -1, 0, true)
			bombing = false
			yield(projectile, 'done')
			emit_signal('done')

		if path_follow.offset >= path.curve.get_baked_length():
			flying = false
			path_follow.offset = 0
