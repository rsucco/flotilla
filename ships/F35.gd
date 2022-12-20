extends Node2D

const projectile_node = preload('res://ships/projectiles/Missile.tscn')
const turn_speed = 2
const speed = 150
var flying = false
var bombing = false
var hidden_from_player
var dest_hex
var dest = null
var waypoints = []
var on_waypoint = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func bomb(target_x, target_y, hidden_from = -1):
	position = Vector2(0, 0)
	dest_hex = [target_x, target_y]
	dest = to_local(get_parent().root.grid.get_hex_center(target_x, target_y))
	hidden_from_player = hidden_from
	waypoints = PoolVector2Array([
		Vector2(0, 0),
		Vector2(0, -250),
		dest,
		Vector2(0, 100),
		Vector2(0, 0)
	])
	on_waypoint = 1
	flying = true
	bombing = true

func _process(delta):
	if flying:
		position += Vector2(0, -speed * delta).rotated(rotation)
		var angle_to_next_waypoint = global_position.angle_to(to_global(waypoints[on_waypoint])) * 180 / PI
		while angle_to_next_waypoint < 0:
			angle_to_next_waypoint += 360
		while angle_to_next_waypoint >= 360:
			angle_to_next_waypoint -= 360
		while rotation_degrees < 0:
			rotation_degrees += 360
		while rotation_degrees >= 360:
			rotation_degrees -= 360
		if randi() % 100 > 90:
			print('position: ', position, ' - rotation_degrees: ', rotation_degrees, ' - angle_to_next_waypoint:', angle_to_next_waypoint, ' - on_waypoint:', waypoints[on_waypoint], ' - distance to:', position.distance_to(waypoints[on_waypoint]))
		if angle_to_next_waypoint > rotation_degrees:
			if angle_to_next_waypoint - rotation_degrees >= turn_speed:
				rotation_degrees += turn_speed
			else:
				rotation_degrees = angle_to_next_waypoint
		elif angle_to_next_waypoint < rotation_degrees:
			if rotation_degrees - angle_to_next_waypoint >= turn_speed:
				rotation_degrees += turn_speed
			else:
				rotation_degrees = angle_to_next_waypoint
		if position.distance_to(waypoints[on_waypoint]) < 50:
			on_waypoint += 1
#		if bombing and position.distance_to(dest) < 250:
#			var projectile = projectile_node.instance()
#			get_parent().root.add_child(projectile)
#			projectile.init(global_position, dest_hex, hidden_from_player)
#			on_waypoint = 3
#			bombing = false
