extends SceneTree
## Makes the game's sounds (M5_PLAN.md §5.4): each area's music and ambient loop, the engine and
## the other effects of plan.md §6, and a sound for each disaster. They are placeholders that a
## sound designer may replace, file by file, with sounds of the same name, length class and format:
## mono 16-bit WAV at 22,050 Hz, peaking no higher than its kind's Tuning.*_PEAK (M5_PLAN.md L29),
## to which this scales each one. Loops carry their loop points in a "smpl" chunk, which Godot's
## importer reads (edit/loop_mode "Detect From WAV"). The output is the same on every run: noise
## comes from one seeded generator. From the repository root:
##   godot --headless -s tools/audio/make_audio.gd
## then tools/ci/import.sh, and commit the WAV files with their .import files.

const RATE := 22050
const OUT := "res://assets/audio/"
const AREAS: Array[StringName] = [&"city", &"rural", &"meadows", &"village", &"desert"]
## Each area's tune: tempo, root note (MIDI), scale steps, chord degrees per bar, and drums.
const TUNES := {
	&"city": [132, 57, [0, 2, 3, 5, 7, 8, 10], [0, 5, 3, 4], 2],
	&"rural": [100, 55, [0, 2, 4, 5, 7, 9, 11], [0, 3, 4, 0], 1],
	&"meadows": [112, 60, [0, 2, 4, 7, 9], [0, 3, 1, 4], 1],
	&"village": [96, 53, [0, 2, 4, 5, 7, 9, 10], [0, 6, 3, 0], 1],
	&"desert": [90, 52, [0, 1, 4, 5, 7, 8, 10], [0, 1, 0, 6], 0],
}

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 5
	for area: StringName in AREAS:
		_save("music/%s" % area, _music(TUNES[area]), Tuning.MUSIC_PEAK, true)
		_save("ambient/%s" % area, _ambient(area), Tuning.AMBIENT_PEAK, true)
	_save("sfx/engine", _engine(), Tuning.LOOP_PEAK, true)
	_save("sfx/rumble", _rumble(), Tuning.LOOP_PEAK, true)
	_save("sfx/screech", _screech(), Tuning.EFFECT_PEAK, false)
	_save("sfx/damage", _thump(0.2, 90.0, 40.0), Tuning.EFFECT_PEAK, false)
	_save("sfx/crash", _crash(), Tuning.EFFECT_PEAK, false)
	_save("sfx/junction", _chime(), Tuning.EFFECT_PEAK, false)
	# The natural disasters, until M6 PR 8.
	_save("sfx/sinkhole", _sinkhole(), Tuning.EFFECT_PEAK, false)
	_save("sfx/tornado", _tornado(), Tuning.EFFECT_PEAK, false)
	_save("sfx/flood", _flood(), Tuning.EFFECT_PEAK, false)
	_save("sfx/quicksand", _quicksand(), Tuning.EFFECT_PEAK, false)
	# The City's legends.
	_save_legend("phantom_bus", _phantom_bus)
	# Rural's legends.
	_save_legend("ufo", _ufo)
	# The Meadows' legends.
	_save_legend("fairy_ring", _fairy_ring)
	# The Village's legends.
	_save_legend("witch_hex", _witch_hex)
	# The Desert's legends.
	quit()


func _music(tune: Array) -> PackedFloat32Array:
	var bpm: int = tune[0]
	var tonic: int = tune[1]
	var scale: Array = tune[2]
	var chords: Array = tune[3]
	var drums: int = tune[4]
	var beat := 60.0 / bpm
	var out := _silence(roundi(16 * beat * RATE))
	for bar: int in 4:
		var degree: int = chords[bar]
		var tones: Array[int] = []
		for k: int in [0, 2, 4]:
			var step: int = degree + k
			var octave := floori(float(step) / scale.size())
			tones.append(tonic + scale[step % scale.size()] + 12 * octave)
		var bass := _note(tones[0] - 12, beat * 1.8, "triangle", 0.5)
		for half: int in 2:
			_add(out, bass, (bar * 4 + half * 2) * beat)
		for sixteenth: int in 16:
			var tone: int = tones[[0, 1, 2, 1][sixteenth % 4]] + 12
			_add(out, _note(tone, beat * 0.22, "square", 0.12), (bar * 4 + sixteenth * 0.25) * beat)
		for eighth: int in 8 if drums > 0 else 0:
			_add(out, _hat(), (bar * 4 + eighth * 0.5) * beat, 0.15)
		for beat_in_bar: int in 4:
			var at := (bar * 4 + beat_in_bar) * beat
			if beat_in_bar % 2 == 0:
				_add(out, _thump(0.15, 120.0, 45.0), at, 0.5)
			elif drums > 1:
				_add(out, _snare(), at, 0.3)
	return out


