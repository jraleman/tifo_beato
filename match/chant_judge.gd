extends RefCounted

## Timing first. Classification delay and hold coverage do not widen timing grades.

const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const WINDOWS := [0.045, 0.09, 0.14]
const POINTS := [100, 70, 40, 0]
const GRADES := ["Perfect", "Great", "Good", "Miss"]
const REFILLS := [6.0, 4.0, 2.0, 0.0]
const TIERS := ["Keep it going", "Bucket Banger", "Terrace Thunder",
	"Scarf Hurricane", "Full Curva Meltdown"]
var notes: Array[Dictionary] = []
var settings: Dictionary = {}
var score := 0.0
var hits := 0
var attempts := 0
var combo := 0
var best_combo := 0
var perfect_streak := 0
var last_grade := ""
var _combo_steps := 0.0
var _spent_attacks: Dictionary = {}
var _results: Array[Dictionary] = []

func _init(chart_notes: Array[Dictionary] = [], configuration: Dictionary = {}) -> void:
	settings = configuration.duplicate(true)
	for note in chart_notes:
		var entry := note.duplicate(true)
		entry["done"] = false
		entry["coverage"] = 0.0
		entry["rest_broken"] = false
		entry["candidate"] = {}
		notes.append(entry)

func window_scale() -> float:
	return [1.0, 1.5, 2.0][clampi(int(settings.get("windows", 0)), 0, 2)] \
		* float(settings.get("window_bonus", 1.0))

func consume(event: Event) -> void:
	if event.kind == Event.SILENCE:
		return
	var best := -1
	var nearest := WINDOWS[2] * window_scale() + 0.000001
	for index in notes.size():
		var note := notes[index]
		if bool(note["done"]) or str(note["kind"]) == "rest":
			continue
		if not _accepts(note, event):
			continue
		var error := absf(event.t - float(note["t"]))
		if str(note["kind"]) == "hold" and event.t <= float(note["t"]) \
			and event.end_t >= float(note["t"]):
			error = 0.0
		if error <= nearest:
			nearest = error
			best = index
	if best < 0:
		return
	var note := notes[best]
	var kind := str(note["kind"])
	var attack_key := snappedf(event.t, 0.00001)
	if kind != "hold" and _spent_attacks.has(attack_key):
		return
	var grade := timing_grade(nearest)
	var pitch := 1.0
	if not bool(settings.get("any_sound", false)) \
		and (kind == "sing" or (kind == "hold" and str(note["hold_kind"]) == "sing")):
		if not event.voiced:
			return
		pitch = 1.0 if event.band == int(note["band"]) else 0.6
	var candidate := {"grade": grade, "level": minf(event.level, 1.0),
		"pitch": pitch, "band": event.band, "error": event.t - float(note["t"]), "duration": event.duration}
	if kind == "hold":
		if (note["candidate"] as Dictionary).is_empty():
			note["candidate"] = candidate
	else:
		_spent_attacks[attack_key] = true
		_finish(best, candidate)

func observe(frame: Frame, dt := 0.01) -> void:
	for note in notes:
		if bool(note["done"]):
			continue
		var start := float(note["t"])
		var duration := float(note["duration"])
		if frame.t < start - 0.000001 or frame.t >= start + duration - 0.000001:
			continue
		if str(note["kind"]) == "rest":
			if frame.level >= 0.08:
				note["rest_broken"] = true
		elif str(note["kind"]) == "hold":
			var sing := str(note["hold_kind"]) == "sing"
			if frame.level >= 0.08 and (not sing or frame.voiced \
				or bool(settings.get("any_sound", false))):
				note["coverage"] = float(note["coverage"]) + dt

