extends Node

## A separate validation export drives real events, never authored grades.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
var fixture_path := "res://games/tifo_beato/tests/flow_fixture.gd"
var use_touch := false
var latency := 0.0
var _failures := PackedStringArray()

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	print("TIFO_PLATFORM_START ", DisplayServer.get_name())
	if OS.has_feature("web"):
		use_touch = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('touch') === '1'"))
		latency = float(JavaScriptBridge.eval("Number(new URLSearchParams(location.search).get('latency') || 0)"))
	_check(GameCatalog.is_single_game_build() and GameCatalog.single_game_id() == Options.GAME_ID,
		"The export feature must really select only Tifo Beato.")
	_check(str(ProjectSettings.get_setting_with_override("application/config/name")) == "Tifo Beato"
		and str(ProjectSettings.get_setting_with_override("application/config/custom_user_dir_name")) \
		== "DeskCanSaw Games/Tifo Beato", "Standalone title and permanent save directory must apply.")
	for foreign in ["chicken_pit", "desk_can_saw", "dolces_adventure", "sailor_man"]:
		_check(not ResourceLoader.exists("res://games/%s/game.gd" % foreign), "Foreign game shipped: " + foreign)
	if not OS.has_feature("tifo_validation"):
		_check(not ResourceLoader.exists("res://games/tifo_beato/tools/sound_spike.tscn")
			and not ResourceLoader.exists("res://games/tifo_beato/tests/platform_test.tscn"),
			"Release packs must exclude developer tools and fixtures.")
	var tree := get_tree()
	var settings := tree.root.get_node("Settings")
	settings.call("set_value", Options.INPUT, 1)
	settings.call("set_value", "accessibility/reduced_motion", true)
	tree.root.get_node("GameSession").call("configure_single_player")
	var packed := load("res://games/tifo_beato/gameplay.tscn") as PackedScene
	var game := packed.instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	var buses := AudioServer.bus_count
	var wallet := int(tree.root.get_node("Store").call("points", Options.GAME_ID))
	game.get("_button_profiles")[0].set("latency_ms", latency)
	game.get("_audio").set("manual_time", 0.0)
	game.set("_request", {"mode": "quick", "ground": 4, "seed": 2026})
	game.call("_start_round")
	game.set_process(false)
	await tree.process_frame
	var script := load(fixture_path) as Script
	if script == null or not script.can_instantiate():
		_check(false, "The explicit real-event validation driver is missing.")
		_report({})
		return
	var driver: RefCounted = script.new(game, use_touch)
	var ticks := 0
	while bool(game.get("_round_active")) and ticks < 75000:
		driver.call("tick", 4)
		ticks += 1
		if ticks % 100 == 0:
			await tree.process_frame
	driver.call("release_all")
	var state: RefCounted = game.get("_state")
	var accuracy := float(state.get("judge").call("accuracy"))
	_check(bool(game.get("_set_complete")) and int(state.call("stars")) >= 3 and accuracy > 0.95,
		"The actual exported engine must complete an accurately played full match.")
	_check(game.get("_source").get("capture") == null and AudioServer.bus_count == buses,
		"Exported Buttons gameplay cannot open or leak microphone capture.")
	var paid := int(tree.root.get_node("Store").call("points", Options.GAME_ID)) - wallet
	_check(paid > 0 and paid <= 120, "Exported complete matches must pay one bounded purse.")
	var report := {"noise": state.call("noise"), "stars": state.call("stars"),
		"accuracy": accuracy, "hits": state.get("judge").get("hits"),
		"touch": use_touch, "latency_ms": latency, "tokens": paid, "ticks": ticks}
	tree.root.remove_child(game)
	game.free()
	await tree.process_frame
	report["tutorial"] = await _test_tutorial(settings)
	if OS.has_feature("web"):
		report["microphone_denial"] = await _test_denied_microphone()
	_report(report)

func _test_tutorial(settings: Node) -> bool:
	settings.call("set_value", "accessibility/reduced_motion", false)
	var guide := (load("res://scenes/menus/instructions.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(guide)
	await get_tree().process_frame
	var video := guide.get("_video") as VideoStreamPlayer
	video.play()
	await get_tree().create_timer(0.8).timeout
	var decoded := bool(guide.get("_video_ready")) and video.stream_position > 0.05 \
		and video.get_video_texture() != null and video.get_video_texture().get_width() == 960
	_check(decoded, "The actual exported Instructions screen must decode its real tutorial.")
	get_tree().root.remove_child(guide)
	guide.free()
	await get_tree().process_frame
	return decoded

func _test_denied_microphone() -> bool:
	if not bool(JavaScriptBridge.eval("window.tifoMicrophoneBlocked === true")):
		_check(false, "Microphone validation requires the browser harness's deny-only stub.")
		return false
	var buses := AudioServer.bus_count
	var check := (load("res://games/tifo_beato/ui/soundcheck.gd") as Script).new() as Control
	get_tree().root.add_child(check)
	await get_tree().process_frame
	_check(check.get("_source").get("capture") == null,
		"Merely opening soundcheck cannot request microphone access.")
	(check.get("_next") as Button).grab_focus()
	_press_enter()
	_check(bool(check.get("_started")), "The routed Start action must begin soundcheck.")
	await get_tree().create_timer(10.8).timeout
	var capture: Node = check.get("_source").get("capture")
	print("TIFO_MIC_DENIAL ", JSON.stringify({
		"started": check.get("_started"), "failed": check.get("_failed"),
		"capturing": capture != null, "buses": AudioServer.bus_count, "before": buses,
		"elapsed": capture.get("_elapsed") if capture != null else -1.0,
		"requests": JavaScriptBridge.eval("window.tifoMediaRequests || 0"),
	}))
	var failed := bool(check.get("_failed")) and check.get("_source").get("capture") == null \
		and AudioServer.bus_count == buses
	_check(failed and float(JavaScriptBridge.eval("window.tifoMediaRequests || 0")) > 0.0,
		"Denied browser capture must show an explicit failure and synchronously close its bus.")
	var choice := {"buttons": false}
	check.connect("cancelled", func(buttons: bool) -> void: choice["buttons"] = buttons)
	(check.get("_actions").get_child(2) as Button).grab_focus()
	_press_enter()
	_check(bool(choice["buttons"]), "The actual Use Buttons action must remain usable after denial.")
	get_tree().root.remove_child(check)
	check.free()
	await get_tree().process_frame
	return failed and bool(choice["buttons"])

func _press_enter() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _report(result: Dictionary) -> void:
	result["passed"] = _failures.is_empty()
	result["failures"] = _failures
	print("TIFO_PLATFORM_RESULT " + JSON.stringify(result))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tifoValidationResult = " + JSON.stringify(result))
	else:
		get_tree().quit(0 if _failures.is_empty() else 1)
