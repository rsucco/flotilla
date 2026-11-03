extends Control
# Hosting or joining a LAN game, over the title screen: games found on the
# network (Finder, answered by hosts' Beacons) are listed to join, or an
# address can be typed. Once the other game answers with the same build,
# hands the connection over (`linked`).

signal linked(link: Link, hosting: bool)

# Adapter names (Linux, Windows) of Docker, libvirt, WSL, VirtualBox and VMware
const VIRTUAL: Array[String] = [
	"docker", "br-", "veth", "virbr", "vethernet", "virtualbox", "vmnet", "vboxnet"
]
# Joining gives up after this long, rather than ENet's half a minute
var connect_timeout := 10.0
var link: Link
var hosting := false
var finder: Finder
# Where hosts answer the finder (tests use their own)
var beacon_port := Beacon.PORT
var _beacon: Beacon
var _waited := 0.0


func _ready() -> void:
	%Address.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	finder = Finder.new()
	finder.changed.connect(_list_games)
	# A Steam Deck has no keyboard, and Steam only opens its own by itself for
	# games using Steamworks (Steam sets SteamDeck=1 in Game Mode)
	%KeyboardHint.visible = OS.get_environment("SteamDeck") == "1"
	Focus.first(self)


func _process(delta: float) -> void:
	if link == null:
		finder.poll()
		return
	link.poll()
	if _beacon != null:
		_beacon.poll()
	if link != null and not hosting:
		_waited += delta
		if _waited > connect_timeout:
			_fail("No game answered at " + %Address.text.strip_edges())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _exit_tree() -> void:
	finder.close()
	if link != null:
		link.close()
	if _beacon != null:
		_beacon.close()


func _on_host_pressed() -> void:
	var hosted := EnetLink.host()
	if hosted == null:
		_say("Couldn't host. Is another game already hosting on this computer?")
		return
	hosting = true
	_beacon = Beacon.listen(beacon_port)
	_listen(hosted)
	var at := local_addresses()
	_say(
		(
			"Hosting at %s. Waiting for a player…" % " or ".join(at)
			if not at.is_empty()
			else "Hosting. Waiting for a player…"
		)
	)


# The games found, each a button to join it (one of another build can't be)
func _list_games() -> void:
	for button in %Games.get_children():
		button.free()
	for address: String in finder.games:
		var button := Button.new()
		button.text = "Game at " + address
		var ours: bool = finder.games[address].version == Link.build()
		button.set_meta("ours", ours)
		if not ours:
			button.text += " (a different version)"
			button.disabled = true
		button.pressed.connect(
			func() -> void:
				%Address.text = address
				_on_join_pressed()
		)
		%Games.add_child(button)
	%Looking.visible = finder.games.is_empty()


func _on_join_pressed() -> void:
	var address: String = %Address.text.strip_edges()
	if address.is_empty():
		return
	var joined := EnetLink.join(address)
	if joined == null:
		_say("That isn't an address")
		return
	hosting = false
	_waited = 0.0
	_listen(joined)
	_say("Joining " + address + "…")


func _listen(to: Link) -> void:
	link = to
	link.connected.connect(_on_connected)
	link.failed.connect(_fail)
	_set_busy(true)


func _on_connected() -> void:
	# Ours no longer, so leaving doesn't close it
	var handed := link
	link = null
	_stop_beacon()
	linked.emit(handed, hosting)


func _fail(reason: String) -> void:
	_stop()
	_say(reason)


# Stops hosting or joining
func _stop() -> void:
	link.close()
	link = null
	_stop_beacon()
	_set_busy(false)


func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
		_beacon = null


func _on_back_pressed() -> void:
	if link != null:
		_stop()
		_say("")
	else:
		queue_free()


# While hosting or joining, only Back (which stops it) can be pressed
func _set_busy(busy: bool) -> void:
	%Host.disabled = busy
	%Join.disabled = busy
	for button: Button in %Games.get_children():
		button.disabled = busy or not button.get_meta("ours")
	%Address.editable = not busy
	if busy:
		%Back.grab_focus(true)
	else:
		Focus.first(self)


func _say(text: String) -> void:
	%Status.text = text
	%Status.visible = not text.is_empty()


# Where the other computer can reach this one: its addresses on a private
# network (home and office LANs), leaving out virtual machines' and
# containers' adapters, which only this computer can reach
static func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for interface: Dictionary in IP.get_local_interfaces():
		var adapter: String = interface.name.to_lower()
		if VIRTUAL.any(func(prefix: String) -> bool: return adapter.begins_with(prefix)):
			continue
		for address: String in interface.addresses:
			var parts := address.split(".")
			if parts.size() != 4:
				continue
			var second := int(parts[1])
			if (
				parts[0] == "10"
				or (parts[0] == "192" and second == 168)
				or (parts[0] == "172" and second >= 16 and second < 32)
			):
				found.append(address)
	return found
