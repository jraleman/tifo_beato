extends RefCounted

## One sample timeline combines independent contacts with optional private capture.

signal capture_failed(reason: String)
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Key = preload("res://games/tifo_beato/sound/key_source.gd")
const Mic = preload("res://games/tifo_beato/sound/mic_source.gd")
const Capture = preload("res://games/tifo_beato/sound/mic_capture.gd")
const Profile = preload("res://games/tifo_beato/sound/voice_profile.gd")
var keys := Key.new()
var mic := Mic.new()
var profile := Profile.new()
var capture: Capture
var kind := 1
var quiet := false
var _microphone_frames: Array[Frame] = []
var _latest := Frame.new(-100.0)

## Only gesture handlers may begin recording; constructing the model opens nothing.
func begin(owner: Node, instrument: int, calibration: Profile,
	now: float, quiet_mode: bool) -> void:
	close()
	kind = instrument
	profile = calibration
	quiet = quiet_mode
	reset(now)
	mic.profile = profile
	mic.quiet = quiet
	mic.sample_rate = AudioServer.get_mix_rate()
	if kind == 0:
		capture = Capture.new()
		capture.name = "ConsentedMicrophone"
		capture.capture_failed.connect(_on_failure)
		owner.add_child(capture)

## Clear held contacts, buffered audio and pitch history at every discontinuity.
func reset(now: float) -> void:
	keys.reset(now)
	mic.reset(now)
	_microphone_frames.clear()
	_latest = Frame.new(-100.0)
	if capture != null:
		capture.clear()

func set_action(action: StringName, pressed: bool, now: float, contact: String) -> void:
	keys.set_action(action, pressed, now, contact)

func frames_until(now: float) -> Array[Frame]:
	if capture != null:
		_microphone_frames.append_array(mic.push_pcm(capture.poll(), now))
	var frames: Array[Frame] = []
	for virtual in keys.frames_until(now):
		var fresh := false
		while not _microphone_frames.is_empty() \
			and _microphone_frames[0].t <= virtual.t + 0.000001:
			_latest = _microphone_frames.pop_front()
			fresh = true
		if virtual.level > 0.0:
			virtual.cents *= maxf(500.0, profile.band_width_cents + 80.0) / 500.0
			frames.append(virtual)
		elif kind == 0 and virtual.t - _latest.t < 0.04:
			var combined := Frame.new(virtual.t, _latest.level,
				_latest.flux if fresh else 0.0, _latest.voiced,
				_latest.cents, _latest.clarity)
			combined.raw_level = _latest.raw_level
			frames.append(combined)
		else:
			frames.append(virtual)
	return frames

func noise_floor() -> float:
	return profile.normalized_level(profile.noise_floor, quiet) if kind == 0 else 0.01

func measured_bleed() -> float:
	return profile.normalized_level(profile.bleed_level, quiet) if kind == 0 else 0.0

func close() -> void:
	if is_instance_valid(capture):
		capture.close()
		capture.queue_free()
	capture = null
	keys.reset()
	_microphone_frames.clear()
	_latest = Frame.new(-100.0)

func _on_failure(reason: String) -> void:
	close()
	capture_failed.emit(reason)