func _ambient(area: StringName) -> PackedFloat32Array:
	var n := 4 * RATE
	var out := _silence(n)
	match area:
		&"city":
			_add(out, _low_pass(_noise(n), 250.0), 0.0, 0.8)
			_add(out, _low_pass(_noise(n), 70.0), 0.0, 1.5)
			for at: float in [0.7, 2.6]:
				_add(out, _swell(_low_pass(_noise(RATE), 600.0)), at, 0.8)
			_add(out, _horn(), 3.1, 0.25)
		&"rural":
			_add(out, _lfo(_low_pass(_noise(n), 450.0), 2, 0.3), 0.0, 1.0)
		&"meadows":
			_add(out, _lfo(_low_pass(_noise(n), 350.0), 1, 0.5), 0.0, 0.6)
			for at: float in [0.3, 0.45, 1.6, 2.4, 2.52, 3.5]:
				_add(out, _chirp(_rng.randf_range(2400.0, 3200.0)), at, 0.25)
		&"village":
			_add(out, _low_pass(_noise(n), 220.0), 0.0, 0.9)
			_add(out, _bell(660.0), 0.5, 0.3)
		&"desert":
			_add(out, _lfo(_high_pass(_low_pass(_noise(n), 3000.0), 900.0), 2, 0.2), 0.0, 1.0)
	return out


## A loop of exactly 55 periods of RATE / 400 Hz, so that it repeats without a seam.
func _engine() -> PackedFloat32Array:
	var period := 400
	var out := _silence(period * 55)
	for i: int in out.size():
		var phase := float(i % period) / period
		out[i] = (2.0 * phase - 1.0) * 0.6 + sin(TAU * 2.0 * phase) * 0.3
	_add(out, _low_pass(_noise(out.size()), 300.0), 0.0, 0.6)
	return _low_pass(out, 1500.0)


func _rumble() -> PackedFloat32Array:
	var out := _low_pass(_noise(RATE), 140.0)
	for _k: int in 12:
		_add(out, _thump(0.03, 300.0, 200.0), _rng.randf_range(0.0, 0.95), 0.05)
	return out


func _screech() -> PackedFloat32Array:
	var n := roundi(0.5 * RATE)
	var out := _silence(n)
	var phase := 0.0
	for i: int in n:
		var t := float(i) / RATE
		phase += (1900.0 + 80.0 * sin(TAU * 30.0 * t)) / RATE
		out[i] = sin(TAU * phase) * minf(t / 0.02, 1.0) * (1.0 - t / 0.5)
	_add(out, _high_pass(_noise(n), 1500.0), 0.0, 0.3)
	return out


## A drop in pitch from `from` to `to` Hz over `seconds`, with a click of noise.
func _thump(seconds: float, from: float, to: float) -> PackedFloat32Array:
	var n := roundi(seconds * RATE)
	var out := _silence(n)
	var phase := 0.0
	for i: int in n:
		var t := float(i) / n
		phase += lerpf(from, to, t) / RATE
		out[i] = sin(TAU * phase) * (1.0 - t) * (1.0 - t)
	_add(out, _decay(_noise(mini(n, 200)), 0.004), 0.0, 0.3)
	return out


func _crash() -> PackedFloat32Array:
	var out := _decay(_low_pass(_noise(RATE), 2500.0), 0.25)
	_add(out, _thump(0.3, 110.0, 35.0), 0.0, 1.0)
	for partial: float in [523.0, 1187.0, 1931.0]:
		_add(out, _decay(_tone(partial, 0.6, "sine"), 0.12), 0.02, 0.15)
	return out


