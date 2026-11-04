extends RefCounted

## The shared movie recorder sees only a Buttons performance, never a microphone.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Chart = preload("res://games/tifo_beato/chart/match_chart.gd")
const Driver = preload("res://games/tifo_beato/tests/flow_fixture.gd")
var _driver: Driver
var _failed := false

func configure(variant: String) -> bool:
	return variant == "solo"

func duration() -> float:
	return 64.0

func capture_inset() -> float:
	return 260.0

func steps() -> Array[Dictionary]:
	var chart := Chart.new(2026, 0)
	var call: Dictionary = chart.phases.filter(func(phase: Dictionary) -> bool:
		return str(phase["kind"]) == "call")[0]
	var response: Dictionary = chart.phases.filter(func(phase: Dictionary) -> bool:
		return str(phase["kind"]) == "response")[0]
	return [
		{"time": 0.0, "title": "One curva. One fence.",
			"body": "Find the guide drum. Buttons are a complete instrument; no microphone opens."},
		{"time": float(call["t"]) - 4.0, "title": "Read the shapes, then play",
			"body": "Square: F/J BEAT. Circle: Space SHOUT. A/S/D: your LOW/MID/HIGH rungs."},
		{"time": float(call["t"]) + 1.5, "title": "Hold a line. Respect the X.",
			"body": "HOLD needs steady coverage. X REST means release every sound input."},
		{"time": float(response["t"]) + 0.2, "title": "The curva answers your actual call",
			"body": "Breathe during RESPONSE. Misses and timing scatter really change what comes back."},
		{"time": 42.0, "title": "Perfects lift the whole stand",
			"body": "Combos build Fury; Q unleashes it once per half. The tifo samples your saved banner."},
		{"time": 56.0, "title": "Your performance earns the stars",
			"body": "Energy helps the toy team, but football is never certain. Career promotion needs stars."},
	]

func settings_overrides() -> Dictionary:
	return {Options.INPUT: 1, Options.LATENCY: 0.0, Options.QUIET: false,
		Options.SPEED: 100, Options.WINDOWS: 0, Options.ANY_SOUND: false,
		Options.NEVER_DIES: false, Options.STATIC_LANE: false, Options.RIVALS: 2,
		Options.COMMENTATOR: 0, "ui/scale": 1.0}

func configure_session(session: Node) -> void:
	session.call("configure_single_player")

func start(scene: Node) -> void:
	scene.get("_audio").set("manual_time", 0.0)
	scene.set("_pool", 0)
	scene.set("_request", {"mode": "quick", "ground": 1, "seed": 2026})
	scene.call("_start_round")
	scene.set_process(false)
	_driver = Driver.new(scene)

func update(scene: Node, time: float, _delta: float) -> void:
	if scene.get("_source").get("capture") != null:
		_failed = true
		push_error("Tutorial capture refuses an active microphone.")
		scene.get_tree().quit(1)
		return
	while float(scene.get("_audio").get("manual_time")) + 0.01 <= time + 0.000001:
		_driver.tick(1)

func validate_finished(scene: Node) -> bool:
	_driver.release_all()
	var state: RefCounted = scene.get("_state")
	return not _failed and state.get("judge").get("hits") >= 24 \
		and float(state.get("judge").call("accuracy")) >= 0.9 \
		and not (state.get("tifo").get("revealed") as Array).is_empty() \
		and scene.get("_source").get("capture") == null
