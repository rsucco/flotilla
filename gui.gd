class_name GUI
extends PanelContainer

# A button was pressed, by its node name (Fire, NextShip, EndTurn...)
signal action_pressed(action: String)

const BUTTON_TEMPLATE := preload("res://gui/sprites/buttons/button_template.png")

var ship_icons := {}

@onready var special_info: Label = $GUIGrid/ShipInfo/AbilityInfo/SpecialAbility
@onready var secondary_info: Label = $GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility
@onready var passive_info: Label = $GUIGrid/ShipInfo/AbilityInfo/PassiveAbility
@onready var drawback_info: Label = $GUIGrid/ShipInfo/AbilityInfo/Drawbacks
@onready var ship_name: Label = $GUIGrid/ShipInfo/ActionInfo/ShipName
@onready var ship_icon: TextureRect = $GUIGrid/ShipInfo/ActionInfo/ShipIcon
@onready var ap_label: Label = $GUIGrid/ShipInfo/ActionInfo/AP
@onready var ap_pips: APPips = $GUIGrid/ShipInfo/ActionInfo/APPips
@onready var special_button: Button = $GUIGrid/Actions/Special
@onready var secondary_button: Button = $GUIGrid/Actions/Secondary


func _ready() -> void:
	for ship_type in Ship.SHIP_TYPES:
		ship_icons[ship_type] = load("res://gui/sprites/" + ship_type + "_icon.png")
	for button: Button in find_children("*", "Button"):
		button.pressed.connect(func() -> void: action_pressed.emit(button.name))


# Button name -> whether it can be pressed; buttons not listed are unchanged
func set_buttons(enabled: Dictionary) -> void:
	for button: String in enabled:
		(find_child(button) as Button).disabled = not enabled[button]


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
		ap_pips.show_ap(0, 0)
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
	ap_pips.show_ap(ship.ap, ship.default_ap)


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


func update_fleets(ours: Array[Ship], theirs: Array[Ship]) -> void:
	fill_fleet($GUIGrid/YourFleet/YourFleetIcons, ours)
	fill_fleet($GUIGrid/OpponentFleet/OpponentFleetIcons, theirs)


# Replaces a container's contents with an icon and count per ship type
func fill_fleet(container: Container, ships: Array[Ship]) -> void:
	for child in container.get_children():
		child.queue_free()
	for ship_type in Ship.SHIP_TYPES:
		var count := ships.filter(func(s: Ship) -> bool: return s.ship_type == ship_type).size()
		if count == 0:
			continue
		var icon := TextureRect.new()
		icon.texture = ship_icons[ship_type]
		var label := Label.new()
		label.text = "x" + str(count)
		var row := HBoxContainer.new()
		row.add_child(icon)
		row.add_child(label)
		container.add_child(row)
