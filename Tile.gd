extends Object

class_name Tile

# Declare member variables here.
var land


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _init(is_land = false):
	land = is_land

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
