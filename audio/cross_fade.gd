class_name CrossFade
extends RefCounted
## Two decks that cross-fade from one loop to the next (IMPLEMENTATION_PLAN.md M5.3): the music or
## the ambient sound of the area the car is in. Each deck's weight moves towards its target, 1 for
## the current deck and 0 for the other, by 1 every `seconds`; gain() makes the weights an
## equal-power fade. A deck that isn't current forgets its track once it is silent, so that its
## player can stop. Pure logic: AudioDirector plays each deck's track at its gain.

## `current` when no deck is: both fade out.
const NONE := -1

## Each deck's track, or null.
var tracks: Array[AudioStream] = [null, null]
## Each deck's weight, from 0 to 1.
var weights: Array[float] = [0.0, 0.0]
## The deck of the latest track, or NONE. A current deck always has a track.
var current := NONE

var _seconds: float


func _init(p_seconds: float) -> void:
	_seconds = p_seconds


## Fades to `track`, or out if it is null: then both decks fade out from where they are, each with
## its track. Returns the deck that must start `track` from its beginning, or -1 if none must: the
## track is null or the current one, or a deck still has it and fades back in from where it is.
## Otherwise the quieter deck takes it, from silence.
func fade_to(track: AudioStream) -> int:
	if track == null:
		current = NONE
		return -1
	var deck := tracks.find(track)
	if deck != -1:
		current = deck
		return -1
	deck = 0 if current == NONE else 1 - current
	if weights[1 - deck] < weights[deck]:
		deck = 1 - deck
	tracks[deck] = track
	weights[deck] = 0.0
	current = deck
	return deck


func advance(delta: float) -> void:
	var step := delta / _seconds if _seconds > 0.0 else 1.0
	for deck: int in 2:
		weights[deck] = move_toward(weights[deck], 1.0 if deck == current else 0.0, step)
		if deck != current and weights[deck] == 0.0:
			tracks[deck] = null


## The track that plays or fades in, or null. Not tracks[current]: tracks[NONE] is the last deck's.
func current_track() -> AudioStream:
	return tracks[current] if current != NONE else null


## Silent at once, with no tracks.
func stop() -> void:
	tracks = [null, null]
	weights = [0.0, 0.0]
	current = NONE


## The gain of a deck at weight `weight`: sin and cos of the fade, so that the loudness stays even.
static func gain(weight: float) -> float:
	return sin(clampf(weight, 0.0, 1.0) * PI / 2.0)
