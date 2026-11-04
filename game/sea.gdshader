shader_type canvas_item;
// The sea for Root's board, flat-shaded in bands like the sprites: a swell
// rolling in on one wind, with whitecaps on the highest crests, and down
// no-man's-land (drawn with a UV of (1, 0)) a current. Only the water's fill
// is touched, picked out by its blue vertex colour, so labels, markers and
// islands stay as drawn. Root steps `phase` a few times a second rather than
// the shader reading TIME, which would redraw the screen every frame.

// Seconds of animation, stepped by Root
uniform float phase = 0.0;
// The water is worked out on a grid this many px across, for the sprites'
// pixel look
uniform float pixel = 2.0;

varying vec2 world;

// Where the wind blows from: the left, a little north of west
const vec2 WIND = vec2(0.96, 0.28);
const vec3 FOAM = vec3(0.85, 0.92, 0.97);


void vertex() {
	world = VERTEX;
}


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


// The open sea: two swells a little apart in length and heading, so their
// crests gather into sets and thin out between, and a lower chop across them
vec3 waves(vec3 sea, vec2 p, float t) {
	// The noise bends the crests so they don't run in ruled lines
	vec2 bend = vec2(fbm(p / 400.0 + t * 0.015), fbm(p / 400.0 + 5.2 - t * 0.01)) - 0.5;
	vec2 q = p + bend * 70.0;
	float swell = 0.6 * wave(q, WIND, 210.0, 3.0, t) + 0.4 * wave(q, turn(WIND, 0.3), 150.0, 3.0, t);
	float chop = (
		wave(q, turn(WIND, 0.6), 46.0, 2.0, t) + wave(q, turn(WIND, -0.7), 29.0, 2.0, t)
	);
	// The crests rise and fall along their length
	swell *= 0.7 + 0.3 * fbm(q / 160.0 * vec2(1.0, 0.4) - WIND * t * 0.05);
	float h = swell + 0.1 * chop;
	// Mostly lit faces and crests, the sea's own blue between them, and here
	// and there a deeper trough
	vec3 col = sea;
	if (h > 0.42) {
		col = sea * 1.12 + vec3(0.1, 0.14, 0.16);
	} else if (h > 0.15) {
		col = sea * 1.08 + vec3(0.02, 0.04, 0.05);
	} else if (h < 0.06 && fbm(p / 180.0 + vec2(t * 0.02, 0.0)) > 0.55) {
		col = sea * 0.82;
	}
	// Whitecaps where the crests run highest, coming and going with the
	// noise, streaked downwind
	vec2 along = vec2(dot(p, WIND) / 30.0, dot(p, vec2(-WIND.y, WIND.x)) / 9.0);
	if (h > 0.55 && fbm(along + vec2(t * 0.25, t * 0.1)) > 0.68) {
		col = FOAM;
	}
	return col;
}


// No-man's-land: streaks drawn out along the flow and carried down it, with
// faster flow lines over them, both meandering a little
vec3 current(vec3 sea, vec2 p, float t) {
	p.x += 5.0 * sin(p.y / 70.0 + t * 0.4);
	float streak = fbm(vec2(p.x / 16.0, (p.y - t * 26.0) / 150.0));
	vec3 col = sea * 0.85;
	if (streak > 0.6) {
		col = sea * 1.3 + vec3(0.02, 0.05, 0.07);
	} else if (streak > 0.46) {
		col = sea * 1.1;
	}
	float line = fbm(vec2(p.x / 5.0, (p.y - t * 40.0) / 110.0) + 11.0);
	if (line > 0.76) {
		col = mix(sea, FOAM, 0.45);
	}
	return col;
}


void fragment() {
	// Blue well above red: the water and the hover/selection blues, never
	// labels, outlines, red hits or orange islands
	float water = smoothstep(0.2, 0.32, COLOR.b - COLOR.r);
	vec2 p = (floor(world / pixel) + 0.5) * pixel;
	vec3 col = UV.x > 0.5 ? current(COLOR.rgb, p, phase) : waves(COLOR.rgb, p, phase);
	COLOR.rgb = mix(COLOR.rgb, col, water);
}
