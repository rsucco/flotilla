shader_type canvas_item;
// The sea for Root's board (the swell itself is in swell.gdshaderinc, shared
// with the submarine's): the open sea; down no-man's-land (drawn with a UV of
// (1, 0)) a current; and around the islands (UV (0.5, how far out)) shallows,
// with a breaker coming in as each crest of the swell arrives, or (UV (0.4,
// how far out)) where they face no-man's-land, a narrow shelf over the
// current, dropping off into deep water. Only the water's fill is touched,
// picked out by its blue vertex colour, so labels, markers and islands stay as
// drawn. Root steps `sea_phase` rather than the
// shader reading TIME, which would redraw the screen every frame.

#include "res://game/swell.gdshaderinc"

// The water is worked out on a grid this many px across, for the sprites'
// pixel look
uniform float pixel = 2.0;

varying vec2 world;

// How long a breaker takes to come in across the shallows, as a share of the
// time between crests
const float BREAKING = 0.3;


void vertex() {
	world = VERTEX;
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


// Near an island, `far` from its coast (0) to the edge of the shallows (1):
// lighter water over the sand; as each crest of the swell arrives, a breaker
// rolls in across the shallows and the surf surges up the shore. The crests
// sweep past an island, so the surf comes round it, side by side. The noise
// roughens the bands, so the coast isn't ruled, but they stay short of where
// the strip ends.
vec3 coast(vec3 col, vec2 p, float far, float t, bool deep) {
	float rough = fbm(p / 25.0);
	float d = far + (rough - 0.5) * 0.35;
	// Lighter water over the sand, brightening the waves already drawn rather
	// than covering them, so their bands carry on through
	if (deep) {
		// Only a narrow shelf before the drop-off, and surf against it
		if (d < 0.3) {
			col = col * 1.25 + vec3(0.02, 0.06, 0.08);
		}
		if (d < 0.1 + 0.06 * sin(t * 1.2 + rough * 9.0)) {
			col = FOAM;
		}
		return col;
	}
	if (d < 0.45) {
		col = col * 1.3 + vec3(0.03, 0.08, 0.1);
	} else if (d < 0.75) {
		col = col * 1.12 + vec3(0.01, 0.03, 0.04);
	}
	float since = since_crest(bent(p, t), t);
	// The breaker, from the edge of the shallows in to the shore
	float breaker = 0.75 * (1.0 - since / BREAKING);
	if (since < BREAKING && abs(d - breaker) < 0.06) {
		col = mix(col, FOAM, 0.75);
	}
	// The surf, surging up the shore as it breaks, then running back
	float surge = clamp((since - BREAKING) / 0.15, 0.0, 1.0) * (1.0 - smoothstep(0.45, 0.8, since));
	if (d < 0.08 + 0.14 * surge) {
		col = FOAM;
	}
	return col;
}


void fragment() {
	// Blue well above red: the water and the hover/selection blues, never
	// labels, outlines, red hits or orange islands
	float water = smoothstep(0.2, 0.32, COLOR.b - COLOR.r);
	vec2 p = (floor(world / pixel) + 0.5) * pixel;
	bool deep = UV.x > 0.25 && UV.x < 0.45;
	bool flowing = UV.x > 0.75 || deep;
	vec3 col = flowing ? current(COLOR.rgb, p, sea_phase) : waves(COLOR.rgb, p, sea_phase);
	if (UV.x > 0.25 && UV.x < 0.75) {
		col = coast(col, p, UV.y, sea_phase, deep);
	}
	COLOR.rgb = mix(COLOR.rgb, col, water);
}
