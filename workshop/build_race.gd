extends RefCounted

## The same judge turns strokes, unrolling and stitches into quality and comic mishaps.

const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
var banner: Banner
var judge: Judge
var classifier := Classifier.new()
var duration := 48.0
var time := 0.0
var complete := false
var _rng := RandomNumberGenerator.new()
var beat_seconds := 0.6
var latency_ms := 0.0

func _init(design: Banner, budget := 24, seed_value := 1,
	configuration: Dictionary = {}) -> void:
	banner = design
	banner.mishaps.clear()
	_rng.seed = seed_value
	for extra in mini(8, ceili(float(banner.overspend(budget)) / 4.0)):
		banner.apply_mishap(_rng)
	var notes: Array[Dictionary] = []
	beat_seconds = 0.6 / (float(configuration.get("speed", 100)) / 100.0)
	duration = beat_seconds * 82.0
	for beat in 80:
		var kind := "beat"
		if beat % 8 == 3:
			kind = "shout"
		elif beat % 8 == 6:
			kind = "sing"
		notes.append({"id": beat, "t": (beat + 2) * beat_seconds, "kind": kind,
			"duration": beat_seconds * 0.5 if kind != "beat" else 0.0,
			"band": 0, "hold_kind": "sing"})
	var settings := configuration.duplicate(true)
	settings["quiet"] = true
	judge = Judge.new(notes, settings)

func consume(frame: Frame) -> void:
	if complete:
		return
	frame = Frame.new(frame.t - latency_ms / 1000.0, frame.level, frame.flux,
		frame.voiced, frame.cents, frame.clarity)
	judge.observe(frame)
	for event in classifier.consume(frame):
		judge.consume(event)

func advance(now: float) -> Array[Dictionary]:
	if complete:
		return []
	time = minf(now, duration + 0.4)
	var results := judge.advance(time - maxf(0.0, latency_ms) / 1000.0)
	for result in results:
		if int(result["grade"]) == 3:
			banner.apply_mishap(_rng)
	if now >= duration + 0.4:
		complete = true
		banner.quality = judge.accuracy() * 100.0
	return results
