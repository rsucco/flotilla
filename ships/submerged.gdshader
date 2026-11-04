shader_type canvas_item;
// A submarine seen through the sea: its hull tinted the sea's blue, with the
// same swell passing over it, lined up with the board's (the sea's own
// shader shares swell.gdshaderinc and the global `sea_phase`).

#include "res://game/swell.gdshaderinc"

// The board's sea colour, which the hull is seen through, and how much
const vec3 SEA = vec3(0.04, 0.3, 0.52);
const float DEPTH = 0.45;
// The sea's pixel grid, so the crests' steps match the board's
uniform float pixel = 2.0;

varying vec2 world;


void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec2 p = (floor(world / pixel) + 0.5) * pixel;
	vec3 under = mix(COLOR.rgb, SEA, DEPTH);
	COLOR.rgb = waves(under, p, sea_phase);
}
