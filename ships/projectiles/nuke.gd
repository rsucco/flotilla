extends Missile

const NUKE_SOUND := preload("res://audio/nuke.wav")


func _ready() -> void:
	rotate_sound = preload("res://audio/torpedo.wav")


func explode(pos: Vector2) -> void:
	# Intercepted by a cruiser: just the normal impact effect
	var last_event := root.grid.tile(dest_hex).get_last_event()
	if not last_event.is_empty() and last_event[1].begins_with("Miss (CIWS"):
		await super(pos)
		return
	var sound := Sfx.play(self, NUKE_SOUND)
	exhaust.queue_free()
	position = pos
	texture = null

	var fire := CPUParticles2D.new()
	fire.spread = 180.0
	fire.gravity = Vector2.ZERO
	fire.initial_velocity_min = 15.0
	fire.initial_velocity_max = 15.0
	fire.damping_min = 10.0
	fire.damping_max = 10.0
	fire.color = Color.CORAL
	fire.scale_amount_min = 0.3
	fire.scale_amount_max = 0.3
	fire.texture = FIRE_TEXTURE
	fire.amount = 200
	fire.lifetime = 1.0
	fire.one_shot = true
	fire.explosiveness = 1.0
	fire.position = pos
	root.add_child(fire)

	var smoke := CPUParticles2D.new()
	smoke.spread = 180.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 40.0
	smoke.damping_min = 20.0
	smoke.damping_max = 20.0
	smoke.scale_amount_min = 0.1
	smoke.scale_amount_max = 0.1
	smoke.texture = SMOKE_TEXTURE
	smoke.amount = 300
	smoke.lifetime = 1.5
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.position = pos
	root.add_child(smoke)

	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.size = get_viewport_rect().size
	# The player can act again while it fades, so don't eat their clicks
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	flash.global_position = Vector2.ZERO
	var tween := create_tween()
	(
		tween
		. tween_property(flash, "color", Color.TRANSPARENT, 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	fire.queue_free()
	smoke.queue_free()
	flash.queue_free()
	if sound.playing:
		await sound.finished
