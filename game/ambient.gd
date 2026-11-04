class_name Ambient
# Background animation (the sea, an idling rotor) moves on in steps, all on
# the one beat, so a still board draws at most 60 frames a second, however
# many things move or however fast the display (a handheld's battery).

const STEP := 1.0 / 60.0
# A slow frame can miss beats, which are made up, but no more than this many,
# so a pause doesn't send it all leaping ahead
const MOST := 6


# Which beat it is: something animating ambiently moves on when this changes
static func beat() -> int:
	return int(Time.get_ticks_msec() / (STEP * 1000.0))


# How far (seconds) something that last moved on at beat `last` should move on now
static func since(last: int) -> float:
	return mini(beat() - last, MOST) * STEP
