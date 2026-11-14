// The props' lights at night (docs/DAYNIGHT.md §5.12, P10): Godot 4.7.2's own canvas group shader
// (drivers/gles3/rasterizer_canvas_gles3.cpp, default_canvas_group_shader), but adding what the
// group holds to what is under it, as the legends' glows add (docs/M6.md §5.5).

shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);

	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}

	COLOR *= c;
}
