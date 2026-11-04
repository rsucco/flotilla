class_name LoopbackLink
extends Link
# Two Links joined inside one process, for tests: what one sends, the other
# receives on its next poll(). Muted, it holds what it sends until unmuted,
# as ENet does through a blip.

var other: LoopbackLink
var muted := false
var _wire: Array[Dictionary] = []
var _held: Array[Dictionary] = []
var _greeted := false


static func pair() -> Array[LoopbackLink]:
	var a := LoopbackLink.new()
	var b := LoopbackLink.new()
	a.other = b
	b.other = a
	return [a, b]


func send(message: Dictionary) -> void:
	if not closed:
		# A copy, as if it had crossed the network
		_held.append(message.duplicate(true))


func _pump() -> void:
	# On the first poll, as a connection would
	if not _greeted:
		_greeted = true
		_say_hello()
	if not muted:
		other._wire.append_array(_held)
		_held.clear()
	while not _wire.is_empty():
		_deliver(_wire.pop_front())
	if other.closed:
		_drop(true)


func close() -> void:
	# What's held goes first, as EnetLink flushes
	other._wire.append_array(_held)
	_held.clear()
	closed = true
