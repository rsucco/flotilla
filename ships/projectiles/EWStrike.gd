extends Node2D

signal done

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(pos):
	position = pos
	var t = Timer.new()
	t.set_wait_time(0.5)
	t.set_one_shot(true)
	self.add_child(t)
	t.start()
	yield(t, "timeout")
	emit_signal('done')
	queue_free()
