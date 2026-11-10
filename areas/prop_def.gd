class_name PropDef
extends Resource
## A prop that an area scatters on its ground (plan.md §5.2, M5_PLAN.md §5.6): a sprite from the
## area's props sheet, which stands with its foot on the centre of a ground cell. PropScatter gives
## each ground cell beside the road one prop or none, by the cell's hash and the densities.

@export var id := &""
## The props sheet that has its frames.
@export var texture: Texture2D
## Its first frame, in pixels of `texture`. The others follow it to the right, as wide.
@export var region := Rect2i()
@export_range(1, 16) var frames := 1
## Frames per second of its animation, or 0 for a prop that stands still.
@export_range(0.0, 30.0, 0.5) var fps := 0.0
## The pixel of a frame that stands on the ground, from the frame's top left.
@export var foot := Vector2i()
## The chance that a ground cell beside the road shows it.
@export_range(0.0, 1.0, 0.001) var density := 0.0


## Returns what breaks the props' contract (M5_PLAN.md §5.6), or nothing.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if texture == null:
		problems.append("prop %s has no texture" % id)
		return problems
	# @export_range keeps only the inspector from fewer frames: a hand-written .tres may have them.
	if frames < 1:
		problems.append("prop %s has %d frames" % [id, frames])
	elif region.size.x <= 0 or region.size.y <= 0:
		problems.append("prop %s: its region is empty" % id)
	else:
		var strip := Rect2i(region.position, region.size * Vector2i(frames, 1))
		if not Rect2i(Vector2i.ZERO, texture.get_size()).encloses(strip):
			problems.append("prop %s: its %d frames reach out of its texture" % [id, frames])
	if (frames > 1) != (fps > 0.0):
		problems.append("prop %s: %d frames at %.1f fps" % [id, frames, fps])
	if not Rect2i(Vector2i.ZERO, region.size + Vector2i.ONE).has_point(foot):
		problems.append("prop %s: its foot is outside its frame" % id)
	if 2 * maxi(foot.x, region.size.x - foot.x) > Tuning.PROP_MAX_SIZE.x:
		problems.append("prop %s is wider than PROP_MAX_SIZE allows" % id)
	if foot.y > Tuning.PROP_MAX_SIZE.y or region.size.y - foot.y > Tuning.PROP_BELOW:
		problems.append("prop %s is taller than PROP_MAX_SIZE and PROP_BELOW allow" % id)
	if density < 0.0 or density > 1.0:
		problems.append("prop %s: density is outside 0..1" % id)
	return problems
