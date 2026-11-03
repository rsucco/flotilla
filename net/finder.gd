class_name Finder
extends RefCounted
# Finds LAN games for a guest: asks the whole network once a second who's
# hosting, and keeps the answers. A host not heard from in a while is gone.
# Polled every frame while looking. See Beacon for the answering side.

# The games found changed
signal changed

const ASK_MS := 1000
const FORGET_MS := 3500

# Where to ask: everyone on the network, unless a test says otherwise
var ask_at := "255.255.255.255"
var port := Beacon.PORT
# Host address -> {"version": its build, "seen": when it last answered (msec)}
var games := {}
var _socket := PacketPeerUDP.new()
var _asked_at := -ASK_MS


func _init() -> void:
	_socket.set_broadcast_enabled(true)
	# Any free port, for the answers to come back to
	_socket.bind(0)


func poll() -> void:
	var now := Time.get_ticks_msec()
	if now - _asked_at >= ASK_MS:
		_asked_at = now
		_socket.set_dest_address(ask_at, port)
		_socket.put_packet(var_to_bytes({"type": "flotilla?"}))
	var before := games.keys()
	while _socket.get_available_packet_count() > 0:
		var answer: Variant = bytes_to_var(_socket.get_packet())
		if answer is Dictionary and answer.get("type") == "flotilla!":
			games[_socket.get_packet_ip()] = {"version": str(answer.get("version")), "seen": now}
	for address: String in games.keys():
		if now - games[address].seen > FORGET_MS:
			games.erase(address)
	if games.keys() != before:
		changed.emit()


func close() -> void:
	_socket.close()
