class_name Root
extends Node2D

# Who's playing: LAN and online play will join these
enum Mode { HOT_SEAT, VS_AI }

const ROW_LABELS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"]
const FONT_SIZE := 11
const FONT := preload("res://opensans.ttf")
const MINE_TEXTURE := preload("res://ships/sprites/projectiles/mine.png")
const HITMISS_TEXTURE := preload("res://gui/sprites/hitmiss.png")
const TURN_SWAP_SCENE := preload("res://gui/local_turn_swap.tscn")
const VICTORY_SCENE := preload("res://gui/victory.tscn")
const MUSIC_FADE := 2.0

# Set by the title screen before loading us
static var mode := Mode.HOT_SEAT
# "Replay This Game" keeps the board and both fleets across a scene reload
static var replay := {}
# Where the title screen's music was, so it carries on through setup
static var title_music_at := 0.0
# A saved game to carry on with, set by the title screen before loading us
static var loaded := {}

var grid: Grid
var players: Array[Player] = []
# Two players taking turns at one screen, rather than one against the AI
var hot_seat := true
var player_up := 0
# Projectiles and other effects, drawn above the ships
var effects: Node2D
# Above the ships and effects: the hovered hex's coordinate, which they may cover
var hover_label: Node2D
var current_turn := 0
var swapping := false
# The ship selection dialog is up
var choosing := false
# The board and fleets this game started with, once both players have chosen
var setup := {}
# Tells this game's saves from others', to mark them finished when it ends.
# A replay is a new game.
var game_id := 0
# Testing cheats (debug builds): V shows both fleets, C readies every ability
# of the player whose turn it is
var reveal_all := false

@onready var gui: GUI = $GUI
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var turn_replay: TurnReplay = $TurnReplay


func _ready() -> void:
	effects = Node2D.new()
	effects.name = "Effects"
	# A saved game brings its own
	if not loaded.is_empty():
		mode = loaded.mode
	hot_seat = mode == Mode.HOT_SEAT
	var second: Player = LocalPlayer.new(1) if hot_seat else AIPlayer.new(1)
	players = [LocalPlayer.new(0), second]
	players[0].opponent = players[1]
	players[1].opponent = players[0]
	for player in players:
		player.effects = effects
		add_child(player)
		if player is LocalPlayer:
			var local := player as LocalPlayer
			local.hot_seat = hot_seat
			local.tile_history = $TileHistory
			local.ship_shown.connect(gui.update_ship_info)
			local.buttons_changed.connect(gui.set_buttons)
		player.fleet_changed.connect(_update_fleets)
		player.attack_started.connect(turn_replay.begin)
		player.attack_landed.connect(turn_replay.land)
		player.attack_resolved.connect(turn_replay.end)
		player.mine_blast.connect(turn_replay.mine_blast.bind(player))
	turn_replay.sinking_shown.connect(_update_fleets)
	gui.action_pressed.connect(_on_gui_action_pressed)
	add_child(effects)
	turn_replay.effects = effects
	hover_label = Node2D.new()
	add_child(hover_label)
	hover_label.draw.connect(_draw_hover_label)
	$TitleMusic.play(title_music_at)
	# New Game and replays start it from the top
	title_music_at = 0.0
	play_game()


func _input(_event: InputEvent) -> void:
	queue_redraw()
	hover_label.queue_redraw()


# What the tag over `hex` says, if it's shown at all
func hover_text(hex: Vector2i) -> String:
	if hex == Grid.OFF_GRID or swapping or choosing:
		return ""
	return ROW_LABELS[hex.y] + str(hex.x)


# The coordinate on a dark tag, readable over markers and ships
func _draw_hover_label() -> void:
	var hex := grid.get_hex_from_coords(get_viewport().get_mouse_position())
	var text := hover_text(hex)
	if text.is_empty():
		return
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var center := grid.get_hex_center(hex)
	var tag := Rect2(center - text_size / 2, text_size).grow_individual(3, 0, 3, 0)
	hover_label.draw_rect(tag, Color(0.0, 0.0, 0.0, 0.7))
	var baseline := Vector2(tag.position.x + 3, tag.position.y + FONT.get_ascent(FONT_SIZE))
	hover_label.draw_string(
		FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE
	)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var up := players[player_up]
	if key.physical_keycode == KEY_C and up is LocalPlayer and up.active:
		(up as LocalPlayer).ready_abilities()
	elif key.physical_keycode == KEY_V:
		reveal_all = not reveal_all
		if not reveal_all:
			for player in players:
				for ship in player.ships:
					# Ships revealed by an ability are drawn translucent
					ship.visible = player.active or ship.modulate.a < 1.0


