class_name Sfx


# Plays a one-shot positional sound as a child of `parent`. The player frees
# itself when finished; await its `finished` signal to keep the parent alive.
static func play(parent: Node, stream: AudioStream) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player
