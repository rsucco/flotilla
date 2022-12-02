extends Ship

class_name Corvette

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(direction, x, y):
	.init(direction, x, y)
	self.len_fore = 0
	self.len_aft = 1
	pass