func _chime() -> PackedFloat32Array:
	var out := _silence(roundi(0.35 * RATE))
	_add(out, _note(84, 0.15, "square", 0.3), 0.0)
	_add(out, _note(91, 0.2, "square", 0.3), 0.12)
	return out


# The natural disasters, until M6 PR 8.


func _sinkhole() -> PackedFloat32Array:
	var out := _decay(_low_pass(_noise(roundi(1.6 * RATE)), 180.0), 0.8)
	_add(out, _decay(_glide(80.0, 30.0, 1.4), 0.7), 0.0, 0.8)
	for _k: int in 10:
		_add(out, _thump(0.04, 400.0, 250.0), _rng.randf_range(0.1, 1.2), 0.1)
	return out


func _tornado() -> PackedFloat32Array:
	var n := 2 * RATE
	var out := _silence(n)
	var noise := _noise(n)
	var low := 0.0
	var band := 0.0
	for i: int in n:
		var t := float(i) / n
		var cutoff := 300.0 + 900.0 * sin(PI * t) + 200.0 * sin(TAU * 3.0 * t)
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		low += a * (noise[i] - low)
		band += a * (low - band)
		out[i] = (low - band) * sin(PI * t)
	return out


func _flood() -> PackedFloat32Array:
	var n := 2 * RATE
	var out := _lfo(_low_pass(_noise(n), 500.0), 3, 0.5)
	for k: int in 30:
		_add(out, _decay(_glide(_rng.randf_range(300.0, 800.0), 900.0, 0.05), 0.02), k * 0.06, 0.2)
	return _fade_out(out)


func _quicksand() -> PackedFloat32Array:
	var out := _glide(200.0, 60.0, 1.6)
	_add(out, _low_pass(_noise(out.size()), 300.0), 0.0, 0.8)
	return _fade_out(_lfo(out, 6, 0.4))


# The City's legends.


## Timed to Tuning.PHANTOM_BUS_BEATS from the end of the delay, when the sound starts: a cracked
## bell tolls as the bus comes out of the fog and again as it stops, over its engine's low drone,
## two notes that beat against each other; the doors hiss open and shut.
func _phantom_bus() -> PackedFloat32Array:
	var beats := Tuning.PHANTOM_BUS_BEATS
	var arrive: float = beats[0]
	var board: float = arrive + beats[1]
	var leave: float = board + beats[2]
	var out := _silence(roundi((board + 1.5) * RATE))
	var drone_seconds: float = leave + beats[3] - arrive
	var drone := _tone(55.0, drone_seconds, "triangle")
	_add(drone, _tone(58.3, drone_seconds, "triangle"), 0.0)
	_add(out, _swell(_low_pass(drone, 400.0)), arrive, 0.6)
	for toll: float in [arrive, board]:
		_add(out, _bell(196.0), toll, 0.8)
		_add(out, _bell(203.0), toll, 0.6)
	for hiss: float in [board, leave]:
		_add(out, _decay(_high_pass(_noise(roundi(0.35 * RATE)), 2500.0), 0.1), hiss, 0.5)
	return out


# Rural's legends.


## Timed to Tuning.UFO_BEATS from the end of the delay, when the sound starts: as night falls, the
## car radio's station is lost in a warbling static, which dies away as the saucer drops without a
## sound. With the beam comes a deep throb, two low notes that beat against each other, and a whine
## that climbs as the car floats up. Both are gone as the beam closes, and the saucer zips off with
## a shriek that climbs out of hearing.
func _ufo() -> PackedFloat32Array:
	var beats := Tuning.UFO_BEATS
	var drop: float = beats[0]
	var beam: float = drop + beats[1]
	var zip: float = beam + beats[2] + beats[3]
	var out := _silence(roundi((zip + beats[4]) * RATE))
	var radio := _lfo(_high_pass(_low_pass(_noise(roundi(beam * RATE)), 3000.0), 800.0), 9, 0.7)
	for i: int in radio.size():
		var t := float(i) / RATE
		radio[i] *= minf(t / drop, 1.0) * clampf((beam - t) / beats[1], 0.0, 1.0)
	_add(out, radio, 0.0, 0.5)
	var held := zip - beam
	var throb := _tone(48.0, held, "triangle")
	_add(throb, _tone(51.0, held, "triangle"), 0.0)
	_add(out, _swell(_low_pass(throb, 600.0)), beam, 0.9)
	_add(out, _swell(_glide(900.0, 1800.0, held)), beam, 0.15)
	_add(out, _fade_out(_glide(300.0, 3000.0, beats[4])), zip, 0.5)
	return out