## Hold/rest deadlines include their length, while the attack is still judged at its start.
func advance(time: float) -> Array[Dictionary]:
	for index in notes.size():
		var note := notes[index]
		if bool(note["done"]):
			continue
		var kind := str(note["kind"])
		var start := float(note["t"])
		var duration := float(note["duration"])
		if kind == "rest" and time >= start + duration:
			_finish(index, {"grade": 3 if bool(note["rest_broken"]) else 0,
				"level": 1.0, "pitch": 1.0, "error": 0.0, "duration": duration})
		elif kind == "hold" and time >= start + duration + WINDOWS[2] * window_scale():
			var candidate: Dictionary = note["candidate"]
			if not candidate.is_empty() and float(note["coverage"]) >= duration * 0.8:
				_finish(index, candidate)
			else:
				_finish(index, {"grade": 3, "level": 1.0, "pitch": 1.0})
		elif kind not in ["rest", "hold"]:
			var classify_delay := 0.17 if kind in ["sing", "shout"] else 0.0
			if time > start + WINDOWS[2] * window_scale() + classify_delay:
				if bool(note.get("optional", false)):
					note["done"] = true
				else:
					_finish(index, {"grade": 3, "level": 1.0, "pitch": 1.0})
	var results := _results
	_results = []
	return results

func timing_grade(error: float) -> int:
	for grade in 3:
		if error <= WINDOWS[grade] * window_scale() + 0.000001:
			return grade
	return 3

func combo_tier() -> int:
	return 4 if combo >= 64 else (3 if combo >= 32 else (2 if combo >= 16 else (
		1 if combo >= 8 else 0)))

func combo_name() -> String:
	return TIERS[4 if best_combo >= 64 else (3 if best_combo >= 32 else (
		2 if best_combo >= 16 else (1 if best_combo >= 8 else 0)))]

func accuracy() -> float:
	return float(hits) / attempts if attempts > 0 else 0.0

func rest_protected(time: float) -> bool:
	for note in notes:
		if str(note["kind"]) == "rest" and time >= float(note["t"]) - 0.000001 \
			and time < float(note["t"]) + float(note["duration"]) - 0.000001:
			return not bool(note["rest_broken"])
	return false

func _accepts(note: Dictionary, event: Event) -> bool:
	if bool(settings.get("any_sound", false)):
		return event.kind != Event.SILENCE
	match str(note["kind"]):
		"beat":
			return event.kind == Event.ONSET
		"shout":
			return event.kind == Event.SHOUT and event.duration >= 0.15 - 0.000001
		"sing":
			return event.kind == Event.SING and event.voiced
		"hold":
			return event.kind == Event.SING if str(note["hold_kind"]) == "sing" \
				else event.kind == Event.SHOUT
	return false

func _finish(index: int, candidate: Dictionary) -> void:
	var note := notes[index]
	note["done"] = true
	var grade := int(candidate["grade"])
	attempts += 1
	if grade < 3:
		hits += 1
		if grade <= 1:
			_combo_steps += 1.25 if str(note["kind"]) == "beat" \
				and int(settings.get("pool", 0)) == 2 else 1.0
			combo = floori(_combo_steps)
		perfect_streak = perfect_streak + 1 if grade == 0 else 0
	else:
		combo = 0
		_combo_steps = 0.0
		perfect_streak = 0
	best_combo = maxi(best_combo, combo)
	var multiplier: float = [1.0, 1.5, 2.0, 3.0, 4.0][combo_tier()]
	var volume := minf(1.2, 0.8 + 0.4 * clampf(float(candidate["level"]), 0.0, 1.0))
	# Fixed carry-equivalent scoring makes Quiet Mode amplitude-independent and non-penalizing.
	if bool(settings.get("quiet", false)):
		volume = 1.2
	var points: float = POINTS[grade] * volume * float(candidate["pitch"]) * multiplier
	if str(note["kind"]) == "sing" and int(settings.get("pool", 0)) == 1:
		points *= 1.2
	points *= float(settings.get("score_bonus", 1.0))
	score += points
	last_grade = GRADES[grade]
	_results.append({"grade": grade, "name": last_grade, "points": points,
		"refill": REFILLS[grade], "kind": str(note["kind"]), "note": note.duplicate(true),
		"level": candidate["level"], "duration": candidate.get("duration", 0.0),
		"band": candidate.get("band", note.get("band", 0)),
		"error": candidate.get("error", 0.0), "combo": combo})
