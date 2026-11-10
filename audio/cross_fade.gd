class_name CrossFade
extends RefCounted
## Two decks that cross-fade from one loop to the next (IMPLEMENTATION_PLAN.md M5.3): the music or
## the ambient sound of the area the car is in. Each deck's weight moves towards its target, 1 for
## the current deck and 0 for the other, by 1 every `seconds`; gain() makes the weights an
## equal-power fade. The other deck forgets its track once it is silent, so that its player can
## stop. Pure logic: AudioDirector plays each deck's track at its gain.

## Each deck's track, or null.
var tracks: Array[AudioStream] = [null, null]
## Each deck's weight, from 0 to 1.
var weights: Array[float] = [0.0, 0.0]
## The deck of the latest track.
var current := 0

var _seconds: float


func _init(p_seconds: float) -> void:
	_seconds = p_seconds


## Fades to `track`, or out if it is null. Returns the deck that must start `track` from its
## beginning, or -1 if none must: the track is the current one, or the other deck still has it and
## fades back in from where it is. Otherwise the quieter deck takes it, from silence.
func fade_to(track: AudioStream) -> int:
	if track == tracks[current]:
		return -1
	var other := 1 - current
	if track == tracks[other]:
		current = other
		return -1
	var deck := other if weights[other] <= weights[current] else current
	tracks[deck] = track
	weights[deck] = 0.0
	current = deck
	return deck if track != null else -1


func advance(delta: float) -> void:
	var step := delta / _seconds if _seconds > 0.0 else 1.0
	for deck: int in 2:
		var target := 1.0 if deck == current and tracks[deck] != null else 0.0
		weights[deck] = move_toward(weights[deck], target, step)
		if deck != current and weights[deck] == 0.0:
			tracks[deck] = null


## The gain of a deck at weight `weight`: sin and cos of the fade, so that the loudness stays even.
static func gain(weight: float) -> float:
	return sin(clampf(weight, 0.0, 1.0) * PI / 2.0)