# The Meadows' legends.


## Timed to Tuning.FAIRY_RING_BEATS from the end of the delay, when the sound starts: a tiny bell as
## each toadstool sprouts, each out of tune with itself; thin laughter, giggles that fall away, as
## the glows swell and the eyes open; a whirl that rises and quickens as the car is made to dance,
## and is gone with it; then one low chime as the eyes close.
func _fairy_ring() -> PackedFloat32Array:
	var beats := Tuning.FAIRY_RING_BEATS
	var glow: float = beats[0]
	var dance: float = glow + beats[1]
	var hold: float = dance + beats[2]
	var out := _silence(roundi((hold + 1.5) * RATE))
	var count := FairyRing.TOADSTOOLS
	for k: int in count:
		var at: float = beats[0] * FairyRing.turn_start(k, count, FairyRing.GROW_SHARE)
		var freq := 1250.0 * pow(2.0, _rng.randf_range(0.0, 0.5))
		_add(out, _bell(freq), at, 0.3)
		_add(out, _bell(freq * 1.045), at, 0.2)
	for k: int in 6:
		_add(out, _chirp(1500.0 * pow(0.93, k)), glow + 0.03 + k * 0.07, 0.4)
	for k: int in 5:
		_add(out, _chirp(1900.0 * pow(0.9, k)), glow + 0.22 + k * 0.06, 0.25)
	var n := roundi(beats[2] * RATE)
	var whirl := _high_pass(_low_pass(_noise(n), 2500.0), 400.0)
	var rising := _glide(220.0, 880.0, beats[2])
	for i: int in n:
		var t := float(i) / n
		# A whoosh for each quarter of the double's turns, faster and faster, as it spins.
		var whoosh := 0.5 + 0.5 * sin(TAU * 4.0 * FairyRing.TURNS * t * t)
		var gone := clampf((1.0 - t) / FairyRing.SHRINK_SHARE, 0.0, 1.0)
		whirl[i] = (whirl[i] + 0.4 * rising[i]) * whoosh * gone * minf(t * 5.0, 1.0)
	_add(out, whirl, dance, 0.6)
	_add(out, _bell(98.0), hold, 1.0)
	_add(out, _bell(99.5), hold, 0.7)
	return out


# The Village's legends.


## Timed to Tuning.WITCH_HEX_BEATS from the end of the delay, when the sound starts: a long, low
## cackle as the witch swoops in; the whoosh of her broom as she circles the car; a thin whine that
## climbs and trembles as the hex runs from her finger; a dull poof as the smoke bursts; a hollow
## knock as the jack-o'-lantern pops up, and the soft rush of its grin catching light. Her cackle
## again as she flies off, dying away.
func _witch_hex() -> PackedFloat32Array:
	var beats := Tuning.WITCH_HEX_BEATS
	var swooped: float = beats[0] * WitchHex.SWOOP_SHARE
	var circled: float = beats[0] + beats[1] * WitchHex.CIRCLE_SHARE
	var puff: float = beats[0] + beats[1]
	var pop: float = puff + beats[2]
	var lit: float = pop + beats[3] * WitchHex.POP_SHARE
	var out := _silence(roundi((pop + 1.2) * RATE))
	_add(out, _cackle(260.0, 6), 0.0, 0.9)
	var whoosh := _high_pass(_low_pass(_noise(roundi((circled - swooped) * RATE)), 1500.0), 400.0)
	_add(out, _swell(whoosh), swooped, 0.6)
	var held := puff - circled
	var whine := _glide(440.0, 1320.0, held)
	_add(whine, _glide(452.0, 1356.0, held), 0.0)
	whine = _lfo(whine, 6, 0.6)
	for i: int in whine.size():
		whine[i] *= float(i) / whine.size()
	_add(out, whine, circled, 0.15)
	_add(out, _decay(_low_pass(_noise(roundi(0.5 * RATE)), 600.0), 0.12), puff, 1.0)
	_add(out, _decay(_tone(70.0, 0.3, "sine"), 0.08), puff, 0.6)
	var knock := _decay(_tone(180.0, 0.3, "sine"), 0.05)
	_add(knock, _decay(_tone(470.0, 0.3, "sine"), 0.02), 0.0, 0.4)
	_add(out, knock, pop, 0.8)
	_add(out, _swell(_low_pass(_noise(roundi(0.3 * RATE)), 400.0)), lit, 0.4)
	_add(out, _fade_out(_low_pass(_cackle(280.0, 7), 1200.0)), pop, 0.5)
	return out


