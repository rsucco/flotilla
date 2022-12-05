extends PanelContainer

var ship_icons

# Called when the node enters the scene tree for the first time.
func _ready():
	# Load ship icon textures
	ship_icons = {}
	for ship_type in Ship.SHIP_TYPES:
		ship_icons[ship_type] = load('res://ships/sprites/' + ship_type + '_icon.png')
	get_parent().gui = self

func _input(event):
	pass

# Update ShipInfo
func update_ship_info():
	var ship = get_parent().selected_ship
	if ship != null:
		get_node('GUIGrid/ShipInfo/Selected').text = 'Selected: ' + ship.ship_name
		get_node('GUIGrid/ShipInfo/Weapon').text = 'Weapon: ' + ship.weapon
		get_node('GUIGrid/ShipInfo/SpecialAbility').text = 'Special Ability: ' + ship.special
		if ship.secondary != 'None':
			get_node('GUIGrid/ShipInfo/SpecialAbility').text += ' / ' + ship.secondary
		get_node('GUIGrid/ShipInfo/PassiveAbility').text = 'Passive Ability: ' + ship.passive
		get_node('GUIGrid/ShipInfo/PassiveAbility').hint_tooltip = get_node('GUIGrid/ShipInfo/PassiveAbility').text
		get_node('GUIGrid/ShipInfo/Drawbacks').text = 'Drawbacks: ' + ship.drawback
		get_node('GUIGrid/ShipInfo/Drawbacks').hint_tooltip = get_node('GUIGrid/ShipInfo/Drawbacks').text
	else:
		get_node('GUIGrid/ShipInfo/Selected').text = 'Selected: '
		get_node('GUIGrid/ShipInfo/Weapon').text = 'Weapon: '
		get_node('GUIGrid/ShipInfo/SpecialAbility').text = 'Special Ability: '
		get_node('GUIGrid/ShipInfo/PassiveAbility').text = 'Passive Ability: '
		get_node('GUIGrid/ShipInfo/Drawbacks').text = 'Drawbacks: '

# Update TurnNumber
func update_turn():
	get_node('GUIGrid/TurnNumber/TurnNumber').text = str(self.get_parent().current_turn)

# Update YourFleet and OpponentFleet
func update_fleets():
	# Clear YourFleet icons
	for n in get_node('GUIGrid/YourFleet/YourFleetIcons').get_children():
		n.queue_free()
	var ship_count = {}
	# Count the number of each type of ship in the player's fleet
	for ship_type in Ship.SHIP_TYPES:
		ship_count[ship_type] = 0
	for ship in get_parent().players[get_parent().player_up].ships:
		ship_count[ship.ship_type] += 1
	# Add ship icons to YourFleet
	for ship_type in Ship.SHIP_TYPES:
		if ship_count[ship_type] > 0:
			var icon_sprite = TextureRect.new()
			icon_sprite.texture = ship_icons[ship_type]
			var icon_label = Label.new()
			icon_label.text = 'x' + str(ship_count[ship_type])
			var icon_container = HBoxContainer.new()
			icon_container.add_child(icon_sprite)
			icon_container.add_child(icon_label)
			get_node('GUIGrid/YourFleet/YourFleetIcons').add_child(icon_container)
#			get_node('GUIGrid/YourFleet/YourFleetIcons').queue_sort()
	# Clear OpponentFleet icons
	for n in get_node('GUIGrid/OpponentFleet/OpponentFleetIcons').get_children():
		n.queue_free()
	ship_count = {}
	# Count the number of each type of ship in the opponent's fleet
	for ship_type in Ship.SHIP_TYPES:
		ship_count[ship_type] = 0
	for ship in get_parent().players[abs(get_parent().player_up - 1)].ships:
		ship_count[ship.ship_type] += 1
	# Add ship icons to OpponentFleet
	for ship_type in Ship.SHIP_TYPES:
		if ship_count[ship_type] > 0:
			var icon_sprite = TextureRect.new()
			icon_sprite.texture = ship_icons[ship_type]
			var icon_label = Label.new()
			icon_label.text = 'x' + str(ship_count[ship_type])
			var icon_container = HBoxContainer.new()
			icon_container.rect_scale = -Vector2(0.1, 0.1)
			icon_container.add_child(icon_sprite)
			icon_container.add_child(icon_label)
			get_node('GUIGrid/OpponentFleet/OpponentFleetIcons').add_child(icon_container)
#			get_node('GUIGrid/YourFleet/YourFleetIcons').queue_sort()
