extends PanelContainer

var ship_icons

# Called when the node enters the scene tree for the first time.
func _ready():
	# Load ship icon textures
	ship_icons = {}
	for ship_type in Ship.SHIP_TYPES:
		ship_icons[ship_type] = load('res://gui/sprites/' + ship_type + '_icon.png')
	get_parent().gui = self

func _input(event):
	pass

func disable_button(button, disabled = true):
	get_node('GUIGrid/Actions/' + button).disabled = disabled

# Update ShipInfo
func update_ship_info(ship):
	if ship != null:
		# Update AbilityInfo container and Actions buttons
		get_node('GUIGrid/ShipInfo/AbilityInfo/SpecialAbility').text = 'Special Ability: ' + ship.special.name
		if ship.special.name != 'None':
			get_node('GUIGrid/ShipInfo/AbilityInfo/SpecialAbility').text += ' (' + str(ship.special.cooldown_current) + '/' + str(ship.special.cooldown_interval) + ')'
			get_node('GUIGrid/Actions/Special').text = ship.special.name
			get_node('GUIGrid/Actions/Special').icon = load('res://gui/sprites/buttons/special_' + ship.special.name.to_lower().replace(' ', '_') + '.png')
		else:
			get_node('GUIGrid/Actions/Special').text = 'Special'
			get_node('GUIGrid/Actions/Special').icon = load('res://gui/sprites/buttons/button_template.png')
		get_node('GUIGrid/ShipInfo/AbilityInfo/SpecialAbility').hint_tooltip = ship.special.desc
		get_node('GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility').text = 'Secondary Ability: ' + ship.secondary.name
		if ship.secondary.name != 'None':
			get_node('GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility').text += ' (' + str(ship.secondary.cooldown_current) + '/' + str(ship.secondary.cooldown_interval) + ')'
			get_node('GUIGrid/Actions/Secondary').text = ship.secondary.name
			get_node('GUIGrid/Actions/Secondary').icon = load('res://gui/sprites/buttons/special_' + ship.secondary.name.to_lower().replace(' ', '_') + '.png')
		else:
			get_node('GUIGrid/Actions/Secondary').text = 'Secondary'
			get_node('GUIGrid/Actions/Secondary').icon = load('res://gui/sprites/buttons/button_template.png')
		get_node('GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility').hint_tooltip = ship.secondary.desc
		get_node('GUIGrid/ShipInfo/AbilityInfo/PassiveAbility').text = 'Passive Ability: ' + ship.passive.name
		get_node('GUIGrid/ShipInfo/AbilityInfo/PassiveAbility').hint_tooltip = ship.passive.desc
		get_node('GUIGrid/ShipInfo/AbilityInfo/Drawbacks').text = 'Drawbacks: ' + ship.drawback.name
		get_node('GUIGrid/ShipInfo/AbilityInfo/Drawbacks').hint_tooltip = ship.drawback.desc
		# Update ActionInfo container
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipName').text = ship.ship_name
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipName').hint_tooltip = 'Weapon: ' + ship.weapon
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipIcon').texture = ship_icons[ship.ship_type]
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipIcon').modulate = Color(1, 1, 1, 1)
		get_node('GUIGrid/ShipInfo/ActionInfo/AP').text = 'AP: ' + str(ship.ap) + '/' + str(ship.default_ap)
	else:
		# Update AbilityInfo container
		get_node('GUIGrid/ShipInfo/AbilityInfo/SpecialAbility').text = 'Special Ability: '
		get_node('GUIGrid/ShipInfo/AbilityInfo/SpecialAbility').hint_tooltip = ''
		get_node('GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility').text = 'Secondary Ability: '
		get_node('GUIGrid/ShipInfo/AbilityInfo/SecondaryAbility').hint_tooltip = ''
		get_node('GUIGrid/ShipInfo/AbilityInfo/PassiveAbility').text = 'Passive Ability: '
		get_node('GUIGrid/ShipInfo/AbilityInfo/PassiveAbility').hint_tooltip = ''
		get_node('GUIGrid/ShipInfo/AbilityInfo/Drawbacks').text = 'Drawbacks: '
		get_node('GUIGrid/ShipInfo/AbilityInfo/Drawbacks').hint_tooltip = ''
		# Update ActionInfo container
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipName').text = ''
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipName').hint_tooltip = ''
		get_node('GUIGrid/ShipInfo/ActionInfo/ShipIcon').modulate = Color(1, 1, 1, 0)
		get_node('GUIGrid/ShipInfo/ActionInfo/AP').text = 'AP:     '
		# Update Actions buttons
		get_node('GUIGrid/Actions/Special').text = 'Special'
		get_node('GUIGrid/Actions/Secondary').text = 'Secondary'
		get_node('GUIGrid/Actions/Special').icon = load('res://gui/sprites/buttons/button_template.png')
		get_node('GUIGrid/Actions/Secondary').icon = load('res://gui/sprites/buttons/button_template.png')

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
