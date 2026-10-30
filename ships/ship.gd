class_name Ship
extends Sprite2D

signal placed

const SHIP_TYPES: Array[String] = [
	"coastal_battery",
	"corvette",
	"destroyer",
	"submarine",
	"cruiser",
	"supply_tender",
	"battleship",
	"carrier"
]
const UNPLACED := Vector2i(-10, -10)

var hit_sound: AudioStream = preload("res://audio/water_hit1.wav")
var sink_sound: AudioStream = preload("res://audio/ship_destroyed.wav")
var move_sound: AudioStream
var hex := UNPLACED
var direction := 0
var default_ap := 4
var ap := 0
var fire_remaining := 0
var len_fore: int
var len_aft: int
var ship_type := ""
var ship_name := ""
var weapon := ""
var hit_hexes: Array[bool] = []
var smoke_nodes: Array[CPUParticles2D] = []
var special := SpecialAbility.new()
var secondary := SpecialAbility.new()
var passive := PassiveAbility.new()
var drawback := Drawback.new()
var placing := false
var moves_queued := 0
var revealed_buddy: Ship
var sunk := false
# Set by EW Strike; blocks firing on the ship's next turn
var jammed := false
var root: Root
var player: Player
var movement_audio_player: AudioStreamPlayer2D


# Subclasses must call super() first
func _ready() -> void:
	player = get_parent()
	root = player.get_parent()
	# Created here rather than as a member default so revealed copies that are
	# freed before entering the tree don't leak it
	movement_audio_player = AudioStreamPlayer2D.new()
	add_child(movement_audio_player)


func _input(event: InputEvent) -> void:
	if not placing:
		return
	if event is InputEventMouseMotion:
		var mouse_hex := root.grid.get_hex_from_coords(event.position)
		var hexes := _get_hexes_at(mouse_hex, direction)
		var any_land := false
		var occupied := false
		for h in hexes:
			if h == Grid.OFF_GRID:
				continue
			if root.grid.tile(h).island:
				any_land = true
			if root.get_ship_at_hex(h) != null:
				occupied = true
		# Coastal batteries go on land instead of water
		if ship_type == "coastal_battery":
			any_land = not any_land
		if (
			not hexes.has(Grid.OFF_GRID)
			and not any_land
			and not occupied
			and root.grid.side_of(mouse_hex) == player.player_num
		):
			set_grid_position(mouse_hex, direction)
			visible = true
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				turn_by(-60)
			MOUSE_BUTTON_WHEEL_DOWN:
				turn_by(60)
			MOUSE_BUTTON_LEFT:
				if hex != UNPLACED:
					placing = false
					placed.emit()


func set_grid_position(new_hex: Vector2i, new_direction: int) -> void:
	direction = new_direction
	rotation_degrees = direction
	hex = new_hex
	position = root.grid.get_hex_center(hex)


func get_occupied_hexes() -> Array[Vector2i]:
	return _get_hexes_at(hex, direction)


# Hexes the ship would occupy centered on `center` facing `dir`, ordered
# stern to bow (the center hex is at index len_aft). Out-of-bounds hexes
# appear as Grid.OFF_GRID.
func _get_hexes_at(center: Vector2i, dir: int) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	var h := center
	for _i in len_aft:
		h = root.grid.get_hex_neighbor(h, dir + 180)
		hexes.push_front(h)
	hexes.append(center)
	h = center
	for _i in len_fore:
		h = root.grid.get_hex_neighbor(h, dir)
		hexes.append(h)
	return hexes


func _get_size() -> int:
	return len_aft + len_fore + 1


# More than 50% damaged
func is_immobilized() -> bool:
	return hit_hexes.count(true) * 2 > hit_hexes.size()


func is_hex_hit(h: Vector2i) -> bool:
	return hit_hexes[get_occupied_hexes().find(h)]


func new_turn() -> void:
	modulate = Color.WHITE
	ap = default_ap
	fire_remaining = 1
	if special.cooldown_current > 0:
		special.cooldown_current -= 1
	if secondary.cooldown_current > 0:
		secondary.cooldown_current -= 1


func place() -> void:
	movement_audio_player.stream = move_sound
	# Hidden until the mouse finds a valid spot, or it shows at the origin
	visible = false
	placing = true


func log_event(h: Vector2i, event: String) -> void:
	root.grid.tile(h).history.append([root.current_turn, event])


func hit(hit_hex: Vector2i, _from_ship: Ship) -> void:
	var index := get_occupied_hexes().find(hit_hex)
	# Don't count hits on already hit hexes (maybe rework this if it's unfun)
	if hit_hexes[index]:
		log_event(hit_hex, "Hit, " + ship_name + " (No effect)")
		return
	hit_hexes[index] = true
	if is_immobilized():
		log_event(hit_hex, "Hit, " + ship_name + " (Immobilized)")
	else:
		log_event(hit_hex, "Hit, " + ship_name)
	_add_smoke(index)
	if not hit_hexes.has(false):
		sink()
	else:
		Sfx.play(self, hit_sound)


