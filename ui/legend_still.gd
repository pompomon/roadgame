class_name LegendStill
extends Sprite2D
## A legend's still (ENDGAME_PLAN.md §5.8), as the arrival's welcome shows it, and the Book: the
## frame of its figure that its scene names (Legend.figure, figure_frame), whole and in full view,
## whatever its rest pose hides, centred on the still's position. It draws as the figure does, in
## its texture and frames, its flips, its self_modulate and its material, at its z_index: a glow
## stays above the veil, and lights the world. A frame smaller than Tuning.STILL_MIN_SIDE px is
## scaled up by the least whole number that makes it as large, so that its pixels stay square.

## The legend's id (DisasterBase.id).
var id := &""


## The still of the legend whose scene is `scene`, or null, with an error, if it isn't a legend or
## names no figure.
static func of(scene: PackedScene) -> LegendStill:
	var node: Node = scene.instantiate() if scene != null and scene.can_instantiate() else null
	var legend := node as Legend
	var still: LegendStill = null
	if legend == null:
		var path := scene.resource_path if scene != null else "<null>"
		push_error("LegendStill: %s isn't a legend" % path)
	elif legend.figure == null:
		push_error("LegendStill: %s names no figure" % legend.id)
	else:
		var figure := legend.figure
		still = LegendStill.new()
		still.id = legend.id
		still.texture = figure.texture
		still.hframes = figure.hframes
		still.vframes = figure.vframes
		still.frame = legend.figure_frame
		still.flip_h = figure.flip_h
		still.flip_v = figure.flip_v
		still.self_modulate = figure.self_modulate
		still.material = figure.material
		still.z_index = figure.z_index
		still.z_as_relative = figure.z_as_relative
		var side := maxf(still.get_rect().size.x, still.get_rect().size.y)
		still.scale = Vector2.ONE * maxf(1.0, ceilf(Tuning.STILL_MIN_SIDE / maxf(side, 1.0)))
	if node != null:
		node.free()
	return still
