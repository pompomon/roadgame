extends RefCounted
## Frau Holle's well's sheet (POOLS_PLAN.md §5.4), drawn into assets/legends/frau_holle/ by
## tools/art/make_legends.gd. `well.png`: a round well of grey stone, its mouth dark, under a
## windlass of planks with a rope and a bucket: bare as it rises, dusted with snow, then capped with
## it and the snow drifted at its foot. Its greys are about as bright as the Village's road and
## ground, so its outline, its mortar, its mouth and its windlass's shade are dark, and they show by
## night (§5.6). Its sizes are the legend's (disasters/legends/frau_holle.gd). No class_name: tools/
## is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const FrauHolleLegend := preload("res://disasters/legends/frau_holle.gd")
## The shaft, in px from the well's foot: its top, the rim, and its foot, ovals of RADII about RIM
## and BASE, and its wall between them, shaded from SHADE_X to its right. Its rows of stones, by the
## height over the foot's front edge of the mortar between them, and the joints between the stones
## of each row, by x, from the foot up. The joints in the rim, by their angles about it.
const RADII := Vector2(21.0, 9.0)
const RIM := Vector2(0.0, -26.0)
const BASE := Vector2(0.0, -10.0)
const SHADE_X := 9
const COURSES: Array[float] = [5.5, 11.0]
const JOINTS: Array[Array] = [[-14, -5, 4, 13], [-18, -9, 0, 9, 18], [-14, -5, 4, 13]]
const RIM_JOINTS: Array[float] = [0.5, 1.2, 1.95, 2.65, 3.6, 4.3, 5.1, 5.8]
## Its mouth: an oval of MOUTH_RADII about the rim's middle, the far side of the shaft in shade, and
## the deep, dark, where it overlaps the same oval DEEP px lower.
const MOUTH_RADII := Vector2(15.0, 5.5)
const DEEP := 1.5
## The windlass: its posts, each with its shaded side to the right, standing on the rim's ends; its
## axle, a log shaded beneath; its crank, a line through its points, beyond the right post; the rope
## that hangs from the axle; and the bucket on it, over the mouth, with a band BAND px down it.
const POSTS: Array[Rect2i] = [Rect2i(-22, -52, 3, 26), Rect2i(19, -52, 3, 26)]
const AXLE := Rect2i(-19, -47, 38, 2)
const CRANK: Array[Vector2] = [Vector2(22, -46), Vector2(25, -46), Vector2(25, -42)]
const ROPE: Array[Vector2] = [Vector2(0, -45), Vector2(0, -42)]
const BUCKET := Rect2i(-3, -41, 6, 6)
const BAND := 3
## The snow. Dusted: on the rim's far side, DUST px deep; a px deep on each post and along the
## axle; and in flakes on the stone. Capped: over the rim, its front lip in shade and
## heaped CAP px over its far side; CAP px deep on each post, the axle and the bucket; and drifted
## at the foot, in ovals by their middles and radii.
const DUST := 1.5
const FLAKES: Array[Vector2i] = [
	Vector2i(-17, -22),
	Vector2i(-8, -15),
	Vector2i(-2, -19),
	Vector2i(6, -13),
	Vector2i(13, -21),
	Vector2i(-12, -8),
	Vector2i(16, -10),
]
const CAP := 2
const DRIFTS: Array[Rect2] = [Rect2(-12, -4, 9, 2.5), Rect2(11, -3, 7, 2)]


static func make(dir: String) -> void:
	var well := LegendArt.new(FrauHolleLegend.WELL, FrauHolleLegend.Cap.size())
	for frame: int in FrauHolleLegend.Cap.size():
		well.frame = frame
		_draw_well(well, frame)
	well.save(dir.path_join("well.png"))


## The well in its sheet's `frame`, a Cap: the snow on the stone lies behind the windlass, which
## the snow on its tops lies on.
static func _draw_well(art: LegendArt, frame: int) -> void:
	_draw_shaft(art)
	if frame == FrauHolleLegend.Cap.DUSTED:
		_dust_stone(art)
	elif frame == FrauHolleLegend.Cap.CAPPED:
		_cap_stone(art)
	_draw_windlass(art)
	if frame == FrauHolleLegend.Cap.DUSTED:
		_dust_tops(art)
	elif frame == FrauHolleLegend.Cap.CAPPED:
		_cap_tops(art)
	art.outline()


## The stone shaft and its mouth.
static func _draw_shaft(art: LegendArt) -> void:
	art.rect(
		Rect2i(-int(RADII.x), int(RIM.y), int(RADII.x) * 2, int(BASE.y - RIM.y)), "city ground"
	)
	art.ellipse(BASE, RADII, "city ground")
	for y: int in range(int(RIM.y), int(BASE.y + RADII.y)):
		for x: int in range(SHADE_X, int(RADII.x)):
			if art.image.get_pixelv(_pixel(art, Vector2i(x, y))).a > 0.0:
				art.plot(Vector2i(x, y), "city dark")
	for height: float in COURSES:
		for x: int in range(-int(RADII.x), int(RADII.x)):
			art.plot(Vector2i(x, floori(_front(BASE, x) - height)), "shadow")
	var heights: Array[float] = [0.0]
	heights.append_array(COURSES)
	heights.append(BASE.y - RIM.y)
	for row: int in JOINTS.size():
		for x: int in JOINTS[row]:
			var low := floori(_front(BASE, x) - heights[row])
			for y: int in range(floori(_front(BASE, x) - heights[row + 1]) + 1, low):
				art.plot(Vector2i(x, y), "shadow")
	art.ellipse(RIM, RADII, "city light")
	for angle: float in RIM_JOINTS:
		var way := Vector2.from_angle(angle)
		art.line(RIM + way * MOUTH_RADII, RIM + way * RADII, "shadow")
	art.ellipse(RIM, MOUTH_RADII, "shadow")
	_overlap(art, RIM, RIM + Vector2(0.0, DEEP), MOUTH_RADII, "ink")


