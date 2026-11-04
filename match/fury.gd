extends RefCounted

## A per-note cap keeps ideal clap and held-shout charging exactly equivalent.

const NOTE_CHARGE := 3.125
const ACTIVE_SECONDS := 8.0
const LONG_SHOUT_SECONDS := 1.5
var charge := 0.0
var active_left := 0.0
var half := 1
var uses := 0
var used_halves: Array[int] = []
var power := ""
var active_power := ""
var power_left := 0.0
var protection_left := 0.0
var ref_distraction := false
var drum_beats := 0
var _shouts: Array[float] = []

func award(grade: int, kind: String, level: float, duration: float) -> void:
	if half in used_halves or active_left > 0.0:
		return
	var perfect_charge := NOTE_CHARGE if grade == 0 else 0.0
	var sustain_charge := 0.0
	if grade < 3 and kind in ["shout", "hold"]:
		sustain_charge = NOTE_CHARGE * minf(duration / 0.5, 1.0) * clampf(level, 0.0, 1.0)
	charge = minf(100.0, charge + maxf(perfect_charge, sustain_charge))

func activate(judging: bool) -> bool:
	if not judging or charge < 100.0 or half in used_halves:
		return false
	charge = 0.0
	active_left = ACTIVE_SECONDS
	used_halves.append(half)
	uses += 1
	return true

func offer_power(id: String) -> void:
	if power.is_empty():
		power = id

func activate_power() -> String:
	var activated := power
	match power:
		"megaphone":
			power_left = 12.0
		"drum":
			power_left = 16.0
			drum_beats = 0
		"tornado":
			protection_left = 15.0
		"ref":
			ref_distraction = true
	if not activated.is_empty():
		power = ""
		active_power = activated if activated in ["megaphone", "drum"] else ""
	return activated

func triple_shout(time: float, empty_bar: bool) -> bool:
	if not empty_bar:
		_shouts.clear()
		return false
	_shouts.append(time)
	while not _shouts.is_empty() and time - _shouts[0] > 2.0:
		_shouts.pop_front()
	if _shouts.size() >= 3:
		_shouts.clear()
		return not power.is_empty()
	return false

func advance(dt: float) -> void:
	active_left = maxf(0.0, active_left - dt)
	power_left = maxf(0.0, power_left - dt)
	protection_left = maxf(0.0, protection_left - dt)
	if power_left <= 0.0:
		active_power = ""
