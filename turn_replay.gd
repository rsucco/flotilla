class_name TurnReplay
extends CanvasLayer
# Records a player's attacks during their turn and replays them for the
# opponent before the opponent's next turn, so hot-seat players see incoming
# fire as they would against an AI or network player. Attacks are replayed by
# stand-in "ghost" ships that run the real animations, while the recorded
# damage is shown as each attack lands instead of being resolved again.

signal finished
# A ship sunk last turn has just been shown going down
signal sinking_shown

# Waits this long at most for the last explosions and sinkings to finish
const SETTLE_TIMEOUT := 6.0
const BLAST_SCENE := preload("res://ships/projectiles/projectile.tscn")

var actions: Array[Action] = []
var recording: Action
var next_action := 0
var playing := false
var fast := false
var base_time_scale := 1.0
# Ghost ships and everything they add to Root while playing
var ghosts: Array[Ship] = []
var spawned: Array[Node] = []
# Set by Root: the board, and where attacks add their effects
var grid: Grid
var effects: Node2D
# Hidden over the attacker's side, so the replay gives away the angle of fire
# but not where the attacker's ships are
var masked: Array[Node2D] = []
var masking := false

@onready var speed: Button = $Bar/Row/Speed


# One attack and what it did to the defending fleet
class Action:
	extends RefCounted
	var player: Player
	var scene: String
	var position: Vector2
	var rotation: float
	var turrets := {}
	var props := {}
	var kind: String
	var target: Vector2i
	# Defender state just before the hit was resolved
	var smoke_before := {}
	var hp_before := {}
	var history_before := {}
	# What the hit changed
	var smoke: Array[CPUParticles2D] = []
	var hit_ships: Array[Ship] = []
	var hp_changes: Array[Array] = []
	var sunk: Array[Ship] = []
	var sounds: Array[Array] = []
	# Copies of the attacker's ship that the attack gave away (battery fire,
	# Sonar Pulse), shown from the start of its replay
	var revealed_before := 0
	var revealed: Array[Ship] = []


func _exit_tree() -> void:
	if playing:
		Engine.time_scale = base_time_scale


func has_actions() -> bool:
	return not actions.is_empty()


# Call before the attack's animation, while the ship is still where it fired from
func begin(ship: Ship, kind: String, target: Vector2i) -> void:
	recording = null
	# Only attacks on the opponent's side (not UNREP)
	if grid.side_of(target) != 1 - ship.player.player_num:
		return
	recording = Action.new()
	recording.player = ship.player
	recording.scene = ship.scene_file_path
	recording.position = ship.global_position
	recording.rotation = ship.global_rotation
	recording.kind = kind
	recording.target = target
	recording.revealed_before = ship.player.opponent.temp_revealed_ships.size()
	for child in ship.get_children():
		if child.name.begins_with("Turret"):
			recording.turrets[child.name] = (child as Node2D).rotation
	# Which turret or silo fires next, and whether it's shot down
	for prop in ["next_turret", "fore_silo", "intercepted"]:
		if prop in ship:
			recording.props[prop] = ship.get(prop)


# Call when the attacker moves onto one of the defender's mines
func mine_blast(hex: Vector2i, player: Player) -> void:
	var action := Action.new()
	action.player = player
	action.kind = "mine"
	action.target = hex
	actions.append(action)


# Call after the animation, just before the defender resolves the attack
func land() -> void:
	if recording == null:
		return
	var defender := recording.player.opponent
	for ship in defender.ships:
		recording.smoke_before[ship] = ship.smoke_nodes.size()
		if ship is CoastalBattery:
			recording.hp_before[ship] = (ship as CoastalBattery).hp
	for hex in _side_hexes(defender):
		recording.history_before[hex] = grid.tile(hex).history.size()


