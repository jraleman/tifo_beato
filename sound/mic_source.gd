extends RefCounted

## Raw capture feeds sample-timed frames; only the onset path is high-passed.

const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Pitch = preload("res://games/tifo_beato/sound/pitch_detector.gd")
const Profile = preload("res://games/tifo_beato/sound/voice_profile.gd")
const FRAME_RATE := 100.0
const HIGH_PASS_HZ := 250.0
const HIGH_PASS_STAGES := 4
var profile := Profile.new()
var quiet := false
var sample_rate := 44100.0
var _pending := PackedFloat32Array()
var _pitch_window := PackedFloat32Array()
var _low: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _previous_high := 0.0
var _sample_count := 0
var _anchor := 0.0
var _pitch := {"voiced": false, "hz": 0.0, "clarity": 0.0}
var _pitch_hop := 0
var last_raw_level := 0.0
var last_hz := 0.0

func reset(time := 0.0) -> void:
	_pending.clear()
	_pitch_window.clear()
	_low = [0.0, 0.0, 0.0, 0.0]
	_previous_high = 0.0
	_sample_count = 0
	_anchor = time
	_pitch_hop = 0
	_pitch = {"voiced": false, "hz": 0.0, "clarity": 0.0}

func push_pcm(stereo: PackedVector2Array, sample_end := -1.0) -> Array[Frame]:
	if _sample_count == 0 and _pending.is_empty() and sample_end >= 0.0:
		_anchor = sample_end - stereo.size() / sample_rate
	var mono := PackedFloat32Array()
	mono.resize(stereo.size())
	for i in stereo.size():
		mono[i] = (stereo[i].x + stereo[i].y) * 0.5
	return push_samples(mono)

func push_samples(samples: PackedFloat32Array) -> Array[Frame]:
	_pending.append_array(samples)
	var result: Array[Frame] = []
	var count := maxi(1, roundi(sample_rate / FRAME_RATE))
	var alpha := 1.0 - exp(-TAU * HIGH_PASS_HZ / sample_rate)
	var offset := 0
	while _pending.size() - offset >= count:
		var energy := 0.0
		var high_energy := 0.0
		for i in count:
			var raw := _pending[offset + i]
			energy += raw * raw
			_pitch_window.append(raw)
			var high := raw
			for stage in HIGH_PASS_STAGES:
				_low[stage] += alpha * (high - _low[stage])
				high -= _low[stage]
			high_energy += high * high
		offset += count
		_sample_count += count
		_pitch_hop += 1
		last_raw_level = sqrt(energy / count)
		if _pitch_window.size() > Pitch.WINDOW_SIZE * Pitch.DECIMATION:
			_pitch_window = _pitch_window.slice(-Pitch.WINDOW_SIZE * Pitch.DECIMATION)
		if _pitch_hop >= 3:
			_pitch = Pitch.analyse(_pitch_window, sample_rate, profile.noise_floor)
			_pitch_hop = 0
		last_hz = float(_pitch["hz"])
		var high_rms := sqrt(high_energy / count)
		var high_level := profile.normalized_level(high_rms, quiet)
		var flux := maxf(0.0, high_level - _previous_high)
		_previous_high = high_level
		var voiced := bool(_pitch["voiced"])
		# The sub-180 Hz guide is not player activity, including during a Rest.
		var activity := voiced or high_rms >= profile.noise_floor * 2.0
		var frame := Frame.new(_anchor + float(_sample_count) / sample_rate,
			profile.normalized_level(last_raw_level, quiet) if activity else 0.0, flux, voiced,
			Pitch.cents_from(last_hz, profile.centre_hz) if voiced else 0.0,
			float(_pitch["clarity"]))
		frame.raw_level = last_raw_level
		result.append(frame)
	if offset > 0:
		_pending = _pending.slice(offset)
	return result
