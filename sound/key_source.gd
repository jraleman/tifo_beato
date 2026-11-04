extends RefCounted

## Independent contacts become virtual acoustic frames, not privileged judge inputs.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const FRAME_SECONDS := 0.01
const BEAT_SECONDS := 0.04
var _contacts: Dictionary = {}
var _requested: Dictionary = {}
var _changes: Array[Dictionary] = []
var _bursts: Array[float] = []
var _attacks: Array[float] = []
var _next_frame := 0.0

func reset(time := 0.0) -> void:
	_contacts.clear()
	_requested.clear()
	_changes.clear()
	_bursts.clear()
	_attacks.clear()
	_next_frame = time

func set_action(action: StringName, pressed: bool, time: float, contact: String) -> void:
	if pressed:
		if _requested.has(contact) and _requested[contact] == action:
			return
		_requested[contact] = action
	else:
		_requested.erase(contact)
	var change := {"action": action, "pressed": pressed, "t": time, "contact": contact}
	var index := 0
	while index < _changes.size() and float(_changes[index]["t"]) <= time:
		index += 1
	_changes.insert(index, change)

func frame_at(time: float) -> Frame:
	while not _changes.is_empty() and float(_changes[0]["t"]) <= time + 0.000001:
		var change: Dictionary = _changes.pop_front()
		var contact := str(change["contact"])
		if bool(change["pressed"]):
			var action: StringName = change["action"]
			_contacts[contact] = action
			_attacks.append(float(change["t"]))
			if action in [Options.BEAT_LEFT, Options.BEAT_RIGHT]:
				_bursts.append(float(change["t"]))
		else:
			_contacts.erase(contact)
	var level := 0.0
	var voiced := false
	var cents := 0.0
	for action: StringName in _contacts.values():
		if action == Options.SHOUT:
			level = 1.0
		elif action in [Options.SING_LOW, Options.SING_MID, Options.SING_HIGH]:
			level = 1.0
			voiced = true
			cents = -500.0 if action == Options.SING_LOW else (
				500.0 if action == Options.SING_HIGH else 0.0)
	for attack in _bursts:
		if time >= attack - 0.000001 and time < attack + BEAT_SECONDS:
			level = maxf(level, 1.0 - maxf(0.0, time - attack) / BEAT_SECONDS * 0.9)
	var flux := 0.0
	while not _attacks.is_empty() and _attacks[0] <= time + 0.000001:
		flux = 1.0
		_attacks.pop_front()
	while not _bursts.is_empty() and time >= _bursts[0] + BEAT_SECONDS:
		_bursts.pop_front()
	return Frame.new(time, level, flux, voiced, cents, 1.0 if voiced else 0.0)

## Catch up every sample; a slow render frame cannot swallow a drum roll.
func frames_until(time: float) -> Array[Frame]:
	var frames: Array[Frame] = []
	while _next_frame <= time + 0.000001:
		frames.append(frame_at(_next_frame))
		_next_frame += FRAME_SECONDS
	return frames
