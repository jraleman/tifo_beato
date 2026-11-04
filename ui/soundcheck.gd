extends MenuScreen

## Explicit, measured calibration; decline and dead devices always leave Buttons usable.

signal completed(profile: RefCounted, seat: int, instrument: int, any_sound: bool)
signal cancelled(use_buttons: bool)
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Source = preload("res://games/tifo_beato/sound/input_stream.gd")
const Profile = preload("res://games/tifo_beato/sound/voice_profile.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Latency = preload("res://games/tifo_beato/sound/latency_calibration.gd")
const Audio = preload("res://games/tifo_beato/audio/tifo_audio.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
const NAMES := ["Room", "Eight steady claps", "Comfortable speaking",
	"Comfortable carrying line", "Comfortable pitch range", "Speakers check"]
const SILENT_ROOM := "Digital silence: check the device or mute switch, retry, or use Buttons."
var seat := 0
var instrument := 0
var profile := Profile.new()
var bindings: Array[int] = [KEY_F, KEY_J]
var _source := Source.new()
var _classifier := Classifier.new()
var _latency := Latency.new()
var _audio: Audio
var _panel: PanelContainer
var _layout: VBoxContainer
var _title: Label
var _copy: Label
var _meter: Label
var _status: Label
var _next: Button
var _headphones: CheckButton
var _any_sound: CheckButton
var _step := 0
var _pitch_step := 0
var _started := false
var _values: Array[float] = []
var _elapsed := 0.0
var _high_cents := 0.0
var _low_cents := 0.0
var _speaker_pulses := 0
var _first_sample := -1.0
var _failed := false
var _measurement_done := false
var _actions: GridContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	add_child(_panel)
	_layout = VBoxContainer.new()
	_panel.add_child(_layout)
	_title = Widgets.label(_layout, "P%d SOUNDCHECK" % (seat + 1), true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_layout.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_copy = Widgets.label(body, "No audio is monitored or saved. Only calibration numbers are stored.\n"
		+ "Use a comfortable voice. Stop if anything feels uncomfortable.\n"
		+ ("Tap Start to allow private microphone capture." if instrument == 0 else (
			"Buttons timing: tap the Beat keys or the big pad with eight guide thumps.")))
	if instrument == 0:
		var devices: Array[String] = []
		for device in AudioServer.get_input_device_list():
			devices.append(device)
		if not devices.is_empty():
			Widgets.choice(body, "Input device", devices,
				maxi(0, devices.find(AudioServer.input_device)),
				func(index: int) -> void: AudioServer.input_device = devices[index])
	_headphones = Widgets.toggle(body, "Headphones", profile.headphones,
		func(_value: bool) -> void: pass)
	_any_sound = Widgets.toggle(body, "Any sound (type + pitch)", false,
		func(_value: bool) -> void: pass)
	_any_sound.tooltip_text = "Ignore note type and pitch; Rests still require silence."
	_meter = Widgets.label(body, "Not recording.")
	_status = Widgets.label(body, "")
	var tap := Widgets.button(body, "BEAT - tap with the guide", _tap)
	tap.visible = instrument == 1
	tap.focus_mode = Control.FOCUS_NONE
	_actions = GridContainer.new()
	_actions.columns = 2
	_layout.add_child(_actions)
	_next = Widgets.button(_actions, "Start", _advance_step)
	Widgets.button(_actions, "Retry", _retry)
	Widgets.button(_actions, "Use Buttons", func() -> void: cancelled.emit(true))
	var cancel := Widgets.button(_actions, "Cancel",
		func() -> void: cancelled.emit(false))
	cancel.accessibility_description = "Cancel and keep the previous measured profile."
	first_focus = _next
	_audio = Audio.new()
	add_child(_audio)
	_source.capture_failed.connect(_on_failure)
	super()

func go_back() -> void:
	cancelled.emit(false)

func _enter_step() -> void:
	_failed = false
	_measurement_done = false
	_values.clear()
	_elapsed = 0.0
	_first_sample = -1.0
	_classifier.reset()
	_speaker_pulses = 0
	_status.text = ""
	_title.text = "P%d: %s (%d/6)" % [seat + 1, NAMES[_step], _step + 1]
	_next.text = "Next" if _step < 5 and instrument == 0 else "Save"
	if _step == 1:
		_latency = Latency.new()
		for pulse in 8:
			_latency.clicks.append(pulse * 0.6)
		_audio.play_track(_latency.clicks, 6.0)
		_copy.text = "Eight guide thumps at 100 BPM. First two are a count-in.\n" \
			+ "Clap or tap steadily with the next six; do not chase the meter."
	else:
		_audio.play_track([], 90.0)
		var directions := ["Keep the room quiet for two seconds.", "",
			"Say your club name a few times at a comfortable speaking level.",
			"Carry a short terrace line comfortably. Never strain or chase volume.",
			["Hum your comfortable centre note.", "Hum a little higher, comfortably.",
				"Hum a little lower, comfortably."][_pitch_step],
			"Stay quiet while the original crowd syllables play. This measures speaker bleed."]
		_copy.text = str(directions[_step])
	_source.begin(self, instrument, profile, 0.0, false)
	_classifier.noise_floor = _source.noise_floor()
	_classifier.band_width = profile.band_width_cents
	_next.disabled = true

func _advance_step() -> void:
	if not _started:
		_started = true
		_step = 1 if instrument == 1 else 0
		if instrument == 1:
			profile.make_virtual()
		_enter_step()
		return
	if not _measure_step():
		return
	_source.close()
	_audio.stop()
	if instrument == 1 or _step == 5:
		profile.calibrated = true
		profile.headphones = _headphones.button_pressed
		var error := profile.save_file(seat, Profile.SAVE_PATH,
			"buttons" if instrument == 1 else "mic")
		if error != OK:
			_status.text = "Could not save the measurements: " + error_string(error)
			_next.disabled = true
			return
		completed.emit(profile, seat, instrument, _any_sound.button_pressed)
		return
	if _step == 4 and _pitch_step < 2:
		_pitch_step += 1
	else:
		_step += 1
	_enter_step()

func _measure_step() -> bool:
	if _step == 1:
		var result := _latency.measure()
		_status.text = str(result["message"])
		if not bool(result["ok"]):
			return false
		profile.latency_ms = float(result["latency_ms"])
		return true
	if _values.is_empty():
		_status.text = "No usable samples yet. Retry, choose a device, or use Buttons."
		return false
	var median := _median(_values)
	match _step:
		0:
			if float(_values.max()) <= 0.0:
				_status.text = SILENT_ROOM
				return false
			profile.noise_floor = clampf(median, 0.00001, 0.2)
		2, 3:
			var audible := _values.filter(func(value: float) -> bool:
				return value > profile.noise_floor * 2.0)
			if audible.size() < 35:
				_status.text = "No steady voice above the room floor. Retry or use Buttons."
				return false
			if _step == 2:
				profile.speak_level = clampf(_median(audible), 0.0001, 1.0)
			else:
				profile.carry_level = clampf(_median(audible), profile.speak_level, 1.0)
		4:
			if _pitch_step == 0:
				profile.centre_hz = clampf(median, 75.0, 900.0)
			elif _pitch_step == 1:
				_high_cents = 1200.0 * log(median / profile.centre_hz) / log(2.0)
			else:
				_low_cents = 1200.0 * log(median / profile.centre_hz) / log(2.0)
				var range_cents := minf(_high_cents, -_low_cents)
				if range_cents < 160.0 and not _any_sound.button_pressed:
					_status.text = "A narrow comfortable range is fine. Enable Any sound, retry, or use Buttons."
					return false
				profile.band_width_cents = clampf(range_cents * 0.5, 80.0, 500.0)
		5:
			profile.bleed_level = clampf(_values.max(), 0.0, 1.0)
	return true

func _process(_delta: float) -> void:
	if not _started or _failed or _measurement_done or _audio == null:
		return
	var now := _audio.now()
	for frame in _source.frames_until(now):
		var sample_available := instrument == 1 or _source.mic._sample_count > 0
		if sample_available and _first_sample < 0.0:
			_first_sample = frame.t
		if not sample_available:
			continue
		_elapsed = maxf(0.0, frame.t - _first_sample)
		if _step == 1:
			for event in _classifier.consume(frame):
				if event.kind == Event.ONSET:
					_latency.onsets.append(event.t)
		elif _elapsed <= 8.0:
			if _step == 4:
				if frame.voiced and frame.clarity >= 0.8:
					_values.append(profile.centre_hz * pow(2.0, frame.cents / 1200.0))
			else:
				_values.append(frame.raw_level)
		_meter.text = "Level %d%% (carry capped) | %s | %.1fs measured" % [
			roundi(minf(1.0, frame.level) * 100.0),
			"voiced" if frame.voiced else "unvoiced", _elapsed]
	if instrument == 0 and _step == 0 and _elapsed >= 2.0 \
		and not _values.is_empty() and float(_values.max()) <= 0.0:
		_on_failure(SILENT_ROOM)
		return
	if _step == 5 and now >= _speaker_pulses * 0.7 and _speaker_pulses < 4:
		_audio.capo((_speaker_pulses % 3) - 1)
		_speaker_pulses += 1
	_status.text = "Guide finished. Save or retry." if _step == 1 and now >= 4.9 else _status.text
	_next.disabled = _elapsed < (4.8 if _step == 1 else 2.0) \
		or (_step == 4 and _values.size() < 35)
	if _step == 5 and _values.size() > 100 and float(_values.max()) > profile.noise_floor * 4.0:
		_status.text = "Speaker bleed detected. Headphones or Buttons are recommended, not required."
	if _elapsed >= (6.0 if _step == 1 else 8.0):
		_source.close()
		_audio.set_paused(true)
		_measurement_done = true
		_meter.text = "Measurement complete. Capture stopped; press Next."

func _unhandled_input(event: InputEvent) -> void:
	if instrument == 1 and _started and _step == 1 and event is InputEventKey:
		if event.echo:
			return
		if event.keycode in bindings or event.physical_keycode in bindings:
			_source.set_action(Options.BEAT_LEFT, event.pressed, _audio.now(),
				"calibration_%d" % event.physical_keycode)
			get_viewport().set_input_as_handled()
			return
	super(event)

func _tap() -> void:
	if _started and _step == 1:
		var now := _audio.now()
		_source.set_action(Options.BEAT_LEFT, true, now, "calibration_pad")
		_source.set_action(Options.BEAT_LEFT, false, now + 0.04, "calibration_pad")

func _retry() -> void:
	_started = true
	if instrument == 1:
		profile.make_virtual()
		_step = 1
	_enter_step()

func _on_failure(reason: String) -> void:
	_failed = true
	_source.close()
	_audio.stop()
	_meter.text = "Capture stopped."
	_status.text = reason
	_next.disabled = true

func _on_layout_changed(dimensions: Vector2) -> void:
	if _panel == null:
		return
	var factor := Widgets.factor(self)
	var width := minf(dimensions.x - 32 * factor, 980 * factor)
	_panel.position = Vector2((dimensions.x - width) * 0.5, 18 * factor)
	_panel.size = Vector2(width, maxf(1.0, dimensions.y - 36 * factor))
	Widgets.scale_tree(_layout, factor)
	var compact := dimensions.y < 700 * factor
	for child in _layout.find_children("*", "BaseButton", true, false):
		child.custom_minimum_size.y = Widgets.touch_minimum(self) if compact else 64.0 * factor
		if compact:
			child.add_theme_font_size_override("font_size", roundi(18 * factor))
	if compact:
		_title.add_theme_font_size_override("font_size", roundi(22 * factor))

func _median(values: Array[float]) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[ordered.size() / 2]

func _exit_tree() -> void:
	stop_capture()

func stop_capture() -> void:
	_source.close()
	if _audio != null:
		_audio.stop()
