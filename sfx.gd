class_name Sfx

const BUS := &"Effects"


# A positional player on the Effects bus, so the volume setting applies. Use
# this for every sound effect.
static func new_player() -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = BUS
	return player


# Plays a one-shot positional sound as a child of `parent`. The player frees
# itself when finished; await its `finished` signal to keep the parent alive.
static func play(parent: Node, stream: AudioStream) -> AudioStreamPlayer2D:
	var player := new_player()
	player.stream = stream
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player


# Quits once every sound has stopped. Godot frees a stopped sound a moment
# later, on the audio thread, and quitting before then leaks it.
static func quit(tree: SceneTree) -> void:
	if is_instance_valid(tree.current_scene):
		tree.current_scene.queue_free()
	await tree.create_timer(0.1).timeout
	tree.quit()
