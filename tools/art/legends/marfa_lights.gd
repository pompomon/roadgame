extends RefCounted
## The Marfa Lights' sheet (docs/POOLS.md §5.4), drawn into assets/legends/marfa_lights/ by
## tools/art/make_legends.gd. `tracks.png`: the tyre tracks that the car leaves as it follows the
## lights off the road, up the screen, smaller and smaller: two dark grooves that run from under its
## back wheels to where it goes, and meet there, narrowing from 2 px to 1 as they go. They are in
## the palette's shadow, far darker than the Desert's ground, so they show by night (§5.6). Their
## sizes are the legend's (disasters/legends/marfa_lights.gd). No class_name: tools/ is not
## exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const MarfaLightsLegend := preload("res://disasters/legends/marfa_lights.gd")
## The share of the rows, from the bottom, where each groove is 2 px wide: the rest is 1 px.
const WIDE_SHARE := 0.5


static func make(dir: String) -> void:
	var size := MarfaLightsLegend.TRACKS
	var tracks := LegendArt.new(size)
	# The left groove, row by row from the bottom: its middle runs from GAUGE px left of the foot to
	# the top's middle. mirror() draws the right one.
	for row: int in range(1, size.y + 1):
		var middle := -MarfaLightsLegend.GAUGE * (1.0 - (row - 0.5) / size.y)
		var wide := row <= size.y * WIDE_SHARE
		var left := roundi(middle - (1.0 if wide else 0.5))
		for x: int in range(left, left + (2 if wide else 1)):
			tracks.plot(Vector2i(x, -row), "shadow")
	tracks.mirror()
	tracks.save(dir.path_join("tracks.png"))
