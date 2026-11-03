extends GutTest
# Hosting and joining a LAN game from the title screen's lobby

const LOBBY_SCENE := preload("res://gui/lan_lobby.tscn")

var handed: Array = []


# On ports of its own, so a real game nearby isn't found
func lobby() -> Control:
	var made: Control = add_child_autofree(LOBBY_SCENE.instantiate())
	made.beacon_port = Beacon.PORT + 40
	made.finder.port = Beacon.PORT + 40
	made.linked.connect(func(link: Link, hosting: bool) -> void: handed.append([link, hosting]))
	return made


func after_each() -> void:
	for pair: Array in handed:
		(pair[0] as Link).close()
	handed.clear()


func test_host_and_join_on_this_computer() -> void:
	var host := lobby()
	var guest := lobby()
	host.get_node("%Host").pressed.emit()
	assert_true(host.get_node("%Status").text.contains("Waiting for a player"))
	assert_true(host.get_node("%Join").disabled, "only Back while hosting")
	guest.get_node("%Address").text = "127.0.0.1"
	guest.get_node("%Join").pressed.emit()
	await wait_until(func() -> bool: return handed.size() == 2, 5)
	var hosting := handed.map(func(pair: Array) -> bool: return pair[1])
	assert_eq_deep(hosting, [true, false])
	assert_true(handed.all(func(pair: Array) -> bool: return pair[0].linked), "linked")


func test_joining_gives_up_where_no_one_answers() -> void:
	var guest := lobby()
	guest.connect_timeout = 0.3
	guest.get_node("%Address").text = "127.0.0.1"
	guest.get_node("%Join").pressed.emit()
	await wait_seconds(0.6)
	assert_true(guest.get_node("%Status").text.begins_with("No game answered"))
	assert_false(guest.get_node("%Join").disabled, "free to try again")


func test_back_stops_hosting() -> void:
	var host := lobby()
	host.get_node("%Host").pressed.emit()
	host.get_node("%Back").pressed.emit()
	assert_false(host.get_node("%Host").disabled)
	assert_false(host.get_node("%Status").visible)
	host.get_node("%Host").pressed.emit()
	assert_true(host.get_node("%Status").text.contains("Waiting"), "the port's free again")
	host.get_node("%Back").pressed.emit()


func test_private_addresses_only() -> void:
	for address in preload("res://gui/lan_lobby.gd").local_addresses():
		assert_false(address.begins_with("127."), address)


func test_games_on_the_network_are_listed_to_join() -> void:
	var host := lobby()
	var guest := lobby()
	assert_true(guest.get_node("%Looking").visible, "looking")
	host.get_node("%Host").pressed.emit()
	await wait_until(func() -> bool: return guest.get_node("%Games").get_child_count() > 0, 5)
	var found: Button = guest.get_node("%Games").get_child(0)
	assert_string_starts_with(found.text, "Game at ")
	assert_false(guest.get_node("%Looking").visible)
	found.pressed.emit()
	await wait_until(func() -> bool: return handed.size() == 2, 5)
	assert_eq(handed.size(), 2, "joined it")


func test_a_game_of_another_version_cant_be_joined() -> void:
	var guest := lobby()
	guest.finder.games["10.0.0.9"] = {"version": "0.0.1/1", "seen": Time.get_ticks_msec()}
	guest._list_games()
	var listed: Button = guest.get_node("%Games").get_child(0)
	assert_eq(listed.text, "Game at 10.0.0.9 (a different version)")
	assert_true(listed.disabled)


func test_a_host_that_stops_answering_is_forgotten() -> void:
	var finder := Finder.new()
	finder.games["10.0.0.9"] = {"version": Link.build(), "seen": Time.get_ticks_msec() - 5000}
	finder.port = Beacon.PORT + 41
	finder.poll()
	assert_eq(finder.games, {})
	finder.close()
