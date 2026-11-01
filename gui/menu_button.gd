extends Button
# Opens the Esc menu. Three bars stand in for an icon until there's a real one.


func _draw() -> void:
	var color := get_theme_color("font_disabled_color" if disabled else "font_color")
	var top := (size.y - 12) / 2
	for i in 3:
		draw_rect(Rect2(6, top + i * 5, size.x - 12, 2), color)
