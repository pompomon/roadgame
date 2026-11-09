class_name DisasterParams
extends RefCounted
## The random parameters of one disaster (plan.md §4.2, IMPLEMENTATION_PLAN.md M3.1). They come
## from the run's disaster stream, so the same seed plays the same disaster the same way. Each
## disaster reads the ones it needs.

## Where the disaster heads or throws its debris: a unit vector in tile space.
var direction := Vector2.RIGHT
## How strong it is, from DISASTER_INTENSITY_MIN to DISASTER_INTENSITY_MAX.
var intensity := 1.0
## Seconds from play() until the disaster shows.
var delay := 0.0
## Scales the size of its particles.
var particle_scale := 1.0
## Seeds its particles (use_fixed_seed). Not `seed`, which would shadow the built-in function.
var particle_seed := 0
## Where it happens, in world pixels: where the car stopped. The stream can't know that.
var origin_world := Vector2.ZERO


## Draws every random field from `rng`, always in the same order.
static func roll(rng: RandomNumberGenerator, origin: Vector2) -> DisasterParams:
	var params := DisasterParams.new()
	params.direction = Vector2.from_angle(rng.randf_range(0.0, TAU))
	params.intensity = rng.randf_range(Tuning.DISASTER_INTENSITY_MIN, Tuning.DISASTER_INTENSITY_MAX)
	params.delay = rng.randf_range(Tuning.DISASTER_DELAY_MIN, Tuning.DISASTER_DELAY_MAX)
	params.particle_scale = rng.randf_range(Tuning.PARTICLE_SCALE_MIN, Tuning.PARTICLE_SCALE_MAX)
	params.particle_seed = rng.randi()
	params.origin_world = origin
	return params
