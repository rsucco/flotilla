class_name Ambient
# Slow background animation (the sea, an idling rotor) moves on in steps, all
# on the one beat, so a still board draws a dozen frames a second rather than
# one for each thing that moves, or every frame (a handheld's battery).

const STEP := 1.0 / 12.0


# Which beat it is: something animating ambiently moves on when this changes
static func beat() -> int:
	return int(Time.get_ticks_msec() / (STEP * 1000.0))