func _process(_delta: float) -> void:
	# Ships hide and show themselves all turn, so keep overriding them
	if reveal_all:
		for player in players:
			for ship in player.ships:
				ship.visible = true


func play_game() -> void:
	grid = Grid.new()
	for player in players:
		player.grid = grid
	$TileHistory.grid = grid
	turn_replay.grid = grid
	player_up = 0
	var resume := loaded
	loaded = {}
	if resume.is_empty():
		await _set_up()
	else:
		_restore(resume)
	pause_menu.can_replay = true
	_update_fleets()
	_start_battle_music()
	# A resumed game starts at the swap screen of the turn it was saved in
	var resuming := not resume.is_empty()
	# Play until one player has no more ships
	while not players[0].ships.is_empty() and not players[1].ships.is_empty():
		# Saved mid-turn: the replay holds this player's own attacks so far, to
		# be shown with the rest of the turn at its end
		var carrying_on: bool = resuming and resume.phase == "turn"
		# Increment the turn counter at the start of player 1's turn
		if player_up == 0 and not resuming:
			current_turn += 1
			grid.turn = current_turn
		# Wait for the hotseat players to swap seats, except on player 1's first turn
		if hot_seat and (resuming or current_turn != 1 or player_up == 1):
			swapping = true
			# From the next player's side from here on
			_update_fleets()
			if not resuming:
				SaveGame.write(SaveGame.AUTOSAVE, save_state("swap"))
			var player := players[player_up]
			var swapper := TURN_SWAP_SCENE.instantiate()
			add_child(swapper)
			# Who's up, which a loaded game otherwise leaves unsaid
			swapper.set_heading("Pass to Player %d" % (player_up + 1))
			var replayable: bool = turn_replay.has_actions() and not carrying_on
			swapper.offer_replay(replayable, player.watch_replay)
			var watch: bool = await swapper.swap_done
			# The board was last drawn from the other player's side
			queue_redraw()
			if replayable:
				# Remember the choice for this player's next swap
				player.watch_replay = watch
				if watch:
					await turn_replay.play()
			swapping = false
		if not carrying_on:
			turn_replay.clear()
		# Against the AI, at the start of each of the player's turns (hot-seat
		# saves at the hand-off)
		if not hot_seat and not resuming and players[player_up] is LocalPlayer:
			SaveGame.write(SaveGame.AUTOSAVE, save_state("swap"))
		gui.update_turn(current_turn)
		_update_fleets()
		# The AI's turn plays out live in front of the player
		if players[player_up] is AIPlayer:
			turn_replay.watch(players[player_up])
		if carrying_on:
			# Carry on with the AP and fire actions it was saved with
			players[player_up].resume_turn()
		else:
			# Reset AP counts, decrement ability timers, etc.
			players[player_up].new_turn()
		resuming = false
		# The player emits made_move once a move has been made. This makes it
		# easy to wait for GUI input for local players, or network input if I
		# ever get around to adding network play.
		while players[player_up].has_moves():
			players[player_up].get_move()
			await players[player_up].made_move
			# For hits and repairs, which don't change the fleet
			_update_fleets()
		players[player_up].finish_turn()
		if turn_replay.watching != null:
			turn_replay.stop_watching()
		if players[player_up].conceded:
			break
		# Go to the next player if they have any ships remaining
		if not players[1 - player_up].ships.is_empty():
			player_up = 1 - player_up

	# Nothing left to carry on with
	SaveGame.delete(SaveGame.AUTOSAVE)
	SaveGame.mark_finished(game_id)
	var victory := VICTORY_SCENE.instantiate()
	if players[player_up].conceded:
		victory.update_winner(2 - player_up, player_up + 1)
	else:
		victory.update_winner(1 if players[0].ships.size() > players[1].ships.size() else 2)
	add_child(victory)
	victory.show_stats(players, current_turn)


