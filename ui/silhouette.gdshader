shader_type canvas_item;

// A legend's silhouette in the Book of Legends (docs/ENDGAME.md §5.10, W26): its still's shape, flat
// in `fill`, BookScreen.SILHOUETTE. Each texel that the still covers at all is drawn whole: a glow's
// alpha falls to nothing at its edge, and with it, most of a glow's silhouette would hardly stand out
// from its cell. A pixel-art still's texels are whole or clear already.
uniform vec4 fill = vec4(1.0);

void fragment() {
	COLOR = vec4(fill.rgb, ceil(COLOR.a));
}
