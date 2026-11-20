class_name PropDef
extends Resource
## A prop that an area scatters on its ground (plan.md §5.2, docs/M5.md §5.6): a sprite from the
## area's props sheet, which stands with its foot on the centre of a ground cell. PropScatter gives
## each lot of ground beside the road one prop or none, by the lot's hash and the densities: most
## props take a lot of one cell, and a building a lot of 2 × 2 (docs/VISUALS.md §5.4), more often
## by a street (§5.8).

## How its shadow falls (docs/DAYNIGHT.md §5.11). UPRIGHT: as a prop that stands at a point and
## is as wide whichever way the light comes from, such as a tree: the rows of its frame above that
## point are laid on the ground away from the light. WALL: as a wall along the tile y axis, up-right
## on the screen, such as a fence: each pixel's shadow falls from the wall's base below it. NONE:
## it lies flat, and casts none.
enum Shadow { UPRIGHT, WALL, NONE }

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
## Where it gives light at night (docs/DAYNIGHT.md §5.12), in pixels from its foot: boxes that a
## glow fills, such as a lamp's head or a lit window, and boxes of the ground that its light falls
## on, which glow more faintly.
@export var lights: Array[Rect2] = []
@export var light_pools: Array[Rect2] = []
## The ground it takes, in cells a side: a lot of `lot` × `lot` cells, aligned with its tile's
## corner, whose front cell its foot stands on the centre of. No other prop stands on a lot that
## shows it, so a box wider than a cell, such as a building, stands in no other prop.
@export_range(1, 4) var lot := 1
## The chance that a lot of its size beside the road shows it.
@export_range(0.0, 1.0, 0.001) var density := 0.0
## The chance that a lot of its size by a street shows it: a lot with a side on a road tile's, but
## not just a corner. -1 for `density`'s (docs/VISUALS.md §5.8).
@export_range(-1.0, 1.0, 0.001) var street_density := -1.0
## Whether it may rise over the road behind it. A prop that may not is left out where its frame
## would touch a road tile's diamond (PropLayout.touches_road()). One that may is a box whose base,
## which its shadow falls from the middle of, lies in its lot, as a building's does: so it never
## stands on the road. It fades wherever it would hide the car or a legend (docs/VISUALS.md §5.9).
@export var see_through := false
@export var shadow := Shadow.UPRIGHT
## How far above the foot, in pixels of the frame, the point that its shadow falls from is: the
## centre of a box's footprint, or where a wall's base line crosses the foot's column.
@export var shadow_rise := 0
## Whether its animation slows to a stop at night and starts again by day, as a windmill's sails
## do, which the miller stops for the night (HEADLIGHTS_PLAN.md §5.5). Only a prop that animates
## may rest.
@export var rests_at_night := false


## Returns what breaks the props' contract (docs/M5.md §5.6), or nothing.
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
	if rests_at_night and frames < 2:
		problems.append("prop %s rests at night, but doesn't animate" % id)
	if not Rect2i(Vector2i.ZERO, region.size + Vector2i.ONE).has_point(foot):
		problems.append("prop %s: its foot is outside its frame" % id)
	if 2 * maxi(foot.x, region.size.x - foot.x) > Tuning.PROP_MAX_SIZE.x:
		problems.append("prop %s is wider than PROP_MAX_SIZE allows" % id)
	if foot.y > Tuning.PROP_MAX_SIZE.y or region.size.y - foot.y > Tuning.PROP_BELOW:
		problems.append("prop %s is taller than PROP_MAX_SIZE and PROP_BELOW allow" % id)
	if lot < 1 or Iso.GROUND_PER_TILE % lot != 0:
		problems.append("prop %s: a lot of %d cells doesn't divide a tile" % [id, lot])
	if density < 0.0 or density > 1.0:
		problems.append("prop %s: density is outside 0..1" % id)
	if street_density != -1.0 and (street_density < 0.0 or street_density > 1.0):
		problems.append("prop %s: street_density is outside 0..1, and isn't -1" % id)
	if shadow not in Shadow.values():
		problems.append("prop %s: its shadow is %d" % [id, shadow])
	elif shadow != Shadow.NONE and (shadow_rise < 0 or shadow_rise >= foot.y):
		problems.append("prop %s: its shadow rises outside its frame" % id)
	# A box's base reaches 2 * shadow_rise back from its foot, which is half a cell from its lot's
	# front corner: in cells' heights, 4 * shadow_rise / cell height <= 2 * lot - 1.
	if (
		see_through
		and (
			shadow != Shadow.UPRIGHT
			or 4 * shadow_rise * Iso.GROUND_PER_TILE > (2 * lot - 1) * Iso.TILE_H
		)
	):
		problems.append("prop %s is see-through, but not a box on its lot" % id)
	return problems


## The chance that a lot of its size shows it, by a street or not.
func chance(by_street: bool) -> float:
	return street_density if by_street and street_density >= 0.0 else density
