extends RefCounted
## Writes make_audio.gd's sounds as files: mono 16-bit PCM WAV, and a loop with its loop points in a
## "smpl" chunk, which Godot's importer reads (edit/loop_mode "Detect From WAV"). No class_name:
## tools/ is not exported.


## `samples`, each from -1 to 1, as a mono 16-bit WAV file at `rate` samples a second; a loop gets
## a "smpl" chunk over the whole sound.
static func encode(samples: PackedFloat32Array, rate: int, loop: bool) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var chunks := PackedByteArray()
	chunks.append_array(_chunk("fmt ", _u16s([1, 1]) + _u32s([rate, rate * 2]) + _u16s([2, 16])))
	chunks.append_array(_chunk("data", data))
	if loop:
		# Manufacturer to sampler data (9 words), then one loop: id, forward, start, end.
		@warning_ignore("integer_division")
		var smpl := _u32s([0, 0, 1000000000 / rate, 60, 0, 0, 0, 1, 0])
		smpl.append_array(_u32s([0, 0, 0, samples.size(), 0, 0]))
		chunks.append_array(_chunk("smpl", smpl))
	return _chunk("RIFF", "WAVE".to_ascii_buffer() + chunks)


static func _chunk(id: String, body: PackedByteArray) -> PackedByteArray:
	return id.to_ascii_buffer() + _u32s([body.size()]) + body


static func _u32s(values: Array[int]) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(values.size() * 4)
	for i: int in values.size():
		out.encode_u32(i * 4, values[i])
	return out


static func _u16s(values: Array[int]) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(values.size() * 2)
	for i: int in values.size():
		out.encode_u16(i * 2, values[i])
	return out
