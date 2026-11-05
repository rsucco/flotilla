class_name Ship
extends Sprite2D

signal placed
signal sank
# Set off a mine at `hex`
signal mine_hit(hex: Vector2i)

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
# Two taps on a hex this close together are a double tap (Android's timeout)
const DOUBLE_TAP_MS := 300
# Placing, each scroll turns us once: a wheel's notch, or a trackpad's whole
# swipe, momentum and all. A swipe comes as a stream of small wheel events
# (Windows) or pan gestures (macOS, which sends a trackpad no wheel events),
# so a scroll ends after this long without any (ms). A pan must go this far
# first, so a resting finger doesn't turn us.
const SCROLL_PAUSE_MS := 150
const PAN_TURN := 0.5

var hit_sound: AudioStream = preload("res://audio/water_hit1.wav")
var sink_sound: AudioStream = preload("res://audio/ship_destroyed.wav")
# The sinking recordings are quieter than the other effects
var sink_volume_db := 4.0
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
# This ship's own name, given by Player.adopt()
var title := ""
var weapon := ""
var hit_hexes: Array[bool] = []
# By the index of the hex it burns on
var smoke_nodes: Dictionary[int, CPUParticles2D] = {}
var special := SpecialAbility.new()
var secondary := SpecialAbility.new()
var passive := PassiveAbility.new()
var drawback := Drawback.new()
var placing := false
var moves_queued := 0
# The water we've left behind us, while it's still there
var wake: Wake
var revealed_buddy: Ship
var sunk := false
# How sinking is logged in tile history
var sunk_event := "Sunk"
# A stand-in that replays this ship's attacks for the opponent (TurnReplay)
var ghost := false
# Kept (hidden) after sinking until the opponent's turn replay has shown it
var held := false
# While the AI's turn plays out live: the hull and everything on it is unseen,
# except aircraft (TurnReplay masks what it fires), and it moves silently
var cloaked := false:
	set(value):
		cloaked = value
		self_modulate = Color.TRANSPARENT if value else Color.WHITE
		if value:
			for child in get_children():
				if child is CanvasItem and child.visible and not (child is SH60 or child is F35):
					child.visible = false
					_cloaked_children.append(child)
		else:
			for child in _cloaked_children:
				if is_instance_valid(child):
					child.visible = true
			_cloaked_children.clear()
# Set by EW Strike; blocks firing on the ship's next turn
var jammed := false
# Jammed for the turn under way, so it can't fire (shown to the player)
var jammed_this_turn := false
# Set as each attack starts: whether the opponent's cruisers will shoot it down
var intercepted := false
# Where the cruiser shooting it down is
var ciws_at := Vector2.INF
# Set by the player that adopts the ship
var player: Player
var grid: Grid
# Where projectiles and other effects go
var effects: Node2D
var movement_audio_player: AudioStreamPlayer2D
# What cloaking hid, to show again
var _cloaked_children: Array[CanvasItem] = []
# The last tap while placing: when, where, and how far it turned us
var _tapped_at := -DOUBLE_TAP_MS
var _tapped_hex := UNPLACED
var _tap_turn := 0
# The scroll under way: when it was last moved, how far it's gone, and
# whether it's turned us yet
var _scrolled_at := -SCROLL_PAUSE_MS
var _scrolled := 0.0
var _scroll_turned := false


# Subclasses must call super() first
func _ready() -> void:
	# Created here rather than as a member default so revealed copies that are
	# freed before entering the tree don't leak it
	movement_audio_player = Sfx.new_player()
	add_child(movement_audio_player)


