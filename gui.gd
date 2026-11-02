class_name GUI
extends PanelContainer

# A button was pressed, by its node name (Fire, NextShip, EndTurn...)
signal action_pressed(action: String)

const BUTTON_TEMPLATE := preload("res://gui/sprites/buttons/button_template.png")
# The Controller Icons addon's texture, loaded rather than named so that
# --check-only can compile this script (see CLAUDE.md)
const GLYPH_SCRIPT := "res://addons/controller_icons/objects/ControllerIconTexture.gd"
# HUD button -> the input action whose button or key it shows
const GLYPHS := {
	"Fire": "action_fire",
	"Special": "action_special",
	"Secondary": "action_secondary",
	"NextShip": "action_next_ship",
	"Forward": "action_forward",
	"Reverse": "action_reverse",
	"Port": "action_port",
	"Starboard": "action_starboard",
	"EndTurn": "action_end_turn",
}
const GLYPH_SIZE := 14

var ship_icons := {}
# Whether the buttons show which button or key presses them: only while a
# controller, or a hotkey, was the last thing used; the mouse hides them
var hints := false:
	set(value):
		hints = value
		for button: String in GLYPHS:
			_glyph(button).visible = value
# How far through End Turn's hold, 0 to 1
var end_turn_hold := 0.0

@onready var special_info: Label = $GUIGrid/ShipInfo/AbilityInfo/SpecialAbility
@onready var secondary_info: Label = $GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility
@onready var passive_info: Label = $GUIGrid/ShipInfo/AbilityInfo/PassiveAbility
@onready var drawback_info: Label = $GUIGrid/ShipInfo/AbilityInfo/Drawbacks
@onready var ship_name: Label = $GUIGrid/ShipInfo/ActionInfo/ShipName
@onready var ship_icon: TextureRect = $GUIGrid/ShipInfo/ActionInfo/ShipIcon
@onready var ap_label: Label = $GUIGrid/ShipInfo/ActionInfo/AP
@onready var special_button: Button = $GUIGrid/Actions/Special
@onready var secondary_button: Button = $GUIGrid/Actions/Secondary


func _ready() -> void:
	for ship_type in Ship.SHIP_TYPES:
		ship_icons[ship_type] = load("res://gui/sprites/" + ship_type + "_icon.png")
	for button: String in GLYPHS:
		var glyph := TextureRect.new()
		glyph.name = "Glyph"
		var texture: Texture2D = load(GLYPH_SCRIPT).new()
		texture.set("path", GLYPHS[button])
		glyph.texture = texture
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.visible = false
		find_child(button).add_child(glyph)
		# In the top-right corner, or beside End Turn, whose text fills it
		glyph.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		glyph.offset_left = -GLYPH_SIZE - 1
		glyph.offset_top = 1
		if button == "EndTurn":
			glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			glyph.offset_left = -GLYPH_SIZE - 3
			glyph.offset_top = -GLYPH_SIZE / 2.0
		glyph.offset_right = glyph.offset_left + GLYPH_SIZE
		glyph.offset_bottom = glyph.offset_top + GLYPH_SIZE
	find_child("EndTurn").draw.connect(_draw_end_turn_hold)
	for button: Button in find_children("*", "Button"):
		button.pressed.connect(func() -> void: action_pressed.emit(button.name))
		# Or a clicked button would keep the focus, and with it Tab, Space and Enter
		button.focus_mode = Control.FOCUS_NONE


# Button name -> whether it can be pressed; buttons not listed are unchanged
func set_buttons(enabled: Dictionary) -> void:
	for button: String in enabled:
		(find_child(button) as Button).disabled = not enabled[button]
		if GLYPHS.has(button):
			_glyph(button).modulate.a = 1.0 if enabled[button] else 0.4


func _glyph(button: String) -> TextureRect:
	return find_child(button).get_node("Glyph")


