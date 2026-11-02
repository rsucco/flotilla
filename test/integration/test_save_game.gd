extends GutTest
# Saving and loading games: the autosave at each hand-off, the Esc menu's
# slots, and carrying on from the title screen. test/pre_run.gd keeps these
# saves out of the player's own.

const ROOT_SCENE := preload("res://root.tscn")
const TITLE_SCENE := preload("res://title_screen.tscn")
const LOAD_SCENE := preload("res://gui/load_game.tscn")
const GameDriver := preload("res://test/game_driver.gd")

var game: Root
var driver: GameDriver


func before_each() -> void:
	for slot in [SaveGame.AUTOSAVE] + SaveGame.SLOTS:
		SaveGame.delete(slot)
	# GUT's own window would catch the board clicks
	get_node("/root/GutRunner/GutLayer").visible = false
	Engine.time_scale = 4.0


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Root.loaded = {}
	Root.mode = Root.Mode.HOT_SEAT
	Root.replay = {}
	get_node("/root/GutRunner/GutLayer").visible = true


func start() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	driver.prepare_board()
	await driver.start_game()


# Frees the current game and starts another from `data`, at its swap screen
func reload(data: Dictionary) -> void:
	game.queue_free()
	await wait_process_frames(1)
	Root.loaded = data
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")


func test_slots_describe_themselves_and_the_latest_is_continued() -> void:
	assert_eq(SaveGame.latest(), "", "nothing saved yet")
	assert_eq(SaveGame.describe("slot2"), "Slot 2: Empty")
	var hot_seat := Root.Mode.HOT_SEAT
	var setup := {"navies": ["uk", "usa"]}
	SaveGame.write("slot2", {"mode": hot_seat, "turn": 4, "player_up": 1, "setup": setup})
	SaveGame.write(SaveGame.AUTOSAVE, {"mode": hot_seat, "turn": 5, "player_up": 0, "setup": setup})
	assert_string_starts_with(
		SaveGame.describe("slot2"), "Slot 2: Hot-seat, Turn 4, United States Navy - "
	)
	assert_eq(SaveGame.latest(), SaveGame.AUTOSAVE)
	SaveGame.write("slot3", {"mode": Root.Mode.VS_AI, "turn": 6, "player_up": 0})
	assert_string_starts_with(SaveGame.describe("slot3"), "Slot 3: vs AI, Turn 6 - ")
	assert_eq(SaveGame.latest(), "slot3")


