extends GutTest
## DisasterParams (IMPLEMENTATION_PLAN.md M3.1, M3 tests): they come from the run's disaster stream,
## so the same seed gives the same params, and different seeds different ones.

const ORIGIN := Vector2(10.0, -20.0)
const SEEDS := 20


## The first `count` params of the run with `run_seed`, as arrays of their fields.
static func _rolls(run_seed: int, count: int) -> Array:
	var rng := DisasterDirector.stream(run_seed)
	var rolls := []
	for _i: int in count:
		rolls.append(_fields(DisasterParams.roll(rng, ORIGIN)))
	return rolls


static func _fields(params: DisasterParams) -> Array:
	return [
		params.direction,
		params.intensity,
		params.delay,
		params.particle_scale,
		params.particle_seed,
		params.origin_world,
	]


func test_the_same_seed_gives_the_same_params() -> void:
	for run_seed: int in SEEDS:
		assert_eq(_rolls(run_seed, 3), _rolls(run_seed, 3), "seed %d" % run_seed)


func test_different_seeds_give_different_params() -> void:
	# Each random field of the first params takes a different value on each seed.
	var values := [{}, {}, {}, {}, {}]
	for run_seed: int in SEEDS:
		var fields: Array = _rolls(run_seed, 1)[0]
		for i: int in values.size():
			values[i][fields[i]] = true
	for i: int in values.size():
		assert_eq(values[i].size(), SEEDS, "field %d" % i)


func test_the_stream_goes_on_from_one_disaster_to_the_next() -> void:
	var rolls := _rolls(1, 2)
	assert_ne(rolls[0], rolls[1])


func test_the_params_are_in_their_ranges() -> void:
	var wrong := 0
	for run_seed: int in 200:
		var params := DisasterParams.roll(DisasterDirector.stream(run_seed), ORIGIN)
		var ok := (
			is_equal_approx(params.direction.length(), 1.0)
			and params.intensity >= Tuning.DISASTER_INTENSITY_MIN
			and params.intensity <= Tuning.DISASTER_INTENSITY_MAX
			and params.delay >= Tuning.DISASTER_DELAY_MIN
			and params.delay <= Tuning.DISASTER_DELAY_MAX
			and params.particle_scale >= Tuning.PARTICLE_SCALE_MIN
			and params.particle_scale <= Tuning.PARTICLE_SCALE_MAX
			and params.origin_world == ORIGIN
		)
		if not ok:
			wrong += 1
	assert_eq(wrong, 0, "params out of their ranges")
