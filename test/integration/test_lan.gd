extends GutTest
# A LAN game, host and guest both in this process over a LoopbackLink: each
# plays its own seat, sees the other's turn live, and the two games stay the
# same move for move (the host rolling every move's dice)

const ROOT_SCENE := preload("res://game/root.tscn")
const GameDriver := preload("res://test/game_driver.gd")
const SELECTION := "res://gui/ship_selection.tscn"

var host: Root
var guest: Root
var drivers: Array[GameDriver] = []


func before_each() -> void:
	seed(5)
	get_node("/root/GutRunner/GutLayer").visible = false
	Engine.time_scale = 4.0
	var links := LoopbackLink.pair()
	Root.mode = Root.Mode.LAN
	Root.link = links[0]
	Root.hosting = true
	host = add_child_autofree(ROOT_SCENE.instantiate())
	Root.link = links[1]
	Root.hosting = false
	guest = add_child_autofree(ROOT_SCENE.instantiate())
	drivers.assign([GameDriver.new(host), GameDriver.new(guest)])
	# Before the hello, so it's the board the guest is sent
	drivers[0].prepare_board()


func after_each() -> void:
	Root.mode = Root.Mode.HOT_SEAT
	Root.hosting = false
	for slot in [SaveGame.AUTOSAVE] + SaveGame.SLOTS:
		SaveGame.delete(slot)
	Engine.time_scale = 1.0
	get_node("/root/GutRunner/GutLayer").visible = true


# `game`'s player picks `navy` and the classic fleet
func choose(game: Root, navy: String) -> void:
	var dialog: Node = await drivers[game.seat].find_dialog(game.players[game.seat], SELECTION)
	dialog.set_island_tiles(game.grid.get_num_island_tiles(game.seat))
	(dialog.get_node("VBoxContainer/Navies/" + navy) as Button).button_pressed = true
	drivers[game.seat].press(dialog.get_node("VBoxContainer/Buttons/Classic"))
	drivers[game.seat].press(dialog.get_node("VBoxContainer/Buttons/OK"))


# One at a time, since a click reaches both games
func place(game: Root) -> void:
	var driver := drivers[game.seat]
	for _i in GameDriver.LAYOUT.size():
		var ship := await driver.placing_ship(game.players[game.seat])
		await driver.click(GameDriver.spot(game.seat, ship.ship_type))


func start(host_navy: String = "usa", guest_navy: String = "japan") -> void:
	await choose(host, host_navy)
	await choose(guest, guest_navy)
	await place(host)
	await place(guest)
	for game in [host, guest]:
		await drivers[0].wait_until(func() -> bool: return game.current_turn == 1, 5, "turn 1")


# Both games' view of the whole board, which should match
func in_step() -> bool:
	return host.players[1].checksum() == guest.players[0].checksum()


# `game`'s player makes a move, and both games play it out
func act(game: Root, ship_type: String, button: String, target := Grid.OFF_GRID) -> void:
	var other := drivers[1 - game.seat]
	var before := other.moves
	await drivers[game.seat].act(ship_type, button, target)
	await other.wait_until(func() -> bool: return other.moves > before, 30, "the other game")


func end_turn(game: Root) -> void:
	var next := 1 - game.player_up
	await drivers[game.seat].end_turn()
	for g in [host, guest]:
		await drivers[0].wait_until(func() -> bool: return g.player_up == next, 5, "the next turn")


func test_both_set_up_on_the_hosts_board() -> void:
	await start()
	assert_eq(guest.grid.get_islands(), host.grid.get_islands(), "the host's islands")
	assert_eq(host.seat, 0, "the host is Player 1")
	assert_eq(guest.seat, 1)
	assert_eq(guest.players[0].navy, "usa", "the guest knows the host's navy")
	assert_eq(host.players[1].navy, "japan", "and the host the guest's")
	for seat in 2:
		var titles := func(game: Root) -> Array:
			return game.players[seat].ships.map(func(s: Ship) -> String: return s.title)
		assert_eq(titles.call(guest), titles.call(host), "the same names")
	for game: Root in [host, guest]:
		var salvo: SpecialAbility = drivers[game.seat].ship_of(1, "battleship").special
		assert_eq(salvo.cooldown_current, salvo.cooldown_interval - 1, "Player 2's head start")
	assert_true(in_step())
	assert_false(
		host.players[1].ships.any(func(s: Ship) -> bool: return s.visible), "theirs unseen"
	)
	assert_true(guest.players[1].ships.all(func(s: Ship) -> bool: return s.visible), "ours in view")


# The C cheat would change only this game's cooldowns, and desync the two
func test_the_ability_cheat_is_off_in_a_lan_game() -> void:
	await start()
	await drivers[0].wait_until(func() -> bool: return host.players[0].active, 5, "our turn")
	var ship: Ship = host.players[0].ships[-1]
	ship.special.cooldown_current = 2
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	host._unhandled_input(key)
	assert_eq(ship.special.cooldown_current, 2)


