class_name Dice
# Every roll the rules make (Fragile, armour, intercepts, where a mine hits),
# from one generator of their own. Nothing else draws on it, so a networked
# game can replay a move identically on both machines from the host's seed.

static var _rng := RandomNumberGenerator.new()


# A roll from 0 to 1
static func roll() -> float:
	return _rng.randf()


static func pick(from: Array) -> Variant:
	return from[_rng.randi_range(0, from.size() - 1)]


# Rolls the same from here on, wherever it's given the same seed
static func reseed(new_seed: int) -> void:
	_rng.seed = new_seed
	_rng.state = 0