# Call once the defender has resolved the attack
func end() -> void:
	if recording == null:
		return
	var action := recording
	recording = null
	var defender := action.player.opponent
	for ship: Ship in action.smoke_before:
		var added := ship.smoke_nodes.slice(action.smoke_before[ship])
		action.smoke.append_array(added)
		if not added.is_empty():
			action.hit_ships.append(ship)
		if ship.sunk:
			action.sunk.append(ship)
			ship.held = true
	for battery: CoastalBattery in action.hp_before:
		if battery.hp != action.hp_before[battery]:
			action.hp_changes.append([battery, action.hp_before[battery], battery.hp])
			action.hit_ships.append(battery)
	# Sounds for outcomes that leave no mark on the board
	for hex in _side_hexes(defender):
		var history := grid.tile(hex).history
		for event: Array in history.slice(action.history_before[hex]):
			if event[1] == "Miss (Blocked by Armor)":
				action.sounds.append([defender.get_ship_at_hex(hex), Battleship.ARMOR_SOUND])
	action.revealed = defender.temp_revealed_ships.slice(action.revealed_before)
	actions.append(action)


# Plays the recorded attacks; returns when done or skipped
func play() -> void:
	if actions.is_empty():
		return
	playing = true
	next_action = 0
	base_time_scale = Engine.time_scale
	_set_fast(fast)
	$Bar/Row/Label.text = "Replay: Player " + str(actions[0].player.player_num + 1) + "'s turn"
	visible = true
	_rewind()
	effects.child_entered_tree.connect(_on_spawned)
	# Deferred so we're already waiting if every attack finishes instantly
	_run.call_deferred()
	await finished


# `player`'s ships sunk last turn that the replay hasn't shown sinking yet
func held_ships(player: Player) -> Array[Ship]:
	var held: Array[Ship] = []
	for action in actions:
		for ship in action.sunk:
			if is_instance_valid(ship) and ship.held and ship.player == player:
				held.append(ship)
	return held


# Forgets the recorded turn, freeing ships kept only to be shown sinking
func clear() -> void:
	for action in actions:
		for ship in action.sunk:
			if is_instance_valid(ship) and ship.held:
				ship.queue_free()
	actions.clear()


func _run() -> void:
	for action in actions:
		if action.kind == "mine":
			masking = false
			await _blast(action.target)
		else:
			var ghost := _make_ghost(action)
			for ship in action.revealed:
				if is_instance_valid(ship):
					action.player.opponent.show_revealed(ship)
			# No hiding where shots come from once the ship has given itself away
			masking = action.revealed.is_empty()
			match action.kind:
				"fire":
					await ghost.fire(action.target)
				"special":
					await ghost.use_special(action.target)
				"secondary":
					await ghost.use_secondary(action.target)
		if not playing:
			return
		_apply(action, true)
	# Let the last explosions, sinkings and aircraft finish
	var waited := 0.0
	while playing and _busy() and waited < SETTLE_TIMEOUT:
		waited += get_process_delta_time()
		await get_tree().process_frame
	if playing:
		_finish()


func _process(_delta: float) -> void:
	if not playing:
		return
	var defender := actions[0].player.opponent.player_num
	for node in masked:
		if is_instance_valid(node):
			# Torpedoes move along their own path rather than moving themselves
			var at := (
				(node as Torpedo).path_follow.global_position
				if node is Torpedo
				else node.global_position
			)
			# Shown over no-man's-land too, where missiles are shot down
			node.visible = not _over(1 - defender, at)
	for ghost in ghosts:
		if ghost is CoastalBattery:
			continue
		for child in ghost.get_children():
			if child is SH60 or child is F35:
				child.visible = _over(defender, child.path_follow.global_position)


func _over(player: int, at: Vector2) -> bool:
	return grid.side_of(grid.get_hex_from_coords(at)) == player


# The defender's mine going off under one of the attacker's ships
func _blast(hex: Vector2i) -> void:
	var blast: Projectile = BLAST_SCENE.instantiate()
	blast.grid = grid
	effects.add_child(blast)
	blast.dest_hex = hex
	blast.texture = null
	Sfx.play(blast, SH60.DROP_SOUND)
	await blast.boom(grid.get_hex_center(hex), false)
	blast.queue_free()


