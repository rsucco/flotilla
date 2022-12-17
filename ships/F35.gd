extends Node2D

var speed = 250
var flying = false
var hidden_from_player
var dest_hex
var dest = null
var path
var path_follow
var path_progress = 0
var sprite
var curve_points = []
var points = []
var last_point = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
	path = get_node('Path')
	path_follow = get_node('Path/PathFollow')
	sprite = get_node('Path/PathFollow/Sprite')

func bomb(target_x, target_y, hidden_from = -1):
	dest_hex = [target_x, target_y]
	dest = to_local(get_parent().root.grid.get_hex_center(target_x, target_y))
	hidden_from_player = hidden_from

	points = PoolVector2Array([
		Vector2(0, 0),
		Vector2(0, -250),
		dest - Vector2(200, 100),
		dest,
		dest - Vector2(200, -100),
		Vector2(0, 100),
		Vector2(0, 0)
	])
	var curve = Curve2D.new()

	for point in points:
		curve.add_point(point)
	curve_points = curve.get_baked_points()
	path.set_curve(curve)
	path_progress = 0
#	rotation_degrees = 90
	flying = true

func _draw():
	for point in curve_points:
		draw_circle(Vector2(point), 2, Color.black)
	for point in points:
		draw_circle(Vector2(point), 5, Color.red)
	if dest != null:
		draw_circle(dest, 5, Color.green)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if flying:
		sprite.global_rotation = last_point.angle_to_point(position)
		last_point = position
		path_progress += speed * delta
		path_follow.offset = path_progress
		update()
