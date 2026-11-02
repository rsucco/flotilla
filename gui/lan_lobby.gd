extends Control
# Hosting or joining a LAN game, over the title screen. Once the other game
# answers with the same build, hands the connection over (`linked`).

signal linked(link: Link, hosting: bool)

# Adapter names (Linux, Windows) of Docker, libvirt, WSL, VirtualBox and VMware
const VIRTUAL: Array[String] = [
	"docker", "br-", "veth", "virbr", "vethernet", "virtualbox", "vmnet", "vboxnet"
]
# Joining gives up after this long, rather than ENet's half a minute
var connect_timeout := 10.0
var link: Link
var hosting := false
var _waited := 0.0


func _ready() -> void:
	%Address.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	Focus.first(self)


func _process(delta: float) -> void:
	if link == null:
		return
	link.poll()
	if link != null and not hosting:
		_waited += delta
		if _waited > connect_timeout:
			_fail("No game answered at " + %Address.text.strip_edges())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _exit_tree() -> void:
	if link != null:
		link.close()


func _on_host_pressed() -> void:
	var hosted := EnetLink.host()
	if hosted == null:
		_say("Couldn't host. Is another game already hosting on this computer?")
		return
	hosting = true
	_listen(hosted)
	var at := local_addresses()
	_say(
		(
			"Hosting at %s. Waiting for a player…" % " or ".join(at)
			if not at.is_empty()
			else "Hosting. Waiting for a player…"
		)
	)


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
	linked.emit(handed, hosting)


func _fail(reason: String) -> void:
	_stop()
	_say(reason)


# Stops hosting or joining
func _stop() -> void:
	link.close()
	link = null
	_set_busy(false)


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
