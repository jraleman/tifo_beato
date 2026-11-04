extends RefCounted

## Dispatches real input events; never changes a grade, score or completion flag.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
var game: Node
var use_touch := false
var _held: Array[Dictionary] = []
var _played: Dictionary = {}
var _pointer := -1
var _beat_hand := 0
var _ticks := 0
var _queue: Array[Dictionary] = []
var _queue_scope := ""
var _queue_revision := -1
var _cursor := 0

func _init(node: Node, touch_mode := false) -> void:
	game = node
	use_touch = touch_mode

func tick(render_every := 4) -> void:
	var audio: Node = game.get("_audio")
	var now := float(audio.get("manual_time")) + 0.01
	audio.set("manual_time", now)
	for index in range(_held.size() - 1, -1, -1):
		if now >= float(_held[index]["end"]) - 0.000001:
			_dispatch(_held[index], false)
			_held.remove_at(index)
	var stage := str(game.get("_stage"))
	var model: RefCounted
	match stage:
		"match": model = game.get("_state")
		"war": model = game.get("_war")
		"workshop": model = game.get("_build")
		"steward": model = game.get("_steward")
	if model != null and bool(game.get("_input_started")):
		var latency := _latency()
		var scope := str(model.get_instance_id())
		if stage == "war":
			scope += "_%d" % int(model.get("phase"))
		var revision := int(model.get("chart_revision")) if stage == "match" else 0
		if scope != _queue_scope or revision != _queue_revision:
			_queue_scope = scope
			_queue_revision = revision
			_cursor = 0
			_queue = _notes(stage, model)
			_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["t"]) < float(b["t"]))
		while _cursor < _queue.size():
			var note := _queue[_cursor]
			var key := scope + "_" + str(note["id"])
			var target := float(note["t"]) + latency
			if now < target - 0.000001:
				break
			_cursor += 1
			if bool(note.get("done", false)) or str(note["kind"]) == "rest" or _played.has(key) \
				or now > target + 0.015:
				continue
			_played[key] = true
			var kind := str(note["kind"])
			var action: StringName = Options.SHOUT
			if kind == "beat":
				action = Options.BEAT_LEFT if _beat_hand % 2 == 0 else Options.BEAT_RIGHT
				_beat_hand += 1
			elif kind == "sing" or kind == "hold" and str(note.get("hold_kind", "shout")) == "sing":
				action = [Options.SING_LOW, Options.SING_MID, Options.SING_HIGH][int(note.get("band", 0)) + 1]
			_pointer = _new_pointer()
			var contact := {"action": action, "pointer": _pointer,
				"end": now + (0.04 if kind == "beat" else maxf(0.22, float(note["duration"])))}
			_held.append(contact)
			_dispatch(contact, true)
		if stage == "match" and model.get("fury").get("active_left") == 0.0 \
			and float(model.get("fury").get("charge")) >= 100.0:
			_press(Options.FURY)
		if stage == "match" and str(model.get("fury").get("power")) == "drum" \
			and str(model.call("phase")["kind"]) == "call":
			_press(Options.POWER)
		elif stage == "match" and str(model.get("fury").get("power")) == "megaphone":
			_press(Options.POWER)
	_ticks += 1
	if _ticks % render_every == 0:
		game.call("_update_round", 0.01 * render_every, 0.0)

func _notes(stage: String, model: RefCounted) -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	if stage in ["match", "workshop"]:
		notes.assign(model.get("judge").get("notes"))
	elif stage == "war" and int(model.get("phase")) > 0:
		var judge: RefCounted = model.get("judge")
		if judge != null:
			notes.assign(judge.get("notes"))
		else:
			var turn: Dictionary = model.get("phases")[int(model.get("phase"))]
			for hit in 8:
				notes.append({"id": hit, "t": float(turn["call_t"]) + hit * float(turn["beat"]),
					"kind": "beat", "duration": 0.0, "done": false})
	elif stage == "steward" and str(model.get("kind")) == "coat":
		notes = [{"id": 0, "t": 0.01, "kind": "hold", "hold_kind": "sing",
			"duration": 25.0, "band": 0, "done": false}]
	elif stage == "steward":
		for pulse in 54:
			var t := pulse * 0.6
			if not bool(model.call("watching", t)):
				notes.append({"id": pulse, "t": t, "kind": "beat", "duration": 0.0, "done": false})
	return notes

func release_all() -> void:
	for contact in _held:
		_dispatch(contact, false)
	_held.clear()

func _latency() -> float:
	var seat := int(game.get("_seat"))
	var profiles: Array = game.get("_button_profiles")
	return clampf(float(profiles[seat].get("latency_ms")) + float(
		game.get_tree().root.get_node("Settings").call("tunable", Options.LATENCY)), -100.0, 400.0) / 1000.0

func _press(action: StringName) -> void:
	_pointer = _new_pointer()
	var contact := {"action": action, "pointer": _pointer}
	_dispatch(contact, true)
	_dispatch(contact, false)

func _new_pointer() -> int:
	for candidate in 32:
		_pointer = (_pointer + 1) % 32
		if not _held.any(func(contact: Dictionary) -> bool:
			return int(contact["pointer"]) == _pointer):
			return _pointer
	push_error("The input fixture exhausted its independent pointer IDs.")
	return -1

func _dispatch(contact: Dictionary, pressed: bool) -> void:
	var action: StringName = contact["action"]
	if use_touch:
		var controls := game.get("_controls") as Control
		var order: Array = controls.get("_order")
		var action_index := [Options.BEAT_LEFT, Options.BEAT_RIGHT, Options.SHOUT,
			Options.SING_LOW, Options.SING_MID, Options.SING_HIGH, Options.FURY, Options.POWER].find(action)
		var pad: Rect2 = controls.get("pads")[order.find(action_index)]
		var event := InputEventScreenTouch.new()
		event.index = int(contact["pointer"])
		event.position = controls.get_global_transform_with_canvas() * pad.get_center()
		event.pressed = pressed
		if DisplayServer.get_name() == "headless":
			controls.get_viewport().push_input(event, true)
		else:
			event.position = controls.get_viewport().get_final_transform() * event.position
			Input.parse_input_event(event)
	else:
		var settings := game.get_tree().root.get_node("Settings")
		for binding in Options.CONTROL_BINDINGS:
			if binding["action"] != action:
				continue
			var event := InputEventKey.new()
			event.keycode = int(settings.call("binding_keycode", str(binding["key"])))
			event.physical_keycode = event.keycode
			event.pressed = pressed
			if DisplayServer.get_name() == "headless":
				game.get_viewport().push_input(event, true)
			else:
				Input.parse_input_event(event)
			break
	Input.flush_buffered_events()
