extends GutTest
# Hosting and joining a LAN game from the title screen's lobby

const LOBBY_SCENE := preload("res://gui/lan_lobby.tscn")

var handed: Array = []


func lobby() -> Control:
	var made: Control = add_child_autofree(LOBBY_SCENE.instantiate())
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
