// The sea's swell, shared by the shaders that show it (the board's, and a
// submarine's, seen through it), so their crests line up: one wind, two
// swells a little apart in length and heading, so their crests gather into
// sets, and a lower chop across them. Flat-shaded in bands like the sprites.

// Seconds of animation, stepped by Root
global uniform float sea_phase;

// Where the wind blows from: the left, a little north of west
const vec2 WIND = vec2(0.96, 0.28);
const vec3 FOAM = vec3(0.85, 0.92, 0.97);
// The main swell's length (px), and its speed: deep water's, for that length
const float SWELL_LENGTH = 210.0;
const float SWELL_SPEED = 31.9;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


float fbm(vec2 p) {
	return 0.5 * noise(p) + 0.3 * noise(p * 2.1 + 3.7) + 0.2 * noise(p * 4.3 + 9.1);
}


vec2 turn(vec2 v, float a) {
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}


// One train of waves `length` px apart, at deep water's speed for that
// length; peaked crests and wide troughs, as real waves are
float wave(vec2 p, vec2 dir, float length, float sharp, float t) {
	float speed = 2.2 * sqrt(length);
	float s = sin(6.2832 / length * (dot(dir, p) - speed * t));
	return pow(0.5 + 0.5 * s, sharp);
}


// Where the noise bends a point to, so the crests don't run in ruled lines
vec2 bent(vec2 p, float t) {
	vec2 bend = vec2(fbm(p / 400.0 + t * 0.015), fbm(p / 400.0 + 5.2 - t * 0.01)) - 0.5;
	return p + bend * 70.0;
}


// How high the sea is at bent point `q` (about 0 to 1.1)
float swell(vec2 q, float t) {
	float trains = (
		0.6 * wave(q, WIND, SWELL_LENGTH, 3.0, t) + 0.4 * wave(q, turn(WIND, 0.3), 150.0, 3.0, t)
	);
	float chop = (
		wave(q, turn(WIND, 0.6), 46.0, 2.0, t) + wave(q, turn(WIND, -0.7), 29.0, 2.0, t)
	);
	// The crests rise and fall along their length
	trains *= 0.7 + 0.3 * fbm(q / 160.0 * vec2(1.0, 0.4) - WIND * t * 0.05);
	return trains + 0.1 * chop;
}


// How long since the main swell's last crest passed bent point `q`, as a
// share of the time between crests (0 to 1)
float since_crest(vec2 q, float t) {
	return fract((SWELL_SPEED * t - dot(WIND, q)) / SWELL_LENGTH + 0.25);
}


// The sea at `p` over `sea`, its colour there: mostly lit faces and crests,
// the sea's own blue between them, here and there a deeper trough, and
// whitecaps where the crests run highest, streaked downwind
vec3 waves(vec3 sea, vec2 p, float t) {
	float h = swell(bent(p, t), t);
	vec3 col = sea;
	if (h > 0.42) {
		col = sea * 1.12 + vec3(0.1, 0.14, 0.16);
	} else if (h > 0.15) {
		col = sea * 1.08 + vec3(0.02, 0.04, 0.05);
	} else if (h < 0.06 && fbm(p / 180.0 + vec2(t * 0.02, 0.0)) > 0.55) {
		col = sea * 0.82;
	}
	vec2 along = vec2(dot(p, WIND) / 30.0, dot(p, vec2(-WIND.y, WIND.x)) / 9.0);
	if (h > 0.55 && fbm(along + vec2(t * 0.25, t * 0.1)) > 0.68) {
		col = FOAM;
	}
	return col;
}
