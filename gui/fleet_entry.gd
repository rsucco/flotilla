class_name FleetEntry
extends HBoxContainer
# One ship type in a fleet panel: its icon and count, the count in red if any
# of them is damaged. Hovering it lists each ship of that type with its hit hexes;
# so does tapping it, for touch screens, which have no hover.

const HIT_COLOR := Color(1.0, 0.25, 0.25)

# Set before adding to the tree
var ships: Array[Ship] = []
var icon: Texture2D
var show_damage := true


func _ready() -> void:
	# Tooltips need text; the hover list replaces it
	tooltip_text = ships[0].ship_name
	var rect := TextureRect.new()
	rect.texture = icon
	add_child(rect)
	var count := Label.new()
	count.text = "x" + str(ships.size())
	if show_damage and ships.any(func(s: Ship) -> bool: return _hits(s).has(true)):
		count.modulate = HIT_COLOR
	add_child(count)


func _gui_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap == null or not tap.pressed or tap.button_index != MOUSE_BUTTON_LEFT:
		return
	# Styled like the tooltip; closes on the next click anywhere
	var popup := PopupPanel.new()
	popup.theme_type_variation = "TooltipPanel"
	popup.add_child(_make_custom_tooltip(tooltip_text))
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	popup.reset_size()
	# Above the entry, since the fleet panels are at the bottom of the screen
	var rect := get_global_rect()
	popup.popup(Rect2i(Vector2i(rect.position) - Vector2i(0, popup.size.y), popup.size))


func _make_custom_tooltip(for_text: String) -> Object:
	var list := VBoxContainer.new()
	var title := Label.new()
	title.text = for_text
	list.add_child(title)
	for ship in ships:
		if not is_instance_valid(ship):
			continue
		var row := HBoxContainer.new()
		var rect := TextureRect.new()
		rect.texture = icon
		rect.draw.connect(_draw_hits.bind(rect, ship))
		row.add_child(rect)
		if ship is CoastalBattery and show_damage:
			var hp := Label.new()
			hp.text = str((ship as CoastalBattery).hp) + "/5 HP"
			row.add_child(hp)
		list.add_child(row)
	return list


# A dot on each hit hex of the icon, stern on the left
func _draw_hits(rect: TextureRect, ship: Ship) -> void:
	if not show_damage or not is_instance_valid(ship):
		return
	var hits := _hits(ship)
	var width := rect.size.x / hits.size()
	for i in hits.size():
		if hits[i]:
			rect.draw_circle(Vector2(width * (i + 0.5), rect.size.y / 2), 3.5, HIT_COLOR)


func _hits(ship: Ship) -> Array[bool]:
	var hits: Array[bool] = []
	for h in ship.get_occupied_hexes():
		hits.append(ship.is_hex_hit(h))
	return hits
