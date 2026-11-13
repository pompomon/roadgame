// Lays the props' shadows on the ground (DAYNIGHT_PLAN.md §5.11, C20): a frame's width along lay_x
// and its height along lay_y, from the sprite's position, where its shadow falls from. Shadows sets
// the two for each kind of shadow as the clock turns, so that no sprite moves.

shader_type canvas_item;

uniform vec2 lay_x = vec2(1.0, 0.0);
uniform vec2 lay_y = vec2(0.0, 1.0);

void vertex() {
	// In the sprite's own space: its transform comes after.
	VERTEX = lay_x * VERTEX.x + lay_y * VERTEX.y;
}