# The Desert's legends.


func _note(midi: int, seconds: float, kind: String, gain: float) -> PackedFloat32Array:
	var freq := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var out := _decay(_tone(freq, seconds, kind), seconds * 0.5)
	for i: int in out.size():
		out[i] *= gain
	return out


func _tone(freq: float, seconds: float, kind: String) -> PackedFloat32Array:
	var out := _silence(roundi(seconds * RATE))
	for i: int in out.size():
		var phase := fmod(freq * i / RATE, 1.0)
		match kind:
			"square":
				out[i] = 1.0 if phase < 0.5 else -1.0
			"triangle":
				out[i] = 4.0 * absf(phase - 0.5) - 1.0
			_:
				out[i] = sin(TAU * phase)
	return out


func _glide(from: float, to: float, seconds: float) -> PackedFloat32Array:
	var out := _silence(roundi(seconds * RATE))
	var phase := 0.0
	for i: int in out.size():
		phase += from * pow(to / from, float(i) / out.size()) / RATE
		out[i] = sin(TAU * phase)
	return out


func _hat() -> PackedFloat32Array:
	return _decay(_high_pass(_noise(roundi(0.04 * RATE)), 5000.0), 0.01)


func _snare() -> PackedFloat32Array:
	var out := _decay(_high_pass(_noise(roundi(0.15 * RATE)), 1200.0), 0.05)
	_add(out, _decay(_tone(190.0, 0.1, "sine"), 0.03), 0.0, 0.5)
	return out


func _horn() -> PackedFloat32Array:
	var out := _tone(392.0, 0.3, "square")
	_add(out, _tone(494.0, 0.3, "square"), 0.0)
	return _fade_out(_low_pass(out, 1200.0))


func _chirp(freq: float) -> PackedFloat32Array:
	var out := _glide(freq, freq * 1.3, 0.08)
	for i: int in out.size():
		out[i] *= sin(PI * i / out.size())
	return out


## `count` rasping "ha"s, from `freq` Hz, each lower than the last: in each, a voice of three
## partials falls a fifth of its pitch over a breath of noise.
func _cackle(freq: float, count: int) -> PackedFloat32Array:
	var syllable := 0.1
	var out := _silence(roundi(syllable * (count + 1) * RATE))
	for k: int in count:
		var pitch := freq * pow(0.94, k)
		var ha := _low_pass(_noise(roundi(syllable * RATE)), 2000.0)
		for partial: float in [1.0, 2.0, 3.0]:
			_add(ha, _glide(pitch * partial, pitch * partial * 0.8, syllable), 0.0, 1.0 / partial)
		_add(out, _swell(ha), k * syllable)
	return _low_pass(out, 2500.0)


func _bell(freq: float) -> PackedFloat32Array:
	var out := _silence(roundi(1.5 * RATE))
	for partial: float in [1.0, 2.0, 2.76, 5.4]:
		_add(out, _decay(_tone(freq * partial, 1.5, "sine"), 0.6 / partial), 0.0, 0.3 / partial)
	return out


func _swell(x: PackedFloat32Array) -> PackedFloat32Array:
	for i: int in x.size():
		x[i] *= sin(PI * i / x.size())
	return x


