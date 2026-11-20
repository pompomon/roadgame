// The car's headlights (HEADLIGHTS_PLAN.md §5.2): the road's own material, so that they light the
// road and nothing else. In their cone each pixel of road is drawn brighter, by `gain` where the
// cone is brightest, and the night's veil darkens it less than the rest: all that is drawn on the
// road, after it, hides the light under it. By day `gain` is 0, and the road is drawn as before.

shader_type canvas_item;

// The cone's apex, at the car's lamps, in canvas pixels; and the rows that turn a canvas offset
// from it into tiles along the car's axis and across it.
uniform vec2 origin;
uniform vec2 along;
uniform vec2 across;
// In tiles: how far the cone reaches, its half width at the lamps, and how much wider it is each
// tile on. It dims from dim_from of its reach on, and from edge of its half width out.
uniform float reach;
uniform float half_width;
uniform float spread;
uniform float dim_from;
uniform float edge;
uniform vec3 gain;

varying vec2 canvas;

void vertex() {
	canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 offset = canvas - origin;
	float ahead = dot(along, offset);
	float aside = abs(dot(across, offset));
	float width = half_width + spread * max(ahead, 0.0);
	float lit = step(0.0, ahead) * (1.0 - smoothstep(dim_from * reach, reach, ahead));
	lit *= 1.0 - smoothstep(edge * width, width, aside);
	COLOR.rgb *= 1.0 + gain * lit;
}
