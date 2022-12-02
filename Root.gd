extends Node2D

var font
var grid
var corvette

# Called when the node enters the scene tree for the first time.
func _ready():
	font = DynamicFont.new()
	font.font_data = load("res://opensans.ttf")
	font.size = 10
	grid = Grid.new()
	corvette = preload('res://Corvette.tscn').instance()
	corvette.init(320, 3, 4)
	add_child(corvette)

func _draw():
	var mouse_hex = grid.get_hex_from_coords(get_viewport().get_mouse_position())
	for x in range(31):
		for y in range(15):
			var color
			if mouse_hex == [x, y]:
				color = PoolColorArray([Color(1.0, 0.0, 0.0)])
			elif grid.grid[x][y].is_land:
				color = PoolColorArray([Color(0.0, 0.7, 0.0)])
			else:
				color = PoolColorArray([Color(0.0, 0.5, 1.0)])
			var hex_points = grid.get_hex_points(x, y)
			draw_polygon(hex_points, color)
			# Draw the border
			for i in range(1, 6):
				draw_line(hex_points[i - 1], hex_points[i], Color(0.0, 0.0, 0.0))
			draw_line(hex_points[5], hex_points[0], Color(0.0, 0.0, 0.0))
			draw_string(font, grid.get_hex_center(x, y), str(x) + ',' + str(y))

func _input(event):
	if event is InputEventMouseButton:
		print('Click! Mouse position:', event.position)
		var on_hex = grid.get_hex_from_coords(event.position)
		print('On hex:', on_hex)
		print('Hex neighbors:', grid.get_all_hex_neighbors(on_hex[0], on_hex[1]))
	elif event is InputEventMouseMotion:
		update()
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
