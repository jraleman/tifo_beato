extends RefCounted

## Red-light flag steps and a quiet hum interview share the acoustic classifier.

const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
var kind := "flag"
var duration := 32.0
var progress := 0
var mistakes := 0
var hum_seconds := 0.0
var complete := false
var success := false
var time := 0.0
var classifier := Classifier.new()
var _last_step := -1
var _last_freeze := -1
var latency_ms := 0.0

func _init(mode := "flag") -> void:
	kind = mode

func watching(now: float) -> bool:
	return floori(now / 0.6) % 8 >= 5

func consume(frame: Frame) -> void:
	if complete:
		return
	frame = Frame.new(frame.t - latency_ms / 1000.0, frame.level, frame.flux,
		frame.voiced, frame.cents, frame.clarity)
	if kind == "flag" and watching(frame.t) and frame.level >= 0.08:
		var freeze := floori(frame.t / 0.6)
		if freeze != _last_freeze:
			_last_freeze = freeze
			mistakes += 1
			progress = maxi(0, progress - 4)
	for event in classifier.consume(frame):
		if kind == "flag" and event.kind == Event.ONSET:
			var beat := roundi(frame.t / 0.6)
			if absf(frame.t - beat * 0.6) > 0.14 or beat == _last_step:
				continue
			_last_step = beat
			if watching(frame.t):
				continue
			else:
				progress += 1
		elif kind == "coat" and event.kind == Event.CLAP:
			mistakes += 1
	if kind == "coat" and frame.voiced and frame.clarity >= 0.8 \
		and frame.level >= 0.08 and frame.level <= 1.2 and absf(frame.cents) <= 250.0:
		hum_seconds += 0.01

func advance(now: float) -> void:
	time = now
	if now >= duration + maxf(0.0, latency_ms) / 1000.0:
		complete = true
		success = progress >= 20 if kind == "flag" else (
			hum_seconds >= duration * 0.75 and mistakes <= 1)

func caption() -> String:
	if kind == "coat":
		return "DRUM IN THE COAT: hold Sing MID. No sharp sounds."
	return "FREEZE: the steward is watching." if watching(time) \
		else "STEP: Beat with the drum. Freeze when the head turns."