## The windlass over the mouth, with its rope and bucket.
static func _draw_windlass(art: LegendArt) -> void:
	for post: Rect2i in POSTS:
		art.rect(post, "plank")
		art.rect(Rect2i(post.end.x - 1, post.position.y, 1, post.size.y), "shadow")
	art.rect(AXLE, "plank")
	art.rect(Rect2i(AXLE.position.x, AXLE.end.y - 1, AXLE.size.x, 1), "shadow")
	for k: int in CRANK.size() - 1:
		art.line(CRANK[k], CRANK[k + 1], "shadow")
	art.line(ROPE[0], ROPE[1], "line")
	art.rect(BUCKET, "plank")
	art.rect(Rect2i(BUCKET.position, Vector2i(BUCKET.size.x, 1)), "shadow")
	art.rect(Rect2i(BUCKET.position.x, BUCKET.position.y + BAND, BUCKET.size.x, 1), "ink")


## A dusting of snow on the stone: on the rim's far side, and in flakes.
static func _dust_stone(art: LegendArt) -> void:
	_overlap(art, RIM, RIM, RADII, "white", Vector2(0.0, DUST))
	for flake: Vector2i in FLAKES:
		art.plot(flake, "white")


## And on the windlass: a px deep on each post and along the axle.
static func _dust_tops(art: LegendArt) -> void:
	for post: Rect2i in POSTS:
		art.rect(Rect2i(post.position.x, post.position.y - 1, post.size.x, 1), "white")
	art.rect(Rect2i(AXLE.position.x, AXLE.position.y - 1, AXLE.size.x, 1), "white")


## A cap of snow over the rim, heaped at its far side, its front lip in shade, round the mouth; and
## drifts at the foot.
static func _cap_stone(art: LegendArt) -> void:
	art.ellipse(RIM - Vector2(0.0, CAP), RADII, "white")
	art.ellipse(RIM, RADII, "white")
	for x: int in range(-int(RADII.x), int(RADII.x)):
		art.plot(Vector2i(x, floori(_front(RIM, x))), "foam")
	art.ellipse(RIM, MOUTH_RADII, "shadow")
	_overlap(art, RIM, RIM + Vector2(0.0, DEEP), MOUTH_RADII, "ink")
	for drift: Rect2 in DRIFTS:
		art.ellipse(drift.position, drift.size, "white")


## And CAP px deep on each post, the axle and the bucket.
static func _cap_tops(art: LegendArt) -> void:
	for post: Rect2i in POSTS:
		art.rect(Rect2i(post.position.x, post.position.y - CAP, post.size.x, CAP), "white")
	art.rect(Rect2i(AXLE.position.x, AXLE.position.y - CAP, AXLE.size.x, CAP), "white")
	art.rect(Rect2i(BUCKET.position.x, BUCKET.position.y - CAP, BUCKET.size.x, CAP), "white")


## The y of the front edge of the oval of RADII about `centre`, at the middle of column `x`.
static func _front(centre: Vector2, x: int) -> float:
	var across := (x + 0.5 - centre.x) / RADII.x
	return centre.y + RADII.y * sqrt(maxf(0.0, 1.0 - across * across))


## Fills the pixels whose centres are inside both the oval of `radii` about `first` and that about
## `second`, and, if `outside` isn't zero, not inside the oval about `first` + `outside`.
static func _overlap(
	art: LegendArt,
	first: Vector2,
	second: Vector2,
	radii: Vector2,
	paint: String,
	outside := Vector2.ZERO
) -> void:
	for y: int in range(floori(first.y - radii.y), ceili(first.y + radii.y)):
		for x: int in range(floori(first.x - radii.x), ceili(first.x + radii.x)):
			var at := Vector2(x, y) + Vector2(0.5, 0.5)
			var inside := _in(at, first, radii) and _in(at, second, radii)
			if outside != Vector2.ZERO:
				inside = inside and not _in(at, first + outside, radii)
			if inside:
				art.plot(Vector2i(x, y), paint)


static func _in(at: Vector2, centre: Vector2, radii: Vector2) -> bool:
	return ((at - centre) / radii).length_squared() <= 1.0


## The sheet's pixel `at` px from the foot of the frame being drawn.
static func _pixel(art: LegendArt, at: Vector2i) -> Vector2i:
	return Vector2i(art.frame * art.frame_size.x + (art.frame_size.x >> 1), art.frame_size.y) + at
