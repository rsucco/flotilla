extends GutHookScript
# Keeps the run's saves (every hand-off autosaves) out of the player's own


func run() -> void:
	SaveGame.dir = "user://test_saves"
