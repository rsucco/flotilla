class_name HiddenPlayer
extends Player
# A player whose fleet the one at this screen never sees: the AI, or the
# player at the other end of a LAN game. Its turn plays out live, with its
# ships cloaked (Root has the turn replay mask its shots).


func new_turn() -> void:
	super()
	_take_the_helm()


func resume_turn() -> void:
	_take_the_helm()


func _take_the_helm() -> void:
	for ship in ships:
		ship.cloaked = true
		ship.visible = true
	active = true


# Copies of the opponent's ships we've seen are for us to know about, not to
# put on the opponent's screen
func show_revealed(_ship: Ship) -> void:
	pass


func finish_turn() -> void:
	super()
	for ship in ships:
		ship.cloaked = false
		ship.visible = false
	active = false
