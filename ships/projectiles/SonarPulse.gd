extends Sprite

var size = 0
signal done

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(pos):
	position = pos
	scale = Vector2(5,5)

func _draw():
	draw_arc(Vector2(0, 0), size, 0, PI * 2, 100, Color(0, 0, 0, 0.5), 2)

func _process(delta):
	size += delta * 50
	if size > 13:
		emit_signal('done')
		self.queue_free()
	update()
