extends SceneTree

## Synthetic DSP and source parity checks; these do not claim real-room certification.

const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Pitch = preload("res://games/tifo_beato/sound/pitch_detector.gd")
const Mic = preload("res://games/tifo_beato/sound/mic_source.gd")
const Profile = preload("res://games/tifo_beato/sound/voice_profile.gd")
const Key = preload("res://games/tifo_beato/sound/key_source.gd")
const Touch = preload("res://games/tifo_beato/sound/touch_source.gd")
const Cpu = preload("res://games/tifo_beato/sound/cpu_source.gd")
const Gate = preload("res://games/tifo_beato/sound/bleed_gate.gd")
const Guide = preload("res://games/tifo_beato/sound/guide_drum.gd")
const Latency = preload("res://games/tifo_beato/sound/latency_calibration.gd")
const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	for rate in [44100, 48000]:
		for frequency in [80.0, 164.81, 220.0, 293.66, 880.0]:
			var result := Pitch.analyse(_tone(frequency, rate, 0.12), rate)
			expect(bool(result["voiced"]) and absf(Pitch.cents_from(
				float(result["hz"]), frequency)) < 15.0, "MPM pitch/rate: %s/%s" % [frequency, rate])
	var classifier := Classifier.new()
	var onsets := 0
	for tick in 100:
		for event in classifier.consume(Frame.new(tick * 0.01,
			1.0 if tick % 8 == 0 else 0.0, 1.0 if tick % 8 == 0 else 0.0)):
			onsets += 1 if event.kind == Event.ONSET else 0
	expect(onsets == 13, "Fast drum rolls must stay separate.")
	for band in [-1, 0, 1]:
		classifier = Classifier.new()
		var found := false
		for tick in 40:
			for event in classifier.consume(Frame.new(tick * 0.01, 1.0,
				1.0 if tick == 0 else 0.0, true, band * 500.0, 1.0)):
				if event.kind == Event.SING and event.band == band:
					found = true
		expect(found, "Sing rung must be relative: " + str(band))
	classifier = Classifier.new()
	var shouted := false
	for tick in 40:
		for event in classifier.consume(Frame.new(tick * 0.01, 1.0,
			1.0 if tick == 0 else 0.0, false)):
			shouted = shouted or event.kind == Event.SHOUT
	expect(shouted, "Unvoiced sustained shouts must not require pitch.")
	var gate := Gate.new()
	gate.register_output(1.0, 0.3, 0.1)
	expect(not gate.accepts(Event.new(1.02, Event.ONSET, 0.3), true), "Known bleed must be rejected.")
	expect(gate.accepts(Event.new(1.02, Event.ONSET, 0.8), true), "Stronger genuine input must survive.")
	expect(not gate.accepts(Event.new(2.0), false), "Responses must never score.")
	var mic := Mic.new()
	mic.sample_rate = Guide.RATE
	mic.profile.carry_level = 1.0
	mic.profile.speak_level = 1.0
	mic.profile.noise_floor = 0.002
	var guide_onsets := 0
	classifier = Classifier.new()
	classifier.noise_floor = 0.002
	var samples := PackedFloat32Array()
	for beat in 8:
		samples.append_array(Guide.thump_samples())
		var silence := PackedFloat32Array()
		silence.resize(roundi(Guide.RATE * (0.6 - Guide.THUMP_SECONDS)))
		samples.append_array(silence)
	for frame in mic.push_samples(samples):
		for event in classifier.consume(frame):
			guide_onsets += 1 if event.kind in [Event.ONSET, Event.SHOUT, Event.SING] else 0
	expect(guide_onsets == 0, "The game's own guide must not classify as player input.")
	mic.reset()
	mic.profile.carry_level = 0.16
	mic.profile.speak_level = 0.08
	mic.quiet = true
	var broken_rests := 0
	for frame in mic.push_samples(samples):
		broken_rests += 1 if frame.level >= 0.08 else 0
	expect(broken_rests == 0,
		"The low guide must not break Rests when Quiet Mode normalizes to speaking level.")
	var calibration := Latency.new()
	for click in 8:
		calibration.clicks.append(click * 0.6)
		calibration.onsets.append(click * 0.6 + 0.095 + (0.002 if click % 2 else -0.002))
	var measurement := calibration.measure()
	expect(bool(measurement["ok"]) and absf(float(measurement["latency_ms"]) - 95.0) < 3.0,
		"Calibration must measure round-trip median.")
	calibration.onsets = [1.3, 1.9, 2.9, 3.1, 3.7, 4.5]
	expect(not bool(calibration.measure()["ok"]), "Loose calibration must be rejected.")
	_test_source_parity()
	_test_queued_contacts()
	var queued := Key.new()
	queued.set_action(Options.BEAT_LEFT, true, 0.0, "tap")
	queued.set_action(Options.BEAT_LEFT, false, 0.04, "tap")
	queued.set_action(Options.SING_MID, true, 0.01, "finger")
	expect(queued.frame_at(0.02).voiced,
		"A scheduled tap release cannot postpone a different finger's earlier press.")
	_test_independent_touch()
	_finish()