func _make_ghost(action: Action) -> Ship:
	var ghost: Ship = load(action.scene).instantiate()
	ghost.ghost = true
	action.player.adopt(ghost)
	ghost.global_position = action.position
	ghost.global_rotation = action.rotation
	for turret: String in action.turrets:
		(ghost.get_node(turret) as Node2D).rotation = action.turrets[turret]
	for prop: String in action.props:
		ghost.set(prop, action.props[prop])
	# Only its aircraft are seen; shots show where it fired from anyway
	ghost.self_modulate = Color.TRANSPARENT
	for child in ghost.get_children():
		if child is CanvasItem and not (child is SH60 or child is F35):
			child.visible = false
	ghosts.append(ghost)
	return ghost


# Puts the defender's fleet back as it was before the turn
func _rewind() -> void:
	var defender := actions[0].player.opponent
	for ship in defender.ships:
		ship.visible = true
		# Undo the opponent's reveals, which are faded
		ship.modulate = Color.WHITE
	# Backwards, so each battery ends up at its earliest HP
	for i in range(actions.size() - 1, -1, -1):
		var action := actions[i]
		for smoke in action.smoke:
			if is_instance_valid(smoke):
				smoke.visible = false
		for change in action.hp_changes:
			if is_instance_valid(change[0]):
				change[0].hp_bar.value = change[1]
		for ship in action.sunk:
			if is_instance_valid(ship):
				ship.visible = true
				ship.modulate = Color.WHITE


# Shows what an attack did; with `animate` false, just the end result
func _apply(action: Action, animate: bool) -> void:
	next_action += 1
	for smoke in action.smoke:
		if is_instance_valid(smoke):
			smoke.visible = true
	for change in action.hp_changes:
		if is_instance_valid(change[0]):
			change[0].hp_bar.value = change[2]
	for ship in action.sunk:
		if not is_instance_valid(ship):
			continue
		if animate:
			_sink(ship)
		else:
			ship.queue_free()
	if not animate:
		return
	for ship in action.hit_ships:
		if is_instance_valid(ship) and not action.sunk.has(ship):
			Sfx.play(ship, ship.hit_sound)
	for sound in action.sounds:
		if is_instance_valid(sound[0]):
			Sfx.play(sound[0], sound[1])


# Frees the ship once its sound has finished too, which may be after the replay
func _sink(ship: Ship) -> void:
	ship.held = false
	sinking_shown.emit()
	await ship.sink_effect()
	ship.queue_free()


func _busy() -> bool:
	# Ships still fading out
	for action in actions.slice(0, next_action):
		for ship in action.sunk:
			if is_instance_valid(ship) and ship.visible:
				return true
	for node in spawned:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return true
	for ghost in ghosts:
		for child in ghost.get_children():
			if (child is SH60 or child is F35) and child.flying:
				return true
			if child is AudioStreamPlayer2D and child.playing:
				return true
	return false


func _finish() -> void:
	playing = false
	Engine.time_scale = base_time_scale
	effects.child_entered_tree.disconnect(_on_spawned)
	# If skipped, drop whatever is still in flight and jump to the end result
	for node in spawned:
		if is_instance_valid(node):
			node.queue_free()
	spawned.clear()
	masked.clear()
	for ghost in ghosts:
		ghost.queue_free()
	ghosts.clear()
	while next_action < actions.size():
		_apply(actions[next_action], false)
	for action in actions:
		for ship in action.sunk:
			if is_instance_valid(ship):
				ship.visible = false
	visible = false
	finished.emit()


func _set_fast(value: bool) -> void:
	fast = value
	Engine.time_scale = base_time_scale * (2.0 if fast else 1.0)
	speed.text = "Speed: 2x" if fast else "Speed: 1x"


func _side_hexes(player: Player) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for x: int in grid.columns_of(player.player_num):
		for y in Grid.ROWS:
			hexes.append(Vector2i(x, y))
	return hexes


func _on_spawned(node: Node) -> void:
	spawned.append(node)
	if masking and node is Node2D:
		masked.append(node)
		# Hidden until _process has checked where it is
		node.visible = false


func _on_speed_pressed() -> void:
	_set_fast(not fast)


func _on_skip_pressed() -> void:
	if playing:
		_finish()