# Ship selection and placement for both players
func _set_up() -> void:
	var selections: Array = []
	if not replay.is_empty():
		grid.set_islands(replay.islands)
		selections = replay.selections
		replay = {}
	for player in players:
		# Hand over before Player 2 sees anything of their setup
		if player.player_num == 1 and hot_seat:
			var swapper := TURN_SWAP_SCENE.instantiate()
			add_child(swapper)
			swapper.set_heading("Pass to Player 2")
			swapper.offer_replay(false, false)
			await swapper.swap_done
		if selections.size() <= player.player_num:
			choosing = true
			selections.append(await player.get_ship_selection())
			choosing = false
		await player.place_ships(selections[player.player_num])
	setup = {"islands": grid.get_islands(), "selections": selections}
	# Random, and unaffected by seed()
	game_id = ResourceUID.create_id()


# Everything needed to carry on with this game: at the swap screen before
# `player_up`'s turn (phase "swap"), or part-way through it ("turn")
func save_state(phase: String) -> Dictionary:
	var tiles: Array[Dictionary] = []
	for x in Grid.COLUMNS:
		for y in Grid.ROWS:
			var tile := grid.tile(Vector2i(x, y))
			if not tile.history.is_empty() or tile.is_mined:
				tiles.append(
					{
						"hex": Vector2i(x, y),
						"history": tile.history.duplicate(true),
						"mined": tile.is_mined
					}
				)
	var saved: Array[Dictionary] = []
	# What the replay refers to: each player's ships, afloat then held for the
	# replay to sink, and the copies of the opponent's ships they've seen
	var fleets: Array[Array] = []
	var copies: Array[Array] = []
	for player in players:
		var held := turn_replay.held_ships(player)
		var revealed := player.temp_revealed_ships.filter(
			func(copy: Ship) -> bool: return is_instance_valid(copy)
		)
		fleets.append(player.ships + held)
		copies.append(revealed)
		(
			saved
			. append(
				{
					"attacks": player.attacks,
					"hits": player.hits,
					"fleet_size": player.fleet_size,
					"watch_replay": player.watch_replay,
					"ships": player.ships.map(SaveGame.ship_state),
					"held": held.map(SaveGame.ship_state),
					"revealed": revealed.map(SaveGame.revealed_state),
				}
			)
		)
	return {
		"phase": phase,
		"mode": mode,
		"game": game_id,
		"turn": current_turn,
		"player_up": player_up,
		"setup": setup,
		"tiles": tiles,
		"players": saved,
		"replay": turn_replay.save(fleets, copies),
	}


# Puts the board and fleets back as `data` (from save_state()) had them
func _restore(data: Dictionary) -> void:
	setup = data.setup
	game_id = data.game
	var islands: Array[Vector2i] = []
	islands.assign(setup.islands)
	grid.set_islands(islands)
	for saved: Dictionary in data.tiles:
		var tile := grid.tile(saved.hex)
		tile.history.assign(saved.history)
		tile.is_mined = saved.mined
	current_turn = data.turn
	grid.turn = current_turn
	player_up = data.player_up
	# As it reads at this swap in a game played through: the turn last played,
	# which at Player 1's hand-off is the one before
	gui.update_turn(current_turn - 1 if data.phase == "swap" and player_up == 0 else current_turn)
	var fleets: Array[Array] = []
	for player in players:
		var saved: Dictionary = data.players[player.player_num]
		player.attacks = saved.attacks
		player.hits = saved.hits
		player.fleet_size = saved.fleet_size
		player.watch_replay = saved.watch_replay
		for state: Dictionary in saved.ships:
			var ship := SaveGame.restore_ship(state, player)
			# Saved mid-turn, the opponent's ships we'd revealed stay revealed
			var revealed: bool = (
				data.phase == "turn" and player.player_num != player_up and state.shown
			)
			ship.visible = revealed
			if revealed:
				ship.modulate = Color(1.0, 1.0, 1.0, 0.8)
			player.ships.append(ship)
		var fleet: Array[Ship] = player.ships.duplicate()
		for state: Dictionary in saved.held:
			var ship := SaveGame.restore_ship(state, player)
			ship.sunk = true
			ship.held = true
			ship.visible = false
			fleet.append(ship)
		fleets.append(fleet)
		for state: Dictionary in saved.revealed:
			player.temp_revealed_ships.append(SaveGame.restore_revealed(state))
	turn_replay.restore(data.replay, players, fleets)