func _noise(n: int) -> PackedFloat32Array:
	var out := _silence(n)
	for i: int in n:
		out[i] = _rng.randf_range(-1.0, 1.0)
	return out


## A one-pole low-pass, run twice round the buffer so that its end flows into its start: the
## filtered noise of a loop has no seam.
func _low_pass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var out := _silence(x.size())
	var y := 0.0
	for k: int in 2:
		for i: int in x.size():
			y += a * (x[i] - y)
			out[i] = y
	return out


func _high_pass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low := _low_pass(x, cutoff)
	for i: int in x.size():
		low[i] = x[i] - low[i]
	return low


## Gain that swings between 1 - depth and 1, `cycles` times per buffer, so that loops stay whole.
func _lfo(x: PackedFloat32Array, cycles: int, depth: float) -> PackedFloat32Array:
	for i: int in x.size():
		x[i] *= 1.0 - depth * 0.5 * (1.0 + cos(TAU * cycles * i / x.size()))
	return x


func _decay(x: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	for i: int in x.size():
		x[i] *= exp(-float(i) / (seconds * RATE))
	return x


func _fade_out(x: PackedFloat32Array) -> PackedFloat32Array:
	for i: int in x.size():
		x[i] *= 1.0 - float(i) / x.size()
	return x


func _silence(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	return out


## Mixes `x` into `out` from `at` seconds, at `gain`. What runs past the end wraps round to the
## start, so that loops have no seam.
func _add(out: PackedFloat32Array, x: PackedFloat32Array, at: float, gain := 1.0) -> void:
	var start := roundi(at * RATE)
	for i: int in x.size():
		out[(start + i) % out.size()] += x[i] * gain


func _normalized(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0
	for v: float in x:
		top = maxf(top, absf(v))
	if top > 0.0:
		for i: int in x.size():
			x[i] *= peak / top
	return x


## Writes `samples`, scaled to `peak`, as a mono 16-bit WAV; a loop gets a "smpl" chunk over the
## whole sound.
func _save(path_in_out: String, samples: PackedFloat32Array, peak: float, loop: bool) -> void:
	var scaled := _normalized(samples, peak)
	var data := PackedByteArray()
	data.resize(scaled.size() * 2)
	for i: int in scaled.size():
		data.encode_s16(i * 2, clampi(roundi(scaled[i] * 32767.0), -32768, 32767))
	var chunks := PackedByteArray()
	chunks.append_array(_chunk("fmt ", _u16s([1, 1]) + _u32s([RATE, RATE * 2]) + _u16s([2, 16])))
	chunks.append_array(_chunk("data", data))
	if loop:
		# Manufacturer to sampler data (9 words), then one loop: id, forward, start, end.
		@warning_ignore("integer_division")
		var smpl := _u32s([0, 0, 1000000000 / RATE, 60, 0, 0, 0, 1, 0])
		smpl.append_array(_u32s([0, 0, 0, samples.size(), 0, 0]))
		chunks.append_array(_chunk("smpl", smpl))
	var path := OUT + path_in_out + ".wav"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_chunk("RIFF", "WAVE".to_ascii_buffer() + chunks))
	file.close()
	print("%s: %.2f s%s" % [path, float(samples.size()) / RATE, ", loop" if loop else ""])


## Saves the legend `id`'s sound from `synth`, its noise drawn from a generator seeded by the id
## alone, so that no other sound changes it (M6_PLAN.md S17).
func _save_legend(id: String, synth: Callable) -> void:
	_rng.seed = hash(id)
	_save("sfx/" + id, synth.call(), Tuning.EFFECT_PEAK, false)


func _chunk(id: String, body: PackedByteArray) -> PackedByteArray:
	return id.to_ascii_buffer() + _u32s([body.size()]) + body


func _u32s(values: Array[int]) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(values.size() * 4)
	for i: int in values.size():
		out.encode_u32(i * 4, values[i])
	return out


func _u16s(values: Array[int]) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(values.size() * 2)
	for i: int in values.size():
		out.encode_u16(i * 2, values[i])
	return out
