extends Control

## Explicit-start, memory-only numbers. No PCM or device data is saved.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Source = preload("res://games/tifo_beato/sound/input_stream.gd")
const Profile = preload("res://games/tifo_beato/sound/voice_profile.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Gate = preload("res://games/tifo_beato/sound/bleed_gate.gd")
const Audio = preload("res://games/tifo_beato/audio/tifo_audio.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
var _source := Source.new()
var _classifier := Classifier.new()
var _gate := Gate.new()
var _audio: Audio
var _instrument: OptionButton
var _status: Label
var _readout: Label
var _events: Label
var _active := false
var _counts: Dictionary = {}
var _lines := PackedStringArray()
var _frames := 0
var _peak := 0.0

func _ready() -> void:
	_audio = Audio.new()
	add_child(_audio)
	_source.capture_failed.connect(func(reason: String) -> void:
		_stop()
		_status.text = reason)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var body := VBoxContainer.new()
	margin.add_child(body)
	Widgets.label(body, "TIFO BEATO - NUMERIC SOUND DIAGNOSTICS", true)
	Widgets.label(body, "60-second explicit-start check. No microphone monitoring, audio file, or recording log.\n"
		+ "Comfortable voice only. Microphone uses P1's existing soundcheck; calibrate in the lobby first.")
	_instrument = Widgets.choice(body, "Instrument", ["Microphone", "Buttons"], 1,
		func(_value: int) -> void: _stop())
	Widgets.button(body, "Start this check", _start)
	Widgets.button(body, "Original speaker-output pulse", _output)
	Widgets.button(body, "Stop and release capture", _stop)
	_status = Widgets.label(body, "Stopped. Choosing an instrument opens nothing.")
	_readout = Widgets.label(body, "")
	_events = Widgets.label(body, "")
	_events.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _start() -> void:
	_stop()
	var profile := Profile.new()
	var instrument := _instrument.selected
	if instrument == 1:
		profile.make_virtual()
	elif profile.load_file(0) != OK:
		_status.text = "Cannot read P1 soundcheck. Capture remains closed."
		return
	elif not profile.calibrated:
		_status.text = "Complete P1's microphone soundcheck in the game before this diagnostic."
		return
	_counts.clear()
	_lines.clear()
	_frames = 0
	_peak = 0.0
	_classifier.reset()
	_classifier.noise_floor = profile.normalized_level(profile.noise_floor, false)
	_classifier.band_width = profile.band_width_cents
	_gate.emissions.clear()
	_gate.headphones = get_tree().root.get_node("Settings").call("tunable_bool", Options.HEADPHONES)
	var beats: Array[float] = []
	for pulse in 100:
		beats.append(pulse * 0.6)
	_audio.play_track(beats, 61.0)
	_active = true
	_status.text = "Checking: F/J Beat, Space Shout, A/S/D LOW/MID/HIGH. Rests mean silence."
	_source.begin(self, instrument, profile, 0.0, false)

func _stop() -> void:
	_active = false
	_source.close()
	if _audio != null:
		_audio.stop()
	if _status != null:
		_status.text = "Stopped; capture released. Numbers remain only on this screen."

func _output() -> void:
	if not _active:
		_status.text = "Start a check before testing the original output."
		return
	var call: Array[Dictionary] = [{"grade": 0, "kind": "sing", "band": 0,
		"note": {"t": 0.0}, "error": 0.0}]
	_audio.response(call, 0.0, 1.0, 0.25)
	_gate.register_output(_audio.now(), _source.measured_bleed(), 1.0)
	_status.text = "Original synthetic crowd pulse. Stay silent to inspect any bleed events."

func _process(_delta: float) -> void:
	if not _active:
		return
	var now := _audio.now()
	for frame in _source.frames_until(now):
		_frames += 1
		_peak = maxf(_peak, frame.level)
		_readout.text = "t %.2fs | %.1f frames/s | level %.3f (peak %.3f) | flux %.3f\n" \
			% [now, _frames / maxf(0.01, now), frame.level, _peak, frame.flux] \
			+ "voiced %s | cents %.0f | clarity %.2f | level gate %s | onsets/min %.1f" \
			% [frame.voiced, frame.cents, frame.clarity,
				_gate.accepts_level(frame.t, frame.level),
				int(_counts.get("onset", 0)) * 60.0 / maxf(0.01, now)]
		for event in _classifier.consume(frame):
			var name := str(event.kind)
			_counts[name] = int(_counts.get(name, 0)) + 1
			if name in ["shout", "sing"] and int(_counts[name]) % 10 != 1:
				continue
			_lines.append("%.2f %s | band %d | duration %.2f | gate %s" % [
				event.t, name, event.band, event.duration, _gate.accepts(event, true)])
			if _lines.size() > 12:
				_lines.remove_at(0)
	_events.text = "\n".join(_lines)
	_gate.prune(now)
	if now >= 60.0:
		_stop()

func _input(event: InputEvent) -> void:
	if not _active or not event is InputEventKey or event.echo:
		return
	var settings := get_tree().root.get_node("Settings")
	for binding in Options.CONTROL_BINDINGS:
		if binding["action"] not in Options.SOUND_ACTIONS:
			continue
		var code := int(settings.call("binding_keycode", str(binding["key"])))
		if event.physical_keycode == code or event.keycode == code:
			_source.set_action(binding["action"], event.pressed, _audio.now(), "key_" + str(code))
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_source.close()
