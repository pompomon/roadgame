class_name SeeThrough
extends RefCounted
## How a see-through prop fades (docs/VISUALS.md §5.9). A building may rise over the road behind it
## (PropDef.see_through), so where it would hide the car, or a sprite that a legend stood on the
## Props layer, it shows PROP_SEE_THROUGH of itself, as the tunnel does (docs/M4.md K5), and comes
## back as they part. Visual only: what shows, and nothing that a seed plays.


## The opacity of a see-through prop whose frame is `frame`, with its foot at y `foot_y`, beside an
## actor whose rect is `actor`, which sorts at y `actor_y`. Props y-sorts them: the prop draws over
## the actor while its foot is lower on the screen, and the actor over it otherwise (A9). It is
## PROP_SEE_THROUGH where their rects meet and the prop is in front, and opaque once they are
## PROP_FADE_PX apart, across and down together, or once the actor is that far in front of it: so
## it changes by nothing as the actor comes in front of it, at a tie.
static func opacity(frame: Rect2, foot_y: float, actor: Rect2, actor_y: float) -> float:
	var gap := maxf(0.0, maxf(frame.position.x - actor.end.x, actor.position.x - frame.end.x))
	gap += maxf(0.0, maxf(frame.position.y - actor.end.y, actor.position.y - frame.end.y))
	gap += maxf(0.0, actor_y - foot_y)
	return lerpf(Tuning.PROP_SEE_THROUGH, 1.0, smoothstep(0.0, Tuning.PROP_FADE_PX, gap))


## The first and the last row whose props may come within PROP_FADE_PX of `rect`, down the screen.
## Row k's tiles have their top corners at y -k * TILE_H / 2, its feet are from TOP_FOOT to
## TILE_H - TOP_FOOT below them, and a frame reaches PROP_MAX_SIZE.y above its foot and PROP_BELOW
## below it (PropLayout).
static func rows(rect: Rect2) -> Vector2i:
	var half := Iso.TILE_H * 0.5
	var top := PropLayout.TOP_FOOT - Tuning.PROP_MAX_SIZE.y
	var bottom := Iso.TILE_H - PropLayout.TOP_FOOT + Tuning.PROP_BELOW
	return Vector2i(
		ceili((top - rect.end.y - Tuning.PROP_FADE_PX) / half),
		floori((bottom - rect.position.y + Tuning.PROP_FADE_PX) / half)
	)
