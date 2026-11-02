class_name LoopbackLink
extends Link
# Two Links joined inside one process, for tests: what one sends, the other
# receives on its next poll()

var other: LoopbackLink
var _inbox: Array[Dictionary] = []
var _closed := false
var _greeted := false


static func pair() -> Array[LoopbackLink]:
	var a := LoopbackLink.new()
	var b := LoopbackLink.new()
	a.other = b
	b.other = a
	return [a, b]


func send(message: Dictionary) -> void:
	if not _closed:
		# A copy, as if it had crossed the network
		other._inbox.append(message.duplicate(true))


func poll() -> void:
	# On the first poll, as a connection would
	if not _greeted:
		_greeted = true
		_say_hello()
	while not _inbox.is_empty():
		_deliver(_inbox.pop_front())
	if other._closed and linked:
		linked = false
		dropped.emit()


func close() -> void:
	_closed = true