func _add_smoke(index: int) -> void:
	var smoke := CPUParticles2D.new()
	smoke.local_coords = true
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	smoke.emission_ring_radius = _get_size() * 3 - 3
	smoke.direction = Vector2.LEFT
	smoke.gravity = Vector2(0, 150)
	smoke.spread = 25.0
	smoke.scale_amount_min = 2.5
	smoke.scale_amount_max = 2.5
	smoke.color = Color.BLACK
	smoke.amount = _get_size() ** 2 * 10
	smoke.lifetime = 0.5
	smoke.position.y -= root.grid.hex_size * (index - len_aft)
	if len_fore == 0:
		smoke.position.y -= 10
	elif len_fore == 2:
		if index == 0:
			smoke.position.y -= 10
		elif index == 4:
			smoke.position.y += 15
	smoke_nodes.append(smoke)
	add_child(smoke)


func sink() -> void:
	if sunk:
		return
	sunk = true
	if is_instance_valid(revealed_buddy):
		revealed_buddy.queue_free()
	var sound := Sfx.play(self, sink_sound)
	# Make visible to the opponent while it sinks
	visible = true
	for h in get_occupied_hexes():
		log_event(h, "Sunk, " + ship_name)
	player.ships.erase(self)
	root.gui.update_fleets()
	var tween := create_tween()
	(
		tween
		. tween_property(self, "modulate", Color(0.0, 0.5, 0.62, 0.5), 3.0)
		. from(Color.WHITE)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await tween.finished
	visible = false
	if sound.playing:
		await sound.finished
	queue_free()


# Rotates by a multiple of 60 degrees if the new position is clear
func turn_by(offset: int) -> void:
	var hexes := _get_hexes_at(hex, direction + offset)
	if hexes.has(Grid.OFF_GRID) or not _is_clear(hexes):
		return
	direction += offset
	await _animate_move("rotation_degrees", direction, 1.0)


# Plays the movement sound for the duration of a (possibly overlapping) move
func _animate_move(property: String, target: Variant, duration: float) -> void:
	moves_queued += 1
	if not movement_audio_player.playing:
		movement_audio_player.play()
	var tween := create_tween()
	tween.tween_property(self, property, target, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await tween.finished
	moves_queued -= 1
	if moves_queued == 0:
		movement_audio_player.stop()


# True if none of the hexes are land or occupied by another ship
func _is_clear(hexes: Array[Vector2i]) -> bool:
	for h in hexes:
		var other := root.get_ship_at_hex(h)
		if root.grid.tile(h).island or (other != null and other != self):
			return false
	return true


# True if moving one hex forward (or back) is in bounds, clear, affordable,
# and the ship isn't too damaged
func can_move(reverse: bool = false) -> bool:
	if is_immobilized():
		return false
	if ap < 1 or (reverse and ap < 4):
		return false
	var new_hex := root.grid.get_hex_neighbor(hex, direction + (180 if reverse else 0))
	var hexes := _get_hexes_at(new_hex, direction)
	return not hexes.has(Grid.OFF_GRID) and _is_clear(hexes)


func can_rotate(offset: int) -> bool:
	if is_immobilized() or ap < 2:
		return false
	var hexes := _get_hexes_at(hex, direction + offset)
	return not hexes.has(Grid.OFF_GRID) and _is_clear(hexes)


# 2 AP and 1 fire action required to fire
func can_fire(_target: Vector2i = Vector2i.ZERO) -> bool:
	return ap >= 2 and fire_remaining >= 1


func can_special() -> bool:
	return special.desc != "" and special.cooldown_current == 0 and ap >= 2


func can_secondary() -> bool:
	return secondary.desc != "" and secondary.cooldown_current == 0 and ap >= 2


func forward() -> void:
	hex = root.grid.get_hex_neighbor(hex, direction)
	ap -= 1
	check_for_mine()
	await _animate_move("position", root.grid.get_hex_center(hex), 1.5)


func reverse() -> void:
	hex = root.grid.get_hex_neighbor(hex, direction + 180)
	ap -= 4
	check_for_mine()
	await _animate_move("position", root.grid.get_hex_center(hex), 2.0)


func port() -> void:
	turn_by(-60)
	ap -= 2
	check_for_mine()


func starboard() -> void:
	turn_by(60)
	ap -= 2
	check_for_mine()


func check_for_mine() -> void:
	for h in get_occupied_hexes():
		var tile := root.grid.tile(h)
		if tile.is_mined:
			tile.is_mined = false
			# A random hex takes the hit (no effect if it's already damaged)
			hit(get_occupied_hexes().pick_random(), self)


# fire/use_special/use_secondary are awaited by the caller until their
# animation finishes. Subclasses call super() first, then animate.
func fire(_target: Vector2i) -> void:
	ap -= 2
	fire_remaining -= 1


func use_special(_target: Vector2i) -> void:
	ap -= 2
	special.cooldown_current = special.cooldown_interval


func use_secondary(_target: Vector2i) -> void:
	ap -= 2
	secondary.cooldown_current = secondary.cooldown_interval


func heal() -> void:
	hit_hexes.fill(false)
	for smoke in smoke_nodes:
		smoke.queue_free()
	smoke_nodes.clear()


# Rotates a turret to face a point, taking the shortest way around
func aim_turret(turret: Node2D, target: Vector2, duration: float) -> void:
	# Turret sprites point up (-y), so add 90 degrees to the direction angle
	var angle := turret.global_position.direction_to(target).angle() + PI / 2
	var shortest := turret.global_rotation + wrapf(angle - turret.global_rotation, -PI, PI)
	var tween := create_tween()
	(
		tween
		. tween_property(turret, "global_rotation", shortest, duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await tween.finished
