class_name Link
extends RefCounted
# The channel between this game and the other in a networked game: plain-data
# messages (no objects), delivered in order. Whoever owns the scene calls
# poll() every frame. It outlives scene changes, so the lobby can hand it to
# Root, and messages wait in `inbox` until read, so none are lost in between.
# Both ends say hello first, and only talk if their builds match.
#
# EnetLink goes over the network; LoopbackLink pairs two in one process.

# Hello exchanged and the builds match
signal connected
# Something new in `inbox`
signal received
# Never linked: the other end runs a different build, or couldn't be reached
signal failed(reason: String)
signal dropped

# What both ends must agree on: the game's version, and this protocol's
# (bump it whenever a message changes)
const PROTOCOL := 1

var version: String = (
	"%s/%d" % [ProjectSettings.get_setting("application/config/version"), PROTOCOL]
)
var linked := false
# Messages not yet read, oldest first
var inbox: Array[Dictionary] = []


func send(_message: Dictionary) -> void:
	pass


func poll() -> void:
	pass


func close() -> void:
	pass


func _say_hello() -> void:
	send({"type": "hello", "version": version})


func _deliver(message: Dictionary) -> void:
	if message.get("type") != "hello":
		inbox.append(message)
		received.emit()
	elif message.get("version") == version:
		linked = true
		connected.emit()
	else:
		failed.emit(
			(
				"They're running a different version (%s, ours is %s)"
				% [message.get("version"), version]
			)
		)