# A controller or a hotkey shows the hints; real mouse use hides them (the
# HexCursor's stand-in mouse moves have no relative motion, so don't count)
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventKey:
		if event.is_pressed() and not hints:
			hints = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5 and not hints:
			hints = true
	elif (
		event is InputEventMouseButton
		or (
			event is InputEventMouseMotion
			and (event as InputEventMouseMotion).relative != Vector2.ZERO
		)
	):
		if hints:
			hints = false


# Shows how far through the End Turn hold the player is
func show_end_turn_hold(fraction: float) -> void:
	end_turn_hold = fraction
	find_child("EndTurn").queue_redraw()


# A bar filling along the bottom of End Turn while it's held
func _draw_end_turn_hold() -> void:
	if end_turn_hold <= 0.0:
		return
	var button: Button = find_child("EndTurn")
	var bar := Rect2(0, button.size.y - 4, button.size.x * end_turn_hold, 4)
	button.draw_rect(bar, Color.WHITE)


func update_ship_info(ship: Ship) -> void:
	if ship == null:
		passive_info.text = "Passive Ability: "
		passive_info.tooltip_text = ""
		drawback_info.text = "Drawbacks: "
		drawback_info.tooltip_text = ""
		ship_name.text = ""
		ship_name.tooltip_text = ""
		ship_icon.modulate = Color.TRANSPARENT
		ap_label.text = "AP:     "
		update_ability(special_button, special_info, "Special", null)
		update_ability(secondary_button, secondary_info, "Secondary", null)
		return
	update_ability(special_button, special_info, "Special", ship.special)
	update_ability(secondary_button, secondary_info, "Secondary", ship.secondary)
	passive_info.text = "Passive Ability: " + ship.passive.name
	passive_info.tooltip_text = ship.passive.desc
	drawback_info.text = "Drawbacks: " + ship.drawback.name
	drawback_info.tooltip_text = ship.drawback.desc
	ship_name.text = ship.ship_name
	ship_name.tooltip_text = "Weapon: " + ship.weapon
	ship_icon.texture = ship_icons[ship.ship_type]
	ship_icon.modulate = Color.WHITE
	ap_label.text = "AP: " + str(ship.ap) + "/" + str(ship.default_ap)


# Shows an ability's name, cooldown, and icon; null clears it
func update_ability(button: Button, info: Label, kind: String, ability: SpecialAbility) -> void:
	button.text = kind
	button.icon = BUTTON_TEMPLATE
	if ability == null:
		info.text = kind + " Ability: "
		info.tooltip_text = ""
		return
	info.text = kind + " Ability: " + ability.name
	info.tooltip_text = ability.desc
	if ability.name != "None":
		info.text += (
			" (" + str(ability.cooldown_current) + "/" + str(ability.cooldown_interval) + ")"
		)
		button.text = ability.name
		button.icon = load(
			(
				"res://gui/sprites/buttons/special_"
				+ ability.name.to_lower().replace(" ", "_")
				+ ".png"
			)
		)


func update_turn(turn: int) -> void:
	$GUIGrid/TurnNumber/TurnNumber.text = str(turn)


# With `our_damage` false, our hits stay hidden (until the replay has shown them)
# Each fleet panel's heading carries its navy's flag
func set_flags(ours: Texture2D, theirs: Texture2D) -> void:
	$GUIGrid/YourFleet/YourFleetHeading/Flag.texture = ours
	$GUIGrid/OpponentFleet/OpponentFleetHeading/Flag.texture = theirs


func update_fleets(ours: Array[Ship], theirs: Array[Ship], our_damage: bool = true) -> void:
	fill_fleet($GUIGrid/YourFleet/YourFleetIcons, ours, our_damage)
	fill_fleet($GUIGrid/OpponentFleet/OpponentFleetIcons, theirs, true)


# Replaces a container's contents with an entry per ship type
func fill_fleet(container: Container, ships: Array[Ship], show_damage: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	for ship_type in Ship.SHIP_TYPES:
		var of_type := ships.filter(func(s: Ship) -> bool: return s.ship_type == ship_type)
		if of_type.is_empty():
			continue
		var entry := FleetEntry.new()
		entry.ships = of_type
		entry.icon = ship_icons[ship_type]
		entry.show_damage = show_damage
		container.add_child(entry)
