class_name LegendStill
extends Sprite2D
## A legend's still (ENDGAME_PLAN.md §5.8), as the arrival's welcome shows it, and the Book: the
## frame of its figure that its scene names (Legend.figure, figure_frame), whole and in full view,
## whatever its rest pose hides, centred on the still's position; or the Vanishing Hitchhiker's
## (§5.17), whose scene is her figure. It draws as the figure does, in its texture and frames, its
## flips, its self_modulate and its material, at its z_index: a glow stays above the veil, and
## lights the world. A glow's still has neither its legend's veil nor the alpha that its legend
## gives it, which keep the figure's light from clipping, so what stands one over a ground bounds
## its light by strength(). A frame smaller than Tuning.STILL_MIN_SIDE px is scaled up by the least
## whole number that makes it as large, so that its pixels stay square.

## The legend's id (DisasterBase.id).
var id := &""


## The still of the legend whose scene is `scene`, or null, with an error, if it isn't a legend or
## names no figure.
static func of(scene: PackedScene) -> LegendStill:
	var node: Node = scene.instantiate() if scene != null and scene.can_instantiate() else null
	var legend := node as Legend
	var hitchhiker := node as Hitchhiker
	var still: LegendStill = null
	if hitchhiker != null:
		still = _drawn(Hitchhiker.ID, hitchhiker, hitchhiker.frame)
	elif legend == null:
		var path := scene.resource_path if scene != null else "<null>"
		push_error("LegendStill: %s isn't a legend" % path)
	elif legend.figure == null:
		push_error("LegendStill: %s names no figure" % legend.id)
	else:
		still = _drawn(legend.id, legend.figure, legend.figure_frame)
	if node != null:
		node.free()
	return still


## The still of the legend `legend_id`, as its `figure` draws its frame `figure_frame`.
static func _drawn(legend_id: StringName, figure: Sprite2D, figure_frame: int) -> LegendStill:
	var still := LegendStill.new()
	still.id = legend_id
	still.texture = figure.texture
	still.hframes = figure.hframes
	still.vframes = figure.vframes
	still.frame = figure_frame
	still.flip_h = figure.flip_h
	still.flip_v = figure.flip_v
	still.self_modulate = figure.self_modulate
	still.material = figure.material
	still.z_index = figure.z_index
	still.z_as_relative = figure.z_as_relative
	var side := maxf(still.get_rect().size.x, still.get_rect().size.y)
	still.scale = Vector2.ONE * maxf(1.0, ceilf(Tuning.STILL_MIN_SIDE / maxf(side, 1.0)))
	return still


## How much of its light the still may show over `ground`, the colour under it as drawn by day: all
## of it, unless it adds light as a glow does. Then it adds to no channel more than the ground
## leaves below white, as if its texels were white, so that it never clips, in any light (docs/M6.md
## S10, Lamps.strength()).
func strength(ground: Color) -> float:
	var blend := material as CanvasItemMaterial
	if blend == null or blend.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		return 1.0
	var shown := 1.0
	for channel: int in 3:
		var glow: float = self_modulate[channel] * self_modulate.a
		if glow > 0.0:
			shown = minf(shown, (1.0 - ground[channel]) / glow)
	return maxf(shown, 0.0)
