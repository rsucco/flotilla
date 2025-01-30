extends Node2D

signal done

const projectile_node = preload('res://ships/projectiles/Missile.tscn')
const jet_sound = preload('res://audio/f35.ogg')
const recon_sound = preload('res://audio/recon.wav')
var speed = 0
var flying = false
var bombing = false
var reconning = false
var hidden_from_player
var target_hex
var dest = null
var path
var path_follow
var sprite
var audio_player
var recon_audio_player
	
# Called when the node enters the scene tree for the first time.
func _ready():
	path = $Path2D
	path_follow = $Path2D/PathFollow2D
	sprite = $Path2D/PathFollow2D/Sprite
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = jet_sound
	recon_audio_player = AudioStreamPlayer2D.new()
	add_child(recon_audio_player)
	recon_audio_player.stream = recon_sound


func fly_to(target_x, target_y, hidden_from = -1, target_x2 = null, target_y2 = null):
	hidden_from_player = hidden_from
	dest = to_local(get_parent().root.grid.get_hex_center(target_x, target_y))
	# Construct a nice pretty Bézier curve to define the flight path
	var start_point = Vector2(0, 0)
	var takeoff_point = Vector2(0, -200)
	var ingress_point = Vector2(0, -150)
	var egress_point = Vector2(0, 300)
	var land_point = Vector2(0, 150)
	var flight_curve = Curve2D.new()
	flight_curve.add_point(start_point)
	flight_curve.add_point(takeoff_point, Vector2.ZERO, ingress_point)
	if target_x2 != null and target_y2 != null:
		var dest2 = to_local(get_parent().root.grid.get_hex_center(target_x2, target_y2))
		var egress_point2
		if target_x2 > 15:
			egress_point2 = Vector2(250, 150)
		else:
			egress_point2 = Vector2(-250, 150)
		flight_curve.add_point(dest)
		flight_curve.add_point(dest2, Vector2.ZERO, egress_point2)
	else:
		flight_curve.add_point(dest, takeoff_point, egress_point)
	flight_curve.add_point(land_point, egress_point)
	flight_curve.add_point(start_point)
	path.curve = flight_curve
	path_follow.offset = 0
	# Idk why tf it wants to rotate the sprite 90 degrees once it starts
	# following the path, but I'm sleepy and this fixes it
	sprite.rotation_degrees = 90
	sprite.z_index = 1
	# Play sound
	audio_player.play()
	flying = true

func bomb(target_x, target_y, hidden_from = -1):
	hidden_from_player = hidden_from
	target_hex = [target_x, target_y]
	# Don't bother flying all the way to the farther rows
	var fake_x = target_x
	if fake_x > 17:
		fake_x -= 2
	elif fake_x < 13:
		fake_x += 2
	speed = 250
	self.fly_to(fake_x, target_y, hidden_from)
	bombing = true

func recon(target_x, target_y, hidden_from = -1):
	hidden_from_player = hidden_from
	var fake_x1
	var fake_x2
	if target_x > 15:
		fake_x1 = 16
		fake_x2 = 30
	else:
		fake_x1 = 14
		fake_x2 = 0
	speed = 350
	self.fly_to(fake_x1, target_y, hidden_from, fake_x2, target_y)
	reconning = true


func _process(delta):
	if flying:
		path_follow.offset += speed * delta
		# Start playing camera sounds when beginning a recon path
		if reconning and path_follow.position.distance_to(dest) < 100 and not recon_audio_player.playing:
			recon_audio_player.play()
		if path_follow.position.distance_to(dest) < 70:
			if bombing:
				var projectile = projectile_node.instance()
				get_parent().root.add_child(projectile)
				projectile.init(path_follow.global_position, target_hex, -1, 0, true)
				bombing = false
				yield(projectile, 'done')
				emit_signal('done')
			elif reconning:
				reconning = false
				emit_signal('done')

		if path_follow.offset >= path.curve.get_baked_length():
			flying = false
			audio_player.stop()
			path_follow.offset = 0