# Crossfades from the title music to the battle music as the first turn starts
func _start_battle_music() -> void:
	var title: AudioStreamPlayer = $TitleMusic
	var battle: AudioStreamPlayer = $Music
	var volume := battle.volume_db
	battle.volume_db = -60.0
	battle.play()
	var fade := create_tween().set_parallel()
	fade.tween_property(battle, "volume_db", volume, MUSIC_FADE)
	fade.tween_property(title, "volume_db", -60.0, MUSIC_FADE)
	fade.chain().tween_callback(title.stop)


func _update_fleets() -> void:
	# Ships sunk last turn still count until the replay shows them sinking
	var seat := viewer()
	var ours: Array[Ship] = players[seat].ships.duplicate()
	ours.append_array(turn_replay.held_ships(players[seat]))
	# Our damage is part of what the replay shows
	gui.update_fleets(ours, players[1 - seat].ships, not swapping)


# Whose side of the game the screen shows: whoever's turn it is in hot-seat,
# otherwise always the local player's
func viewer() -> int:
	return player_up if hot_seat else 0


# Only mid-turn, when it's clear who's at the screen (not during setup, swaps
# or replays), and not with a shot in the air, which would land after the end
func _on_pause_menu_opened() -> void:
	var player := players[player_up]
	var mid_turn := player is LocalPlayer and player.active and not player.animation_playing
	pause_menu.can_concede = mid_turn
	pause_menu.can_save = mid_turn


func _on_gui_action_pressed(action: String) -> void:
	var player := players[player_up]
	if player is LocalPlayer:
		(player as LocalPlayer).press(action)


func _on_pause_menu_save_requested(slot: String) -> void:
	SaveGame.write(slot, save_state("turn"))


func _on_pause_menu_concede_requested() -> void:
	pause_menu.close()
	players[player_up].concede()


func _on_pause_menu_replay_requested() -> void:
	replay = setup
	get_tree().reload_current_scene()


func get_ship_at_hex(hex: Vector2i) -> Ship:
	for player in players:
		var ship := player.get_ship_at_hex(hex)
		if ship != null:
			return ship
	return null


func _draw() -> void:
	var mouse_hex := grid.get_hex_from_coords(get_viewport().get_mouse_position())
	var hover_hexes := players[viewer()].get_hover_hexes(mouse_hex)
	var selected_hexes: Array[Vector2i] = []
	var selected_center := Grid.OFF_GRID
	var selected := players[viewer()].selected_ship
	if selected != null:
		selected_hexes = selected.get_occupied_hexes()
		selected_center = selected_hexes[selected.len_aft]
	var row_step := grid.hex_size / sqrt(3)

	for x in Grid.COLUMNS:
		# Column labels, highlighted under the mouse
		# Centered across the hex's width, so wider numbers don't drift right
		var label_pos := grid.get_hex_center(Vector2i(x, 0)) - Vector2(grid.hex_size / 2, row_step)
		if x % 2 != 0:
			label_pos.y -= row_step * 0.75
		var label_color := Color.RED if mouse_hex.x == x and current_turn != 0 else Color.WHITE
		draw_string(
			FONT,
			label_pos,
			str(x),
			HORIZONTAL_ALIGNMENT_CENTER,
			grid.hex_size,
			FONT_SIZE,
			label_color
		)

		for y in Grid.ROWS:
			var hex := Vector2i(x, y)
			var tile := grid.tile(hex)
			# Row labels on both sides
			if x == 0:
				var left := (
					grid.get_hex_center(Vector2i(0, y))
					- Vector2(grid.hex_size * 0.75, -row_step / 2)
				)
				var right := (
					grid.get_hex_center(Vector2i(Grid.COLUMNS - 1, y))
					+ Vector2(grid.hex_size * 0.6, row_step / 2)
				)
				var row_color := (
					Color(0.7, 0.0, 0.0) if mouse_hex.y == y and current_turn != 0 else Color.WHITE
				)
				draw_string(
					FONT, left, ROW_LABELS[y], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, row_color
				)
				draw_string(
					FONT, right, ROW_LABELS[y], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, row_color
				)

			var points := grid.get_hex_points(hex)
			draw_polygon(
				points,
				PackedColorArray(
					[hex_color(hex, tile, hover_hexes, selected_hexes, selected_center)]
				)
			)
			# Border
			points.append(points[0])
			draw_polyline(points, Color.BLACK)

			draw_string(
				FONT,
				grid.get_hex_center(hex) + Vector2(-grid.hex_size / 2, grid.hex_size / 12),
				ROW_LABELS[y] + str(x),
				HORIZONTAL_ALIGNMENT_CENTER,
				grid.hex_size,
				FONT_SIZE,
				Color.BLACK
			)

			# Hit/miss markers on the opponent's grid, fading out over turns. Over
			# the label, which a miss's ring goes around.
			if grid.side_of(hex) == 1 - viewer():
				draw_markers(hex, tile)


