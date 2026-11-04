extends RefCounted

## A Hann-windowed 55 Hz thump stays below both voice pitch and high-band onsets.

const RATE := 8000
const FREQUENCY := 55.0
const THUMP_SECONDS := 0.18

static func thump_samples(rate := RATE) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(rate * THUMP_SECONDS))
	for i in samples.size():
		var envelope := pow(sin(PI * float(i) / samples.size()), 2.0)
		samples[i] = sin(TAU * FREQUENCY * float(i) / rate) * envelope * 0.45
	return samples

## Pre-rendered timing is immune to render-frame scheduling jitter.
static func render(beats: Array[float], seconds: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(ceili((seconds + 0.5) * RATE) * 2)
	var thump := thump_samples()
	for beat in beats:
		var start := roundi(beat * RATE)
		for i in thump.size():
			var index := start + i
			if index >= 0 and index * 2 + 1 < bytes.size():
				bytes.encode_s16(index * 2, roundi(thump[i] * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
