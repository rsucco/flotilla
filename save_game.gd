class_name SaveGame
# Saved games: an autosave written at every hand-off, plus three slots the
# players save to from the Esc menu. Each is one file in user:// (on Web, the
# browser's storage), written with store_var and read back without objects.
# Root decides what goes in a save; this turns ships to and from plain data.

# Bumped when a save's contents change, so older saves read as empty rather
# than half-load (2: the turn replay, held ships and the mode; 3: ship names)
const VERSION := 3
const AUTOSAVE := "autosave"
const SLOTS: Array[String] = ["slot1", "slot2", "slot3"]
# Shown to players
const NAMES := {"autosave": "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}

static var dir := "user://saves"


static func path(slot: String) -> String:
	return dir.path_join(slot + ".save")


static func write(slot: String, data: Dictionary) -> void:
	data.version = VERSION
	data.saved_at = Time.get_unix_time_from_system()
	_store(slot, data)


static func _store(slot: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Couldn't save to " + path(slot))
		return
	file.store_var(data)


# The save in `slot`, or {} if there's none (or it's from another version)
static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var file := FileAccess.open(path(slot), FileAccess.READ)
	if file == null:
		return {}
	# store_var() starts with the data's length: a file that doesn't match is
	# damaged, and would make get_var() complain
	if file.get_length() < 4 or file.get_32() != file.get_length() - 4:
		return {}
	file.seek(0)
	var data: Variant = file.get_var(false)
	if not data is Dictionary or data.get("version") != VERSION:
		return {}
	return data


static func delete(slot: String) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(path(slot))


# Marks the slots saved from `game` as finished, keeping when they were saved.
# They can still be loaded, but aren't continued.
static func mark_finished(game: int) -> void:
	for slot in SLOTS:
		var data := read(slot)
		if data.get("game") == game:
			data.finished = true
			_store(slot, data)


# The most recently saved slot of a game still in play, autosave included, or
# "" if there are none
static func latest() -> String:
	var newest := ""
	var newest_at := -1.0
	for slot in [AUTOSAVE] + SLOTS:
		var data := read(slot)
		if not data.is_empty() and not data.get("finished") and data.saved_at > newest_at:
			newest = slot
			newest_at = data.saved_at
	return newest


# e.g. "Slot 1: Hot-seat, Turn 4, Player 2 - 2026-10-31 21:04", "Slot 1: vs AI,
# Turn 4 - ...", "Slot 1: Empty", or with " (finished)" after a finished game
static func describe(slot: String) -> String:
	var data := read(slot)
	if data.is_empty():
		return NAMES[slot] + ": Empty"
	var bias: int = Time.get_time_zone_from_system().bias * 60
	var when := Time.get_datetime_string_from_unix_time(int(data.saved_at) + bias, true)
	var game := "Hot-seat, Turn %d, Player %d" % [data.turn, data.player_up + 1]
	if data.mode == Root.Mode.VS_AI:
		game = "vs AI, Turn %d" % data.turn
	var text := "%s: %s - %s" % [NAMES[slot], game, when.left(16)]
	return text + " (finished)" if data.get("finished") else text


static func ship_state(ship: Ship) -> Dictionary:
	var state := {
		"scene": ship.scene_file_path,
		"title": ship.title,
		"hex": ship.hex,
		"direction": ship.direction,
		"hit_hexes": ship.hit_hexes.duplicate(),
		"ap": ship.ap,
		"fire_remaining": ship.fire_remaining,
		"special": ship.special.cooldown_current,
		"secondary": ship.secondary.cooldown_current,
		"jammed": ship.jammed,
		# Whether the opponent can see it (revealed this turn)
		"shown": ship.visible,
		# Where its guns were last aimed
		"turrets": {},
	}
	for child in ship.get_children():
		if child.name.begins_with("Turret"):
			state.turrets[child.name] = (child as Node2D).rotation
	if ship is CoastalBattery:
		state.hp = (ship as CoastalBattery).hp
	elif ship is SupplyTender:
		state.dc_timer = (ship as SupplyTender).dc_timer
	elif ship is Cruiser:
		state.fore_silo = (ship as Cruiser).fore_silo
	elif ship is Battleship:
		state.next_turret = (ship as Battleship).next_turret
	return state


# Makes a ship from `state` for `player`, which adopts it
static func restore_ship(state: Dictionary, player: Player) -> Ship:
	var ship: Ship = load(state.scene).instantiate()
	ship.title = state.title
	player.adopt(ship)
	ship.set_grid_position(state.hex, state.direction)
	ship.hit_hexes.assign(state.hit_hexes)
	for index in ship.hit_hexes.size():
		if ship.hit_hexes[index]:
			ship._add_smoke(index)
	ship.ap = state.ap
	ship.fire_remaining = state.fire_remaining
	ship.special.cooldown_current = state.special
	ship.secondary.cooldown_current = state.secondary
	ship.jammed = state.jammed
	for turret: String in state.turrets:
		(ship.get_node(turret) as Node2D).rotation = state.turrets[turret]
	if ship is CoastalBattery:
		var battery := ship as CoastalBattery
		battery.hp = state.hp
		battery.hp_bar.value = battery.hp
	elif ship is SupplyTender:
		(ship as SupplyTender).dc_timer = state.dc_timer
	elif ship is Cruiser:
		(ship as Cruiser).fore_silo = state.fore_silo
	elif ship is Battleship:
		(ship as Battleship).next_turret = state.next_turret
	return ship


# A copy of a ship that gave itself away (a battery firing, a sub's Sonar
# Pulse), as shown to the other player. Copies are only for show, and made by
# duplicate(), which keeps their position but not script variables like hex.
static func revealed_state(copy: Ship) -> Dictionary:
	var state := {
		"scene": copy.scene_file_path, "position": copy.position, "rotation": copy.rotation
	}
	if copy.has_node("Turret"):
		state.turret = (copy.get_node("Turret") as Node2D).rotation
	return state


# Remade outside the tree, as the original copies are: the player adopts it
# when showing it
static func restore_revealed(state: Dictionary) -> Ship:
	var copy: Ship = load(state.scene).instantiate()
	copy.position = state.position
	copy.rotation = state.rotation
	if state.has("turret"):
		(copy.get_node("Turret") as Node2D).rotation = state.turret
	return copy
