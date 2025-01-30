extends Node2D

signal done
const ew_sound = preload('res://audio/ew_strike.wav')

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(pos):
	# Play sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = ew_sound
	audio_player.play()
	position = pos
	var t = Timer.new()
	t.set_wait_time(0.5)
	t.set_one_shot(true)
	self.add_child(t)
	t.start()
	yield(t, "timeout")
	emit_signal('done')
	queue_free()
