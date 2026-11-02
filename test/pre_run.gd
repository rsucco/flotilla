extends GutHookScript
# Keeps the run's saves (every hand-off autosaves) out of the player's own,
# and the run out of the way of any real controller


func run() -> void:
	SaveGame.dir = "user://test_saves"
	# A pad in use elsewhere (say, in another game) would steer the games under
	# test. Ignored once we count as unfocused; the tests' own button presses go
	# through the viewport, which this doesn't filter.
	Input.ignore_joypad_on_unfocused_application = true
	Engine.get_main_loop().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
