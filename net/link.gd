class_name Link
extends RefCounted
# The channel between this game and the other in a networked game: plain-data
# messages (no objects), delivered in order. Whoever owns the scene calls
# poll() every frame. It outlives scene changes, so the lobby can hand it to
# Root, and messages wait in `inbox` until read, so none are lost in between.
# Both ends say hello first, and only talk if their builds match. Then each
# sends a heartbeat every second, so a silence shows: a few seconds is a blip
# (`quiet`, then `heard` if they come back), a minute means they're gone.
#
# EnetLink goes over the network; LoopbackLink pairs two in one process.

# Hello exchanged and the builds match
signal connected
# Something new in `inbox`
signal received
# Never linked: the other end runs a different build, or couldn't be reached
signal failed(reason: String)
# Nothing heard for `quiet_after` seconds, and then word from them again
signal quiet
signal heard
# They're gone: closed their end (`left`), or silent for `give_up_after`
signal dropped(left: bool)

# What both ends must agree on: the game's version, and this protocol's
# (bump it whenever a message changes)
const PROTOCOL := 2
const BEAT_MS := 1000

var version := build()
var linked := false
# Messages not yet read, oldest first
var inbox: Array[Dictionary] = []
# Seconds of silence before it's a blip, and before they're given up on
var quiet_after := 5.0
var give_up_after := 60.0
var is_quiet := false
# Our end's closed: nothing more is sent or taken in
var closed := false
# When we last sent a heartbeat, and last heard anything (msec)
var _beat_at := 0
var _heard_at := 0


# This build, as both ends must agree on it
static func build() -> String:
	return "%s/%d" % [ProjectSettings.get_setting("application/config/version"), PROTOCOL]


func send(_message: Dictionary) -> void:
	pass


# Delivers what's arrived, and keeps the heartbeat going
func poll() -> void:
	if closed:
		return
	_pump()
	if not linked:
		return
	var now := Time.get_ticks_msec()
	if now - _beat_at >= BEAT_MS:
		_beat_at = now
		send({"type": "beat"})
	var silent := (now - _heard_at) / 1000.0
	if silent > give_up_after:
		close()
		_drop(false)
	elif silent > quiet_after and not is_quiet:
		is_quiet = true
		quiet.emit()


# Takes in what's arrived, passing each message to _deliver()
func _pump() -> void:
	pass


func close() -> void:
	pass


# How long since we heard from them, in seconds
func silence() -> float:
	return (Time.get_ticks_msec() - _heard_at) / 1000.0


func _drop(left: bool) -> void:
	if linked:
		linked = false
		dropped.emit(left)


func _say_hello() -> void:
	send({"type": "hello", "version": version})


func _deliver(message: Dictionary) -> void:
	_heard_at = Time.get_ticks_msec()
	if is_quiet:
		is_quiet = false
		heard.emit()
	if message.get("type") == "beat":
		return
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