func hex_color(
	hex: Vector2i,
	tile: Tile,
	hover_hexes: Array[Vector2i],
	selected_hexes: Array[Vector2i],
	selected_center: Vector2i
) -> Color:
	if hover_hexes.has(hex) and current_turn != 0:
		# Darker on the opponent's grid
		if grid.side_of(hex) == viewer():
			return Color(0.8, 0.5, 0.25) if tile.island else Color(0.0, 0.3, 0.9)
		return Color(0.47, 0.27, 0.14) if tile.island else Color(0.0, 0.26, 0.5)
	if hex == selected_center and not swapping:
		return Color(0.7, 0.42, 0.2) if tile.island else Color(0.0, 0.3, 0.9)
	if selected_hexes.has(hex) and not swapping:
		return Color(0.0, 0.4, 0.9)
	if tile.island:
		return Color(1.0, 0.67, 0.5)
	return Color(0.0, 0.3, 0.65) if tile.no_mans_land else Color(0.0, 0.5, 1.0)


func draw_markers(hex: Vector2i, tile: Tile) -> void:
	var center := grid.get_hex_center(hex)
	var last_event := tile.get_last_event()
	if not last_event.is_empty():
		var alpha := maxf(1.0 - (current_turn - last_event[0]) / 10.0, 0.0)
		var event: String = last_event[1]
		# Shapes as well as colours, for colour-blind players: an outlined red dot
		# with a cross for a hit, a ring around the label for a miss, an outlined
		# black dot when sunk
		if event == "Hit":
			draw_circle(center, 11, Color(0.0, 0.0, 0.0, alpha))
			draw_circle(center, 10, Color(1.0, 0.0, 0.0, alpha))
			var cross := Color(1.0, 1.0, 1.0, alpha)
			draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), cross, 2.5, true)
			draw_line(center + Vector2(-5, 5), center + Vector2(5, -5), cross, 2.5, true)
		elif event in ["Miss", "Miss (ASW Strike)", "Miss (Nuclear Strike)", "Miss (Salvo)"]:
			draw_circle(center, 14, Color(1.0, 1.0, 1.0, alpha), false, 3.0, true)
		elif event == "Sunk":
			draw_circle(center, 12, Color(1.0, 1.0, 1.0, alpha))
			draw_circle(center, 10, Color(0.0, 0.0, 0.0, alpha))
		elif event.begins_with("Miss ("):
			# Mixed marker when a potential hit was blocked by an ability
			draw_texture(
				HITMISS_TEXTURE,
				center - HITMISS_TEXTURE.get_size() / 2,
				Color(1.0, 1.0, 1.0, alpha)
			)
	if tile.is_mined:
		draw_texture(MINE_TEXTURE, center - MINE_TEXTURE.get_size() / 2, Color(0.0, 0.0, 0.0, 0.5))
