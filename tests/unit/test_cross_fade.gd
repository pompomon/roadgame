extends GutTest
## CrossFade (IMPLEMENTATION_PLAN.md M5.3): two decks fade from one area's loop to the next's, or
## to silence, at equal power, and a deck forgets its track once it is silent.

const SECONDS := 1.5

var _a := AudioStreamWAV.new()
var _b := AudioStreamWAV.new()
var _c := AudioStreamWAV.new()


## A fade with `track` in full on its deck.
func _playing(track: AudioStream) -> CrossFade:
	var fade := CrossFade.new(SECONDS)
	fade.fade_to(track)
	fade.advance(SECONDS)
	return fade


func test_the_first_track_fades_in_from_silence() -> void:
	var fade := CrossFade.new(SECONDS)
	var deck := fade.fade_to(_a)
	assert_true(deck in [0, 1], "a deck starts it")
	assert_eq(fade.tracks[deck], _a)
	assert_eq(fade.current, deck)
	assert_eq(fade.weights[deck], 0.0)
	fade.advance(SECONDS / 2.0)
	assert_almost_eq(fade.weights[deck], 0.5, 1e-6)
	fade.advance(SECONDS)
	assert_eq(fade.weights[deck], 1.0, "full, and no more")


func test_a_new_track_fades_in_as_the_old_fades_out_at_equal_power() -> void:
	var fade := _playing(_a)
	var old := fade.current
	var deck := fade.fade_to(_b)
	assert_eq(deck, 1 - old, "the other deck")
	fade.advance(SECONDS / 2.0)
	assert_almost_eq(fade.weights[old], 0.5, 1e-6)
	assert_almost_eq(fade.weights[deck], 0.5, 1e-6)
	var power := (
		pow(CrossFade.gain(fade.weights[old]), 2) + pow(CrossFade.gain(fade.weights[deck]), 2)
	)
	assert_almost_eq(power, 1.0, 1e-6, "as loud as either track alone")
	fade.advance(SECONDS / 2.0)
	assert_eq(fade.weights[deck], 1.0)
	assert_eq(fade.weights[old], 0.0)
	assert_null(fade.tracks[old], "the silent deck forgets its track")
	assert_eq(fade.tracks[deck], _b)


func test_the_same_track_again_changes_nothing() -> void:
	var fade := _playing(_a)
	var weights := fade.weights.duplicate()
	assert_eq(fade.fade_to(_a), -1)
	fade.advance(SECONDS)
	assert_eq(fade.weights, weights)


func test_back_to_the_old_track_mid_fade_fades_it_back_in_from_where_it_is() -> void:
	var fade := _playing(_a)
	var old := fade.current
	fade.fade_to(_b)
	fade.advance(SECONDS / 3.0)
	assert_eq(fade.fade_to(_a), -1, "no deck restarts it")
	assert_eq(fade.current, old)
	assert_almost_eq(fade.weights[old], 2.0 / 3.0, 1e-6)
	fade.advance(SECONDS / 3.0)
	assert_eq(fade.weights[old], 1.0)
	assert_null(fade.tracks[1 - old], "the new track faded out and is forgotten")


func test_a_third_track_mid_fade_takes_the_quieter_deck() -> void:
	var fade := _playing(_a)
	var old := fade.current
	var deck := fade.fade_to(_b)
	fade.advance(SECONDS / 4.0)
	assert_eq(fade.fade_to(_c), deck, "the deck of the track that had just come in")
	assert_eq(fade.tracks[deck], _c)
	assert_eq(fade.weights[deck], 0.0, "from silence")
	assert_almost_eq(fade.weights[old], 0.75, 1e-6, "the old one keeps fading out")
	fade.advance(SECONDS)
	assert_eq(fade.tracks[deck], _c)
	assert_null(fade.tracks[old])


func test_no_track_fades_out() -> void:
	var fade := _playing(_a)
	assert_eq(fade.fade_to(null), -1)
	assert_null(fade.current_track(), "nothing fades in")
	fade.advance(SECONDS / 2.0)
	assert_almost_eq(fade.weights[0] + fade.weights[1], 0.5, 1e-6)
	fade.advance(SECONDS / 2.0)
	assert_eq(fade.weights, [0.0, 0.0] as Array[float])
	assert_eq(fade.tracks, [null, null] as Array[AudioStream])


## Copilot's review of #41: no track mid-fade cut the quieter deck at once, from a gain of 0.71.
func test_no_track_mid_fade_fades_both_decks_out_from_where_they_are() -> void:
	var fade := _playing(_a)
	var old := fade.current
	var deck := fade.fade_to(_b)
	fade.advance(SECONDS / 4.0)
	assert_eq(fade.fade_to(null), -1)
	assert_null(fade.current_track(), "nothing fades in")
	assert_eq(fade.tracks[old], _a, "each deck keeps its track")
	assert_eq(fade.tracks[deck], _b)
	fade.advance(SECONDS / 8.0)
	assert_almost_eq(fade.weights[old], 0.625, 1e-6, "from where it was")
	assert_almost_eq(fade.weights[deck], 0.125, 1e-6, "from where it was")
	fade.advance(SECONDS / 8.0)
	assert_eq(fade.weights[deck], 0.0)
	assert_null(fade.tracks[deck], "silent, so forgotten")
	assert_eq(fade.tracks[old], _a)
	fade.advance(SECONDS / 2.0)
	assert_eq(fade.weights, [0.0, 0.0] as Array[float])
	assert_eq(fade.tracks, [null, null] as Array[AudioStream])


func test_a_track_fading_out_to_silence_fades_back_in_from_where_it_is() -> void:
	var fade := _playing(_a)
	var old := fade.current
	fade.fade_to(null)
	fade.advance(SECONDS / 4.0)
	assert_eq(fade.fade_to(_a), -1, "no deck restarts it")
	assert_eq(fade.current_track(), _a)
	assert_eq(fade.current, old)
	fade.advance(SECONDS / 8.0)
	assert_almost_eq(fade.weights[old], 0.875, 1e-6)


func test_a_track_that_faded_out_starts_again_from_its_beginning() -> void:
	var fade := _playing(_a)
	fade.fade_to(_b)
	fade.advance(SECONDS)
	var deck := fade.fade_to(_a)
	assert_true(deck in [0, 1], "a deck must start it again")
	assert_eq(fade.tracks[deck], _a)


func test_gain_keeps_the_power_of_two_decks_even() -> void:
	assert_eq(CrossFade.gain(0.0), 0.0)
	assert_almost_eq(CrossFade.gain(1.0), 1.0, 1e-6)
	assert_eq(CrossFade.gain(-1.0), 0.0, "clamped")
	assert_almost_eq(CrossFade.gain(2.0), 1.0, 1e-6, "clamped")
	for weight: float in [0.1, 0.25, 0.5, 0.9]:
		var power := pow(CrossFade.gain(weight), 2) + pow(CrossFade.gain(1.0 - weight), 2)
		assert_almost_eq(power, 1.0, 1e-6, str(weight))
