class_name EnetLink
extends Link
# A Link over the network: the host listens for one guest, the guest connects
# to the host's address. Godot's ENet peer is used directly, polled for
# packets, rather than through RPCs, so nothing depends on node paths.

const PORT := 43210
# ENet's own limit on silence (msec), past Link's minute so it's Link that
# gives up, and ENet holds on through a blip, resending what was held up
const TIMEOUT := 90000

var _peer := ENetMultiplayerPeer.new()


# Listening for a guest, or null if the port can't be opened
static func host(port: int = PORT) -> EnetLink:
	var link := EnetLink.new()
	if link._peer.create_server(port, 1) != OK:
		return null
	link._listen()
	return link


# Connecting to the host at `address`, or null if it can't even try
static func join(address: String, port: int = PORT) -> EnetLink:
	var link := EnetLink.new()
	if link._peer.create_client(address, port) != OK:
		return null
	link._listen()
	return link


func _listen() -> void:
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.peer_connected.connect(
		func(id: int) -> void:
			_peer.get_peer(id).set_timeout(0, TIMEOUT, TIMEOUT)
			_say_hello()
	)
	_peer.peer_disconnected.connect(func(_id: int) -> void: _drop(true))


func send(message: Dictionary) -> void:
	if closed:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(var_to_bytes(message))


func _pump() -> void:
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		# No objects, so a malicious packet can't run code
		var message: Variant = bytes_to_var(_peer.get_packet())
		if message is Dictionary:
			_deliver(message)
	# A guest whose connection gave up before the hello
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and not linked:
		failed.emit("No game answered there")


func close() -> void:
	# Sends what's queued first: closing throws it away
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		_peer.host.flush()
	_peer.close()
	closed = true
