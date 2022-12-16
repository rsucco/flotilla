extends Projectile

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(orig, dest_hex, hidden_from = -1):
	.init(orig, dest_hex, hidden_from)
	speed = 400
