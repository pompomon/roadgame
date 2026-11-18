shader_type canvas_item;

// A legend's silhouette in the Book of Legends (ENDGAME_PLAN.md §5.10, W26): its still's shape,
// each texel in `fill`, BookScreen.SILHOUETTE, with the texel's alpha.
uniform vec4 fill = vec4(1.0);

void fragment() {
	COLOR = vec4(fill.rgb, COLOR.a);
}