func _input(event: InputEvent) -> void:
	if not placing:
		return
	if event is InputEventMouseMotion:
		var mouse_hex := grid.get_hex_from_coords(event.position)
		if can_place(mouse_hex, direction):
			set_grid_position(mouse_hex, direction)
			visible = true
	elif event is InputEventPanGesture:
		_scroll((event as InputEventPanGesture).delta.y, PAN_TURN)
	elif HexCursor.presses(event, "action_port"):
		turn_by(-60)
	elif HexCursor.presses(event, "action_starboard"):
		turn_by(60)
	elif event.is_action_pressed("action_confirm") or event.is_action_pressed("action_fire"):
		# The keyboard and controller's click, at the HexCursor
		if hex != UNPLACED:
			placing = false
			placed.emit()
	elif event is InputEventMouseButton and event.pressed:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			_tap(grid.get_hex_from_coords(event.position))
			return
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll(-1.0, 0.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(1.0, 0.0)
			MOUSE_BUTTON_LEFT:
				if hex != UNPLACED:
					placing = false
					placed.emit()


# Scrolled `by` (up negative) while placing: the first time this scroll has
# gone `far` enough, we turn that way
func _scroll(by: float, far: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _scrolled_at > SCROLL_PAUSE_MS:
		_scrolled = 0.0
		_scroll_turned = false
	_scrolled_at = now
	_scrolled += by
	if not _scroll_turned and absf(_scrolled) > far:
		_scroll_turned = true
		turn_by(60 if _scrolled > 0.0 else -60)


# Placing by touch, which has no hover or wheel: a tap moves us there, a tap
# on us turns us, and a double tap places us. Touch sends no motion before a
# tap, and not every platform flags double taps, so we time them ourselves.
func _tap(at: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	if at == _tapped_hex and now - _tapped_at < DOUBLE_TAP_MS and hex != UNPLACED:
		# The first tap of the two wasn't meant to turn us
		if _tap_turn != 0:
			turn_by(-_tap_turn)
		placing = false
		placed.emit()
		return
	_tapped_at = now
	_tapped_hex = at
	_tap_turn = 0
	if get_occupied_hexes().has(at):
		var before := direction
		turn_by(60)
		_tap_turn = direction - before
	elif can_place(at, direction):
		set_grid_position(at, direction)
		visible = true


# Whether we can be placed for the start of the game centred on `at`, facing
# `dir`: on our side, all on the board, all on water (land for coastal
# batteries), and clear of our other ships
func can_place(at: Vector2i, dir: int) -> bool:
	if grid.side_of(at) != player.player_num:
		return false
	var hexes := hexes_at(at, dir)
	if hexes.has(Grid.OFF_GRID):
		return false
	for h in hexes:
		var other := player.get_ship_at_hex(h)
		if (
			grid.tile(h).island != (ship_type == "coastal_battery")
			or (other != null and other != self)
		):
			return false
	return true


func set_grid_position(new_hex: Vector2i, new_direction: int) -> void:
	direction = new_direction
	rotation_degrees = direction
	hex = new_hex
	position = grid.get_hex_center(hex)


func get_occupied_hexes() -> Array[Vector2i]:
	return hexes_at(hex, direction)


# Hexes the ship would occupy centered on `center` facing `dir`, ordered
# stern to bow (the center hex is at index len_aft). Out-of-bounds hexes
# appear as Grid.OFF_GRID.
func hexes_at(center: Vector2i, dir: int) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	var h := center
	for _i in len_aft:
		h = grid.get_hex_neighbor(h, dir + 180)
		hexes.push_front(h)
	hexes.append(center)
	h = center
	for _i in len_fore:
		h = grid.get_hex_neighbor(h, dir)
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
	# Hidden until the mouse finds a valid spot, or it shows at the origin
	visible = false
	placing = true


# Adds an effect (projectile, pulse...) to the board, giving projectiles the grid
func spawn(effect: Node2D) -> void:
	if effect is Projectile:
		(effect as Projectile).grid = grid
	effects.add_child(effect)


# How tile history names us: "Exeter (Destroyer)", with any `note` alongside
# the type
func called(note := "") -> String:
	var about := PackedStringArray()
	# Batteries are named for what they are
	if not title.begins_with(ship_name):
		about.append(ship_name)
	if not note.is_empty():
		about.append(note)
	return title if about.is_empty() else title + " (" + ", ".join(about) + ")"


func hit(hit_hex: Vector2i, _from_ship: Ship) -> void:
	var index := get_occupied_hexes().find(hit_hex)
	# Don't count hits on already hit hexes (maybe rework this if it's unfun)
	if hit_hexes[index]:
		grid.log_event(hit_hex, "Hit, " + called("No effect"))
		return
	hit_hexes[index] = true
	grid.log_event(hit_hex, "Hit, " + called())
	_add_smoke(index)
	if not hit_hexes.has(false):
		sink()
	else:
		Sfx.play(self, hit_sound)


func _add_smoke(index: int) -> void:
	# Burning where it was hit, its smoke trailing downwind
	var smoke := Explosion.burning(_get_size())
	smoke.position.y -= grid.hex_size * (index - len_aft)
	if len_fore == 0:
		smoke.position.y -= 10
	elif len_fore == 2:
		if index == 0:
			smoke.position.y -= 10
		elif index == 4:
			smoke.position.y += 15
	smoke_nodes[index] = smoke
	add_child(smoke)
	if cloaked:
		smoke.visible = false
		_cloaked_children.append(smoke)


func sink() -> void:
	if sunk:
		return
	sunk = true
	if is_instance_valid(revealed_buddy):
		revealed_buddy.queue_free()
	for h in get_occupied_hexes():
		grid.log_event(h, sunk_event + ", " + called())
	sank.emit()
	await sink_effect()
	if not held:
		queue_free()


# A copy of us for the opponent to see where we gave ourselves away: not
# cloaked, even if we are
func copy_as_seen() -> Ship:
	var copy: Ship = duplicate()
	copy.title = title
	copy.self_modulate = Color.WHITE
	for child in _cloaked_children:
		# Smoke freed since (repaired) has nothing to show
		if not is_instance_valid(child):
			continue
		# Children added at runtime (smoke, say) aren't duplicated
		var copied := copy.get_node_or_null(get_path_to(child))
		if copied != null:
			copied.visible = true
	return copy


# Wrecked (see _wreck()), then settles and fades into a spreading slick, with
# the sinking sound; returns when both are done
func sink_effect() -> void:
	var sound := Sfx.play(self, sink_sound)
	sound.volume_db = sink_volume_db
	# Make visible to the opponent while it sinks
	visible = true
	# (Tests sink ships that have no effects layer)
	var tween := create_tween().set_parallel()
	if effects != null:
		_wreck(tween)
		_slick()
	(
		tween
		. tween_property(self, "modulate", Color(0.2, 0.25, 0.3, 0.0), 3.0)
		. from(Color.WHITE)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(self, "scale", scale * 0.85, 3.0)
	await tween.finished
	visible = false
	if is_instance_valid(sound) and sound.playing:
		await sound.finished


# Rotates by a multiple of 60 degrees if the new position is clear
func turn_by(offset: int) -> void:
	var hexes := hexes_at(hex, direction + offset)
	if hexes.has(Grid.OFF_GRID) or not Helm.is_clear(self, hexes):
		return
	direction += offset
	await _animate_move("rotation_degrees", direction, 1.0)


# Plays the movement sound and leaves a wake for the duration of a (possibly
# overlapping) move
func _animate_move(property: String, target: Variant, duration: float) -> void:
	moves_queued += 1
	if not movement_audio_player.playing and not cloaked:
		# Here rather than at placement, which loaded ships skip
		movement_audio_player.stream = move_sound
		movement_audio_player.play()
	# Only where the viewer can see us: a wake would give away a cloaked ship
	# (the AI's or the other LAN player's, mid-turn) or a hidden one. Not while
	# being placed, either: we aren't under way yet.
	var trail: Wake = (
		_make_wake() if visible and not cloaked and not ghost and not placing else null
	)
	if trail != null:
		trail.moving = true
	var tween := create_tween()
	tween.tween_property(self, property, target, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await tween.finished
	moves_queued -= 1
	if trail != null and moves_queued == 0:
		# What's already in the water fades out on its own
		trail.moving = false
	if moves_queued == 0:
		movement_audio_player.stop()


# Going up in a blast, with smaller ones along the hull, one after another on
# the sinking's `tween`
func _wreck(tween: Tween) -> void:
	Explosion.blast(effects, effects.to_local(global_position), 1.6)
	# A visual shuffle: the global generator, not the rules' dice
	var along := get_occupied_hexes()
	along.shuffle()
	for i in mini(along.size(), 3):
		if along[i] != Grid.OFF_GRID:
			var at := effects.to_local(grid.get_hex_center(along[i]))
			tween.tween_callback(_secondary_blast.bind(at)).set_delay(0.35 + 0.4 * i)


# One of the smaller explosions along the hull as we go down
func _secondary_blast(at: Vector2) -> void:
	Explosion.blast(effects, at, 0.7)


# Oil and debris spreading where we went down, then fading
func _slick() -> void:
	var slick := Sprite2D.new()
	slick.texture = Explosion.SMOKE_TEXTURE
	slick.modulate = Color(0.05, 0.07, 0.08, 0.6)
	slick.position = effects.to_local(global_position)
	slick.scale = Vector2.ONE * 0.04 * _get_size()
	effects.add_child(slick)
	# Under the fire and smoke
	effects.move_child(slick, 0)
	var spread := slick.create_tween().set_parallel()
	spread.tween_property(slick, "scale", slick.scale * 2.2, 6.0).set_ease(Tween.EASE_OUT)
	spread.tween_property(slick, "modulate:a", 0.0, 6.0).set_ease(Tween.EASE_IN)
	spread.chain().tween_callback(slick.queue_free)


# Our wake, carried on from move to move until it's faded
func _make_wake() -> Wake:
	if is_instance_valid(wake):
		return wake
	wake = Wake.new()
	wake.show_behind_parent = true
	# The sprite points up (-y), so its stern is the bottom of its rect
	wake.stern = Vector2(0, get_rect().end.y - 6)
	wake.beam = get_rect().size.x * global_scale.x / 2
	add_child(wake)
	return wake


# True if moving one hex forward (or back) is in bounds, clear, affordable,
# and the ship isn't too damaged
func can_move(reverse: bool = false) -> bool:
	if is_immobilized():
		return false
	if ap < 1 or (reverse and ap < 4):
		return false
	var new_hex := grid.get_hex_neighbor(hex, direction + (180 if reverse else 0))
	var hexes := hexes_at(new_hex, direction)
	return not hexes.has(Grid.OFF_GRID) and Helm.is_clear(self, hexes)


func can_rotate(offset: int) -> bool:
	if is_immobilized() or ap < 2:
		return false
	var hexes := hexes_at(hex, direction + offset)
	return not hexes.has(Grid.OFF_GRID) and Helm.is_clear(self, hexes)


# 2 AP and 1 fire action required to fire
func can_fire(_target: Vector2i = Vector2i.ZERO) -> bool:
	return ap >= 2 and fire_remaining >= 1


func can_special() -> bool:
	return special.desc != "" and special.cooldown_current == 0 and ap >= 2


func can_secondary() -> bool:
	return secondary.desc != "" and secondary.cooldown_current == 0 and ap >= 2


func forward() -> void:
	hex = grid.get_hex_neighbor(hex, direction)
	ap -= 1
	check_for_mine()
	await _animate_move("position", grid.get_hex_center(hex), 1.5)


func reverse() -> void:
	hex = grid.get_hex_neighbor(hex, direction + 180)
	ap -= 4
	check_for_mine()
	await _animate_move("position", grid.get_hex_center(hex), 2.0)


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
		var tile := grid.tile(h)
		if tile.is_mined:
			tile.is_mined = false
			mine_hit.emit(h)
			# A random hex takes the hit (no effect if it's already damaged)
			hit(grid.dice.pick(get_occupied_hexes()), self)


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
	for smoke in smoke_nodes.values():
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