func test_unreadable_saves_are_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	var file := FileAccess.open(SaveGame.path("slot1"), FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	assert_eq(SaveGame.read("slot1"), {}, "garbage")
	file = FileAccess.open(SaveGame.path("slot1"), FileAccess.WRITE)
	file.store_var({"version": SaveGame.VERSION + 1, "turn": 1})
	file.close()
	assert_eq(SaveGame.read("slot1"), {}, "another version")
	assert_eq(SaveGame.latest(), "")


func test_autosaved_at_each_hand_off() -> void:
	await start()
	await driver.end_turn()
	await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	var data := SaveGame.read(SaveGame.AUTOSAVE)
	assert_eq(data.get("phase"), "swap")
	assert_eq(data.get("player_up"), 1, "before Player 2's turn")
	assert_eq(data.get("turn"), 1)


func test_turn_counter_reads_as_before_the_save() -> void:
	await start()
	await driver.end_turn()
	await driver.swap()
	await driver.wait_until(func() -> bool: return game.players[1].active, 5, "Player 2's turn")
	await driver.end_turn()
	await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	var label := "GUIGrid/TurnNumber/TurnNumber"
	var live: String = game.gui.get_node(label).text
	assert_eq(live, "1", "Player 1's hand-off, before turn 2")
	await reload(SaveGame.read(SaveGame.AUTOSAVE))
	assert_eq(game.gui.get_node(label).text, live)


func test_mid_turn_save_carries_on_where_it_left_off() -> void:
	await start()
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	game.grid.tile(GameDriver.spot(1, "cruiser")).is_mined = true
	var saved := game.save_state("turn")
	await reload(saved)
	await driver.swap()
	await driver.wait_until(func() -> bool: return game.players[0].active, 5, "the turn")
	var battleship := driver.ship_of(0, "battleship")
	assert_eq(battleship.ap, 2, "the AP it was saved with")
	assert_eq(battleship.fire_remaining, 0)
	assert_true(game.grid.tile(GameDriver.spot(1, "cruiser")).is_mined, "mines")
	var now := game.save_state("turn")
	assert_eq(now.tiles, saved.tiles, "every hex's history")
	assert_eq(now.replay, saved.replay, "the attacks so far, for the replay")
	for player in 2:
		assert_eq(now.players[player], saved.players[player], "Player %d's fleet" % (player + 1))
	await driver.act("cruiser", "Forward")
	var cruiser := driver.ship_of(0, "cruiser")
	assert_true(cruiser.movement_audio_player.playing, "moving with its sound")
	assert_eq(cruiser.movement_audio_player.stream, cruiser.move_sound)


func test_hand_off_save_starts_the_next_players_turn() -> void:
	await start()
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	await reload(SaveGame.read(SaveGame.AUTOSAVE))
	var swap := driver._dialog(game, "res://gui/local_turn_swap.tscn")
	var navy := game.players[1].navy_name()
	assert_eq(swap.get_node("VBoxContainer/Label").text, "Pass to " + navy, "says who's up")
	assert_eq(game.gui.get_node("GUIGrid/TurnNumber/TurnNumber").text, "1", "the turn replayed")
	assert_true(swap.get_node("VBoxContainer/WatchReplay").visible, "last turn's replay")
	var smoke: CPUParticles2D = game.turn_replay.actions[0].smoke()[0]
	await driver.swap(true)
	await wait_process_frames(1)
	assert_true(game.turn_replay.playing, "replayed")
	assert_false(smoke.visible, "the hit not shown before the shell lands")
	await driver.wait_until(func() -> bool: return game.players[1].active, 20, "Player 2's turn")
	assert_true(smoke.visible, "shown once it lands")
	assert_eq(game.current_turn, 1)
	assert_eq(driver.ship_of(1, "battleship").ap, 4, "a fresh turn")
	assert_true(driver.ship_of(1, "destroyer").hit_hexes.has(true), "with last turn's damage")


func test_a_ship_sunk_last_turn_is_replayed_sinking_after_loading() -> void:
	await start()
	driver.ready_abilities(game.players[0])
	await driver.act("destroyer", "Special", driver.ship_of(1, "submarine").hex)
	await driver.end_turn()
	await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	await reload(SaveGame.read(SaveGame.AUTOSAVE))
	var held := game.turn_replay.held_ships(game.players[1])
	assert_eq(held.size(), 1, "kept for the replay")
	var sub := held[0]
	assert_eq(sub.ship_type, "submarine")
	assert_false(game.players[1].ships.has(sub), "not afloat")
	await driver.swap(true)
	await wait_process_frames(1)
	assert_true(sub.visible, "afloat again at the start of the replay")
	await driver.wait_until(func() -> bool: return game.players[1].active, 20, "Player 2's turn")
	assert_false(is_instance_valid(sub) and sub.visible, "shown sinking")


func test_a_battery_that_fired_is_still_shown_after_loading() -> void:
	await start()
	await driver.act("coastal_battery", "Fire", GameDriver.spot(1, "destroyer"))
	await driver.end_turn()
	await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	await reload(SaveGame.read(SaveGame.AUTOSAVE))
	var copies := game.players[1].temp_revealed_ships
	assert_eq(game.turn_replay.actions[0].revealed, copies, "the replay shows it firing")
	await driver.swap()
	await driver.wait_until(func() -> bool: return game.players[1].active, 5, "Player 2's turn")
	assert_eq(copies.size(), 1)
	var battery := driver.ship_of(0, "coastal_battery")
	assert_true(copies[0].visible and copies[0].is_inside_tree(), "shown to Player 2")
	assert_eq(copies[0].position, battery.position, "where it is")
	assert_almost_eq(
		(copies[0].get_node("Turret") as Node2D).rotation,
		battery.turret.rotation,
		0.01,
		"as it fired"
	)


func test_a_turn_resumed_part_way_is_replayed_whole() -> void:
	await start()
	await driver.act("battleship", "Fire", GameDriver.spot(1, "destroyer"))
	await reload(game.save_state("turn"))
	var swap := driver._dialog(game, "res://gui/local_turn_swap.tscn")
	assert_false(swap.get_node("VBoxContainer/WatchReplay").visible, "not our own attacks")
	await driver.swap()
	await driver.wait_until(func() -> bool: return game.players[0].active, 5, "the turn")
	await driver.act("destroyer", "Fire", GameDriver.spot(1, "cruiser"))
	await driver.end_turn()
	swap = await driver.find_dialog(game, "res://gui/local_turn_swap.tscn")
	assert_true(swap.get_node("VBoxContainer/WatchReplay").visible)
	assert_eq(game.turn_replay.actions.size(), 2, "from before the save and after")


func test_save_from_the_esc_menu() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	driver.prepare_board()
	var menu := game.pause_menu
	menu.open()
	assert_true(menu.save_game.disabled, "not during setup")
	menu.close()
	await driver.start_game()
	menu.open()
	menu.save_game.pressed.emit()
	var slots := menu.get_node("Panel/Saves/Slots").get_children()
	assert_eq(slots.size(), 3)
	assert_eq(slots[1].text, "Slot 2: Empty")
	slots[1].pressed.emit()
	assert_eq(SaveGame.read("slot2").get("phase"), "turn")
	assert_eq(menu.heading.text, "Saved to Slot 2")
	assert_true(menu.main.visible, "back to the menu")
	menu.close()


func test_overwriting_a_slot_asks_first() -> void:
	await start()
	# Marked, to tell it from the save that replaces it
	var old := game.save_state("turn")
	old.phase = "old"
	SaveGame.write("slot1", old)
	var menu := game.pause_menu
	menu.open()
	menu.save_game.pressed.emit()
	menu.get_node("Panel/Saves/Slots").get_child(0).pressed.emit()
	assert_true(menu.confirm.visible, "asks")
	assert_eq(menu.question.text, "Overwrite Slot 1?")
	menu.get_node("Panel/Confirm/Buttons/No").pressed.emit()
	assert_true(menu.saves.visible, "No goes back to the slot list")
	assert_eq(SaveGame.read("slot1").phase, "old", "not overwritten")
	menu.get_node("Panel/Saves/Slots").get_child(0).pressed.emit()
	menu.get_node("Panel/Confirm/Buttons/Yes").pressed.emit()
	assert_eq(SaveGame.read("slot1").get("phase"), "turn", "overwritten")
	assert_eq(menu.heading.text, "Saved to Slot 1")
	assert_true(get_tree().paused, "still paused under the menu")
	menu.close()


func test_finished_game_is_kept_but_not_continued() -> void:
	await start()
	await driver.end_turn()
	await driver.swap()
	await driver.wait_until(func() -> bool: return game.players[1].active, 5, "Player 2's turn")
	assert_false(SaveGame.read(SaveGame.AUTOSAVE).is_empty())
	SaveGame.write("slot1", game.save_state("turn"))
	var saved_at: float = SaveGame.read("slot1").saved_at
	var other := game.save_state("turn")
	other.game = game.game_id + 1
	SaveGame.write("slot2", other)
	game.players[1].concede()
	await driver.find_dialog(game, "res://gui/victory.tscn")
	assert_true(SaveGame.read(SaveGame.AUTOSAVE).finished, "the autosave, kept")
	assert_true(SaveGame.read("slot1").finished, "this game's slot")
	assert_eq(SaveGame.read("slot1").saved_at, saved_at, "keeps when it was saved")
	assert_string_ends_with(SaveGame.describe("slot1"), " (finished)")
	assert_false(SaveGame.read("slot2").has("finished"), "another game's slot")
	assert_eq(SaveGame.latest(), "slot2", "Continue skips the finished game")
	SaveGame.delete("slot2")
	var title: Node = add_child_autofree(TITLE_SCENE.instantiate())
	var buttons := title.get_node("TextureRect/PanelContainer/Buttons")
	assert_false(buttons.get_node("Continue").visible, "nothing to continue")
	assert_false(buttons.get_node("Load").disabled, "but the finished game loads")
	title.free()
	await reload(SaveGame.read("slot1"))
	assert_false(game.save_state("turn").has("finished"), "saving it again carries on")


func test_title_screen_continue_and_load() -> void:
	var title: Node = add_child_autofree(TITLE_SCENE.instantiate())
	var buttons := title.get_node("TextureRect/PanelContainer/Buttons")
	assert_false(buttons.get_node("Continue").visible, "nothing to continue")
	assert_true(buttons.get_node("Load").disabled)
	title.free()
	var setup := {"navies": ["uk", "usa"]}
	SaveGame.write("slot1", {"mode": Root.Mode.HOT_SEAT, "turn": 2, "player_up": 0, "setup": setup})
	title = add_child_autofree(TITLE_SCENE.instantiate())
	buttons = title.get_node("TextureRect/PanelContainer/Buttons")
	assert_true(buttons.get_node("Continue").visible)
	assert_false(buttons.get_node("Load").disabled)
	var dialog: Control = add_child_autofree(LOAD_SCENE.instantiate())
	var slots := dialog.get_node("%Slots").get_children()
	assert_eq(slots.size(), 4, "autosave and three slots")
	assert_true(slots[0].disabled, "no autosave yet")
	assert_false(slots[1].disabled)
	watch_signals(dialog)
	slots[1].pressed.emit()
	assert_signal_emitted_with_parameters(dialog, "slot_chosen", ["slot1"])


func test_replay_after_loading() -> void:
	await start()
	var islands := game.grid.get_islands()
	SaveGame.write("slot1", game.save_state("turn"))
	await reload(SaveGame.read("slot1"))
	# What Replay This Game does, short of reloading the scene (GUT's, here)
	Root.replay = game.setup
	game.queue_free()
	await wait_process_frames(1)
	game = add_child_autofree(ROOT_SCENE.instantiate())
	driver = GameDriver.new(game)
	assert_eq(game.grid.get_islands(), islands)
	var ship := await driver.placing_ship(game.players[0])
	assert_not_null(ship, "places the saved fleet again")
