extends Node

## Original synthesis and an audible playback clock; no microphone monitoring.

const Guide = preload("res://games/tifo_beato/sound/guide_drum.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const RATE := 22050
var clock_player: AudioStreamPlayer
var manual_time := -1.0
var paused := false
var _held_time := 0.0
var _last_time := 0.0
var _voices: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _instrument_voice: AudioStreamPlayer
var _instrument_band := -10
var _unvoiced_since := -1.0
var _shout_played := false

func _ready() -> void:
	clock_player = AudioStreamPlayer.new()
	clock_player.name = "GuideDrumClock"
	clock_player.bus = "SFX"
	clock_player.volume_db = -13.0
	add_child(clock_player)
	for band in [-1, 0, 1]:
		_voices[band] = voice_samples(band)

## Position plus mixer interpolation minus output latency is the audible time.
func now() -> float:
	if manual_time >= 0.0:
		return manual_time
	if paused:
		return _held_time
	if clock_player == null or not clock_player.playing:
		return _last_time
	var audible := clock_player.get_playback_position() \
		+ AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	_last_time = maxf(_last_time, audible)
	return _last_time

func play_track(beats: Array[float], duration: float, start := 0.0) -> void:
	stop()
	if manual_time >= 0.0:
		manual_time = start
	_last_time = start
	_held_time = start
	clock_player.stream = Guide.render(beats, duration)
	guide_enabled(true)
	clock_player.play(start)
	paused = false

func seek(time: float) -> void:
	_last_time = time
	_held_time = time
	if manual_time >= 0.0:
		manual_time = time
	if clock_player != null:
		clock_player.seek(time)

func set_paused(value: bool) -> void:
	if value:
		_held_time = now()
	paused = value
	if clock_player != null:
		clock_player.stream_paused = value
	if value:
		stop_voices()

func guide_enabled(value: bool) -> void:
	if clock_player != null:
		clock_player.volume_db = -13.0 if value else -80.0

func stop() -> void:
	if clock_player != null:
		clock_player.stop()
	stop_voices()
	paused = false

func capo(band := 0) -> void:
	_play(_stream(_voices.get(band, _voices[0])), -15.0)

func instrument_frame(frame: Frame) -> void:
	if frame.voiced:
		var band := signi(roundi(frame.cents))
		if band != _instrument_band or not is_instance_valid(_instrument_voice):
			_stop_instrument()
			var stream := _stream(_voices[band])
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / 2
			_instrument_voice = _play(stream, -18.0)
			_instrument_band = band
		_unvoiced_since = -1.0
	else:
		_stop_instrument()
		var level := frame.level
		if level < 0.4:
			_unvoiced_since = -1.0
			_shout_played = false
		else:
			if _unvoiced_since < 0.0:
				_unvoiced_since = frame.t
			if frame.flux > 0.5:
				cue("beat")
			if not _shout_played and frame.t - _unvoiced_since >= 0.15:
				capo(0)
				_shout_played = true

func _stop_instrument() -> void:
	if is_instance_valid(_instrument_voice):
		_instrument_voice.stop()
		_instrument_voice.queue_free()
	_instrument_voice = null
	_instrument_band = -10

## Missing/sloppy hits really change the response, rather than playing a perfect chart.
func response(call: Array[Dictionary], call_start: float, seconds: float,
	scatter: float, megaphone := false) -> void:
	var samples := PackedFloat32Array()
	samples.resize(ceili(seconds * RATE))
	var first_offset := 0.0
	var last_offset := 0.0
	for result in call:
		if int(result["grade"]) < 3 and str(result["kind"]) != "rest":
			var offset := float(result["note"]["t"]) - call_start + float(result["error"])
			first_offset = minf(first_offset, offset - scatter * 0.375)
			last_offset = maxf(last_offset, offset + scatter * 0.375)
	var timing_scale := minf(1.0, maxf(0.01, seconds - 0.52) \
		/ maxf(0.01, last_offset - first_offset))
	for result in call:
		var grade := int(result["grade"])
		if grade >= 3 or str(result["kind"]) == "rest":
			continue
		var note: Dictionary = result["note"]
		var band := int(result.get("band", 0)) if str(result["kind"]) in ["sing", "hold"] else 0
		var voice: PackedFloat32Array = _voices.get(band, _voices[0])
		for layer in 6:
			var offset := float(note["t"]) - call_start + float(result["error"]) \
				+ scatter * (layer - 2.5) * 0.15
			var start := roundi((offset - first_offset) * timing_scale * RATE)
			var gain: float = [1.0, 0.8, 0.5, 0.0][grade] * (0.2 if megaphone else 0.13)
			for i in voice.size():
				var at := start + i
				if at >= 0 and at < samples.size():
					samples[at] += voice[i] * gain
	for index in range(maxi(0, samples.size() - roundi(0.2 * RATE)), samples.size()):
		samples[index] *= float(samples.size() - index) / (0.2 * RATE)
	_play(_stream(samples), -10.0)

func stop_voices() -> void:
	_stop_instrument()
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_players.clear()
	_unvoiced_since = -1.0
	_shout_played = false

func cue(kind: String, level := 1.0) -> void:
	_play(_stream(_cue_samples(kind)), -15.0 + linear_to_db(maxf(0.0001, level)))

## Longer original rival patterns play only inside a caller-free response tail.
func disruption(kind: String, beat: float, seconds: float, level := 1.0) -> void:
	var pulse := _cue_samples(kind)
	var samples := PackedFloat32Array()
	samples.resize(roundi(RATE * seconds))
	var spacing := beat / 1.06 if kind == "rival_drums" else beat * (
		0.75 if kind == "trumpet" else 2.0)
	var at := 0.0
	var hit := 0
	while at < seconds:
		var start := roundi(at * RATE)
		var gain := 1.0 if hit % 2 == 0 else 0.65
		for index in mini(pulse.size(), samples.size() - start):
			samples[start + index] += pulse[index] * gain
		at += maxf(0.06, spacing)
		hit += 1
	var fade := mini(samples.size(), roundi(RATE * 0.12))
	for index in fade:
		samples[samples.size() - fade + index] *= float(fade - index) / maxf(1.0, fade)
	_play(_stream(samples), -15.0 + linear_to_db(maxf(0.0001, level)))

static func _cue_samples(kind: String) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(RATE * 0.25))
	var frequency: float = {"beat": 80.0, "power": 180.0, "fury": 440.0,
		"tifo": 550.0, "goal_home": 660.0, "goal_away": 220.0,
		"whistle": 880.0, "air_horn": 310.0, "trumpet": 349.0,
		"rival_drums": 95.0, "kazoo": 247.0, "inflatable": 150.0}.get(kind, 330.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 412
	for i in samples.size():
		var t := float(i) / RATE
		var envelope := sin(PI * float(i) / samples.size()) * exp(-t * 6.0)
		var value := sin(TAU * frequency * t) * 0.25
		if kind in ["air_horn", "trumpet", "rival_drums", "kazoo"]:
			value += sin(TAU * frequency * 1.07 * t) * 0.12 + rng.randf_range(-0.08, 0.08)
		samples[i] = value * envelope
	return samples

static func voice_samples(band: int) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(RATE * 0.32))
	var frequency := 220.0 * pow(2.0, band * 500.0 / 1200.0)
	for i in samples.size():
		var t := float(i) / RATE
		var envelope := pow(sin(PI * float(i) / samples.size()), 0.65)
		var voice := sin(TAU * frequency * t) * 0.55 \
			+ sin(TAU * frequency * 2.0 * t) * 0.2 \
			+ sin(TAU * frequency * 3.0 * t) * 0.12
		samples[i] = voice * envelope
	return samples

static func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream

func _play(stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	for index in range(_players.size() - 1, -1, -1):
		if not is_instance_valid(_players[index]):
			_players.remove_at(index)
	if _players.size() >= 8:
		var oldest: AudioStreamPlayer = _players.pop_front()
		oldest.stop()
		oldest.queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume
	add_child(player)
	_players.append(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
