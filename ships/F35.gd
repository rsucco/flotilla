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
var tween = Tween.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func bomb(target_x, target_y, hidden_from = -1):
	position = Vector2(0, 0)
	dest_hex = [target_x, target_y]
	dest = to_local(get_parent().root.grid.get_hex_center(target_x, target_y))
	hidden_from_player = hidden_from
	waypoints = PoolVector2Array([
		Vector2(0, 60),
		Vector2(0, -250),
		dest,
		Vector2(0, 150),
		Vector2(0, 60)
	])
	on_waypoint = 1
	flying = true
	bombing = true

func _process(delta):
	if flying:
		position = position.move_toward(waypoints[on_waypoint], speed * delta)
		var angle_to_next_waypoint = global_position.angle_to_point(to_global(waypoints[on_waypoint])) * 180 / PI
		while angle_to_next_waypoint < 0:
			angle_to_next_waypoint += 360
		while angle_to_next_waypoint >= 360:
			angle_to_next_waypoint -= 360
		if randi() % 100 > 90:
			print('position: ', position, ' - global_rotation_degrees: ', global_rotation_degrees, ' - angle_to_next_waypoint:', angle_to_next_waypoint, ' - on_waypoint:', waypoints[on_waypoint], ' - distance to:', position.distance_to(waypoints[on_waypoint]))
		if position.distance_to(waypoints[on_waypoint]) < 30:
			on_waypoint += 1
			if on_waypoint == len(waypoints):
				flying = false
				position = Vector2(0, 60)
				tween.stop_all()
				rotation_degrees = 0
				print('position: ', position, ' - global_rotation_degrees: ', global_rotation_degrees, ' - angle_to_next_waypoint:', angle_to_next_waypoint)
			else:
				tween = Tween.new()
				tween.interpolate_property(self, 'global_rotation_degrees', global_rotation_degrees, angle_to_next_waypoint, 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
				add_child(tween)
				tween.start()

		if bombing and position.distance_to(dest) < 200:
			var projectile = projectile_node.instance()
			get_parent().root.add_child(projectile)
			projectile.init(global_position, dest_hex, hidden_from_player)
			on_waypoint = 3
			bombing = false
			tween = Tween.new()
			tween.interpolate_property(self, 'global_rotation_degrees', global_rotation_degrees, angle_to_next_waypoint, 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			add_child(tween)
			tween.start()
