class_name Dice
extends RefCounted
# Every roll the rules make (Fragile, armour, intercepts, where a mine hits),
# from a generator of the game's own (Grid.dice). Nothing else draws on it, so
# a networked game can replay a move identically on both machines from the
# host's seed, and two games in one process (tests) don't share one.

var _rng := RandomNumberGenerator.new()


func roll() -> float:
	return _rng.randf()


func pick(from: Array) -> Variant:
	return from[_rng.randi_range(0, from.size() - 1)]


func reseed(new_seed: int) -> void:
	# Setting the seed sets the state from it; setting the state afterwards would
	# undo that, and every seed would roll the same
	_rng.seed = new_seed
