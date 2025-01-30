extends Missile

const nuke_sound = preload('res://audio/nuke.wav')

# Called when the node enters the scene tree for the first time.
func _ready():
	self.rotate_sound = preload('res://audio/torpedo.wav')


func explode(pos = null):
	# Play sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = nuke_sound
	audio_player.play()
	fire.queue_free()
	position = dest
	texture = null
	var fire = Particles2D.new()
	var fire_material = ParticlesMaterial.new()
	fire_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	fire_material.initial_velocity = 15
	fire_material.gravity = Vector3(0, 0, 0)
	fire_material.spread = 360.0
	fire_material.damping = 10
	fire_material.color = Color.coral
	fire_material.scale = 0.3
	fire.process_material = fire_material
	fire.texture = preload('res://ships/sprites/projectiles/fire.png')
	fire.amount = 200
	fire.lifetime = 1
	fire.set_one_shot(true)
	fire.set_explosiveness_ratio(1)
	fire.position = position
	get_parent().add_child(fire)

	var smoke = Particles2D.new()
	var smoke_material = ParticlesMaterial.new()
	smoke_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_POINT
	smoke_material.initial_velocity = 40
	smoke_material.gravity = Vector3(0, 0, 0)
	smoke_material.spread = 360.0
	smoke_material.damping = 20
	smoke_material.scale = 0.1
	smoke.process_material = smoke_material
	smoke.texture = preload('res://ships/sprites/projectiles/smoke.png')
	smoke.amount = 300
	smoke.lifetime = 1.5
	smoke.set_one_shot(true)
	smoke.set_explosiveness_ratio(1)
	smoke.position = position
	get_parent().add_child(smoke)

	var flash = ColorRect.new()
	flash.color = Color.white
	flash.rect_size = get_viewport_rect().size
	flash.set_global_position(Vector2.ZERO)
	get_parent().add_child(flash)
	var tween = Tween.new()
	tween.interpolate_property(flash, 'color', Color.white, Color.transparent, 0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	add_child(tween)
	tween.start()
	yield(tween, 'tween_completed')

	var t = Timer.new()
	t.set_wait_time(1)
	t.set_one_shot(true)
	self.add_child(t)
	t.start()
	yield(t, "timeout")

	fire.queue_free()
	smoke.queue_free()
	flash.queue_free()
	yield(audio_player, 'finished')
	audio_player.queue_free()
	emit_signal('explosion_done')
