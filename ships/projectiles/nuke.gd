extends Missile

const NUKE_SOUND := preload("res://audio/nuke.wav")


func _ready() -> void:
	rotate_sound = preload("res://audio/torpedo.wav")


func explode(pos: Vector2) -> void:
	# Intercepted by a cruiser: just the normal impact effect
	var last_event := grid.tile(dest_hex).get_last_event()
	if not last_event.is_empty() and last_event[1].begins_with("Miss (CIWS"):
		await super(pos)
		return
	var sound := Sfx.play(self, NUKE_SOUND)
	exhaust.queue_free()
	position = pos
	texture = null

	# Out to the edge of the strike's area: two hexes' reach
	var step := grid.get_hex_center(dest_hex).distance_to(
		grid.get_hex_center(dest_hex + Vector2i(0, 1))
	)
	var lasts := Explosion.nuke(get_parent(), pos, step * 2.5)

	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.size = get_viewport_rect().size
	# The player can act again while it fades, so don't eat their clicks
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_sibling(flash)
	flash.global_position = Vector2.ZERO
	var tween := create_tween()
	(
		tween
		. tween_property(flash, "color", Color.TRANSPARENT, 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await tween.finished

	await get_tree().create_timer(lasts - 0.5, false).timeout
	flash.queue_free()
	fading = true
	if is_instance_valid(sound) and sound.playing:
		await sound.finished