func _test_source_parity() -> void:
	var pattern: Array[Dictionary] = [
		{"id": 0, "t": 0.2, "kind": "beat", "duration": 0.0, "band": 0, "hold_kind": "shout"},
		{"id": 1, "t": 0.8, "kind": "shout", "duration": 0.3, "band": 0, "hold_kind": "shout"},
		{"id": 2, "t": 1.6, "kind": "sing", "duration": 0.35, "band": -1, "hold_kind": "shout"},
		{"id": 3, "t": 2.4, "kind": "hold", "duration": 0.7, "band": 1, "hold_kind": "sing"},
		{"id": 4, "t": 3.5, "kind": "rest", "duration": 0.3, "band": 0, "hold_kind": "shout"},
	]
	var acoustic := Cpu.new(pattern)
	var keys := Key.new()
	var judges: Array[Judge] = [Judge.new(pattern), Judge.new(pattern)]
	var classifiers: Array[Classifier] = [Classifier.new(), Classifier.new()]
	var started := {}
	var stopped := {}
	for tick in 420:
		var time := tick * 0.01
		for index in pattern.size():
			var note := pattern[index]
			if note["kind"] == "rest":
				continue
			var action: StringName = Options.BEAT_LEFT
			if note["kind"] == "shout":
				action = Options.SHOUT
			elif note["kind"] in ["sing", "hold"]:
				action = Options.SING_LOW if int(note["band"]) == -1 else Options.SING_HIGH
			if not started.has(index) and time >= float(note["t"]) - 0.000001:
				started[index] = true
				keys.set_action(action, true, time, str(index))
			if not stopped.has(index) and time >= float(note["t"]) \
				+ maxf(0.04, float(note["duration"])):
				stopped[index] = true
				keys.set_action(action, false, time, str(index))
		var frames: Array[Frame] = [acoustic.frame_at(time), keys.frame_at(time)]
		for source in 2:
			judges[source].observe(frames[source])
			for event in classifiers[source].consume(frames[source]):
				judges[source].consume(event)
			judges[source].advance(time)
	expect(judges[0].hits == pattern.size() and judges[1].hits == pattern.size(),
		"Acoustic and button streams must finish every note type.")
	expect(absf(judges[0].score - judges[1].score) <= judges[0].score * 0.05,
		"Ideal acoustic and button scores must agree within 5%.")

func _test_queued_contacts() -> void:
	var boundary := Key.new()
	boundary.set_action(Options.BEAT_LEFT, true, 2.46, "fractional")
	var attack := boundary.frame_at(2.45999999999999)
	expect(attack.flux == 1.0 and attack.level == 1.0,
		"Floating sample drift must never consume an onset before its burst becomes audible.")
	var keys := Key.new()
	keys.set_action(Options.SHOUT, true, 0.125, "finger")
	keys.set_action(Options.SHOUT, false, 0.175, "finger")
	for frame in keys.frames_until(0.22):
		var held := frame.t >= 0.125 and frame.t < 0.175
		expect(is_equal_approx(frame.level, 1.0 if held else 0.0),
			"Catch-up frames must respect the actual press and release timestamps.")

func _test_independent_touch() -> void:
	var touch := Touch.new()
	var keys := Key.new()
	touch.action_changed.connect(func(action: StringName, pressed: bool, contact: String) -> void:
		keys.set_action(action, pressed, 0.0, contact))
	touch.press(1, Options.SHOUT)
	touch.press(2, Options.SHOUT)
	touch.release(1)
	expect(keys.frame_at(0.0).level == 1.0,
		"Releasing one finger must not release another finger's held Shout.")
	touch.clear()
	expect(keys.frame_at(0.01).level == 0.0, "Handoffs must release every touch contact.")

func _tone(frequency: float, rate: int, seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(rate * seconds))
	for i in samples.size():
		samples[i] = sin(TAU * frequency * float(i) / rate) * 0.5
	return samples

func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("Tifo sound tests: %d failures." % failures.size())
	quit(0 if failures.is_empty() else 1)
