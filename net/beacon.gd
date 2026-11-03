class_name Beacon
extends RefCounted
# A host's answer to guests looking for games: listens on the discovery port
# and tells whoever asks that a game is here, and which build. Polled every
# frame while hosting. See Finder for the asking side.

const PORT := 43211

var _socket := PacketPeerUDP.new()


# Listening on `port`, or null if it can't be (another host on this computer)
static func listen(port: int = PORT) -> Beacon:
	var beacon := Beacon.new()
	if beacon._socket.bind(port) != OK:
		return null
	return beacon


func poll() -> void:
	while _socket.get_available_packet_count() > 0:
		# No objects, so a malicious packet can't run code
		var asked: Variant = bytes_to_var(_socket.get_packet())
		if asked is Dictionary and asked.get("type") == "flotilla?":
			_socket.set_dest_address(_socket.get_packet_ip(), _socket.get_packet_port())
			_socket.put_packet(var_to_bytes({"type": "flotilla!", "version": Link.build()}))


func close() -> void:
	_socket.close()