func test_a_navy_chosen_by_both_stays_the_hosts() -> void:
	await choose(host, "uk")
	await choose(guest, "uk")
	var again: Node = await drivers[1].find_dialog(guest.players[1], SELECTION)
	assert_not_null(again, "the guest chooses again")
	assert_true((again.get_node("VBoxContainer/Navies/uk") as Button).disabled, "without the UK")
	await choose(guest, "france")
	await place(host)
	await place(guest)
	assert_eq(guest.players[0].navy, "uk")
	assert_eq(host.players[1].navy, "france", "the host waited for the guest's next choice")


func test_moves_play_out_the_same_in_both_games() -> void:
	await start()
	# In both games, or the host would rightly refuse the guest's
	for game in [host, guest]:
		for player in game.players:
			drivers[0].ready_abilities(player)
	# Missiles near a cruiser, so there are intercepts to roll
	var cruiser: Vector2i = GameDriver.spot(1, "cruiser")
	await act(host, "destroyer", "Fire", cruiser)
	await act(host, "battleship", "Special", GameDriver.spot(1, "corvette"))
	await act(host, "carrier", "Forward")
	assert_true(in_step(), "after the host's moves")
	assert_eq(guest.turn_replay.watching, guest.players[0], "the guest watches them live")
	await end_turn(host)
	assert_eq(host.viewer(), 0, "each screen stays on its own side")
	assert_eq(guest.viewer(), 1)
	await act(guest, "cruiser", "Fire", GameDriver.spot(0, "destroyer"))
	await act(guest, "submarine", "Special", GameDriver.spot(0, "battleship"))
	await act(guest, "carrier", "Forward")
	assert_true(in_step(), "after the guest's, which the host checked and rolled for")
	await end_turn(guest)
	assert_eq(host.current_turn, 2)
	assert_eq(guest.current_turn, 2)
	assert_true(in_step())


func test_conceding_ends_both_games() -> void:
	await start()
	host._on_pause_menu_concede_requested()
	for game in [host, guest]:
		await drivers[0].wait_until(
			func() -> bool: return drivers[0]._dialog(game, "res://gui/victory.tscn") != null,
			5,
			"the victory screen"
		)
	var victory: Node = drivers[1]._dialog(guest, "res://gui/victory.tscn")
	assert_string_contains(victory.get_node("VBoxContainer/Label").text, "You win!")
	assert_false(victory.get_node("VBoxContainer/HBoxContainer/Rematch").visible, "no rematch yet")
	assert_true(guest.get_node("VictoryMusic").playing, "the winner's music")
	assert_true(host.get_node("DefeatMusic").playing, "and the loser's")


func test_lan_games_are_never_saved() -> void:
	await start()
	assert_eq(SaveGame.latest(), "", "no autosave")
	host.pause_menu.opened.emit()
	assert_false(host.pause_menu.can_save, "nor a save from the menu")
	assert_true(host.pause_menu.can_concede)


func victory_text(game: Root) -> String:
	await drivers[0].wait_until(
		func() -> bool: return drivers[0]._dialog(game, "res://gui/victory.tscn") != null,
		5,
		"the end of the game"
	)
	var victory: Node = drivers[0]._dialog(game, "res://gui/victory.tscn")
	return victory.get_node("VBoxContainer/Label").text if victory != null else ""


func test_leaving_counts_as_conceding() -> void:
	await start()
	# Mid-way through the host's turn, the guest quits
	guest.free()
	var them: String = host.players[1].navy_name()
	assert_eq(await victory_text(host), "You win! " + them + " left the game.")
	assert_true(host.over)
	assert_false(host.players[0].active, "no more moves")


func test_a_blip_is_waited_out() -> void:
	await start()
	var link: Link = host.players[1].link
	link.quiet_after = 0.2
	guest.players[0].link.muted = true
	# They move while we can't hear them
	await drivers[0].wait_until(func() -> bool: return link.is_quiet, 5, "the silence")
	await drivers[0].wait_until(
		func() -> bool: return host.get_node("Banner").visible, 5, "the banner"
	)
	assert_string_contains(host.get_node("Banner/Label").text, "Lost touch with")
	guest.players[0].link.muted = false
	await drivers[0].wait_until(func() -> bool: return not link.is_quiet, 5, "word again")
	assert_false(host.get_node("Banner").visible, "back as it was: our turn, no banner")
	await act(host, "carrier", "Forward")
	assert_true(in_step(), "carrying on")
	assert_false(host.over)


func test_a_minutes_silence_is_dropping_out() -> void:
	await start()
	host.players[1].link.give_up_after = 0.5
	guest.players[0].link.muted = true
	var them: String = host.players[1].navy_name()
	assert_eq(await victory_text(host), "You win! " + them + " dropped out.")


func test_games_out_of_step_both_stop() -> void:
	await start()
	# Something the guest's game got wrong
	guest.players[0].ships[0].ap = 1
	await drivers[0].act("carrier", "Forward")
	for game in [host, guest]:
		assert_string_contains(await victory_text(game), "stopped matching")
		var link: Link = game.players[1 - game.seat].link
		assert_true(link.closed, "and closed, so no more heartbeats")


func test_leaving_during_setup() -> void:
	await choose(host, "usa")
	guest.free()
	assert_string_contains(await victory_text(host), "left the game")
