shader_type canvas_item;
// Light playing on the water, for Root's board. Only the sea hexes' fill is
// touched, picked out by its blue vertex colour, so labels, markers and
// islands stay as drawn. No-man's-land runs as a slow current. Root steps
// `phase` a few times a second rather than the shader reading TIME, which
// would redraw the screen every frame.

// Seconds of animation, stepped by Root
uniform float phase = 0.0;
// No-man's-land's left and right edges (x)
uniform vec2 channel = vec2(-1.0);
// How much the crests brighten the water
uniform float strength = 0.11;

varying vec2 world;


void vertex() {
	world = VERTEX;
}


void fragment() {
	vec4 sea = COLOR;
	// Blue well above red: the water and the hover/selection blues, never
	// black or white text, red hits, or orange islands
	float water = smoothstep(0.3, 0.5, sea.b - sea.r);
	vec2 p = world / 70.0;
	float t = phase * 0.6;
	if (world.x > channel.x && world.x < channel.y) {
		// Downstream, slower and calmer
		p.y -= phase * 0.35;
		t *= 0.5;
	}
	// Two crossing swells, each bent by the other, so the crests wander
	vec2 q = p + 0.4 * vec2(sin(p.y * 1.7 + t), cos(p.x * 1.3 - t * 0.9));
	float swell = sin(q.x * 2.1 + t * 0.7) * sin(q.y * 1.9 - t * 0.6);
	float crest = smoothstep(0.3, 1.0, swell);
	sea.rgb += strength * water * crest;
	COLOR = sea;
}
