extends SceneTree

## Runtime loads keep the shell's autoload dependencies out of the compile pass.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Audio = preload("res://games/tifo_beato/audio/tifo_audio.gd")
var _failures := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_compile_owned("res://games/tifo_beato")
	if not _failures.is_empty():
		_finish()
		return
	var session := get_root().get_node("GameSession")
	var settings := get_root().get_node("Settings")
	var previous: Variant = settings.call("get_value", Options.INPUT)
	settings.call("set_value", Options.INPUT, 1)
	GameCatalog.select(Options.GAME_ID)
	session.call("configure_single_player")
	var manifest := GameCatalog.current()
	_expect(manifest != null and manifest.achievements.size() == 21,
		"The discovered game must register all 21 stable achievements.")
	var buses := AudioServer.bus_count
	var packed := load("res://games/tifo_beato/gameplay.tscn") as PackedScene
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	if not game.has_method("game_id") or game.get("_view") == null:
		_expect(false, "Gameplay must compile and build its actual world and UI.")
	else:
		_expect(str(game.get("_stage")) == "lobby" and not bool(game.get("_round_active")),
			"First entry must show the railway without starting a round.")
		var source: RefCounted = game.get("_source")
		_expect(source.get("capture") == null and AudioServer.bus_count == buses,
			"Neither construction nor the Buttons lobby may open a microphone bus.")
		await _test_preferences(game, settings, session)
		_test_response(game.get("_audio"))
		game.call("_show_card", "PASS THE MEGAPHONE", "Release the previous inputs.",
			0, "Ready", func() -> void: pass)
		game.set("_blocked_touches", {77: true})
		await process_frame
		var ready := game.get("_ready_button") as Button
		_expect(ready.disabled, "A card must wait for the old touch even outside a round.")
		var release := InputEventScreenTouch.new()
		release.index = 77
		release.pressed = false
		game.call("_input", release)
		await process_frame
		await process_frame
		_expect(not ready.disabled, "Releasing the old touch must unlock an inactive-round card.")
		game.set("_scores", [7, 3])
		game.call("_on_round_timer_timeout")
		var payload: Dictionary = game.call("_share_payload")
		_expect(str(payload["score"]) == "7" and not payload.has("tb_banner_snapshot"),
			"A forced incomplete finish preserves shell scores without inventing a snapshot.")
		game.call("_on_play_again_pressed")
		await process_frame
		_expect(bool(game.get("_round_active")) and not bool(game.get("_input_locked"))
			and int(game.get("_scores")[0]) == 0,
			"Replay must immediately start a clean, unlocked round after a stopped handoff.")
		_test_rival_audio(game)
		var controls := game.get("_controls") as Control
		game.get("_state").get("fury").call("offer_power", "tornado")
		game.call("_update_round", 0.0, 0.0)
		_expect(controls.accessibility_description.contains("Scarf Tornado")
			and (game.get("_match_hud") as Control).accessibility_description.contains("Scarf Tornado"),
			"Compact inventory labels must preserve the full power name for assistive reading.")
		_expect(not str(game.get("_match_hud").get("_metrics")[4]).contains("POWER"),
			"An inventory name cannot add wrapped rows to the Fury meter.")
		var finger := InputEventScreenTouch.new()
		finger.index = 3
		finger.position = controls.get_global_transform_with_canvas() \
			* (controls.get("pads")[0] as Rect2).get_center()
		finger.pressed = true
		get_root().push_input(finger, true)
		_expect((game.get("_physical_touches") as Dictionary).has(3),
			"A pad-handled touch must still reach the physical handoff ledger.")
		game.call("_show_card", "PASS THE MEGAPHONE", "Release the actual held finger.",
			0, "Ready", func() -> void: pass)
		await process_frame
		_expect((game.get("_ready_button") as Button).disabled,
			"Clearing virtual contacts cannot pretend the physical finger was released.")
		finger.pressed = false
		get_root().push_input(finger, true)
		await process_frame
		_expect(not (game.get("_ready_button") as Button).disabled,
			"A real touch release must unlock the card even after pads are disabled.")
	get_root().remove_child(game)
	game.free()
	await process_frame
	for path in ["character_preview", "store_preview", "gallery_stage", "share_art"]:
		var scene := load("res://games/tifo_beato/%s.tscn" % path) as PackedScene
		var stage := scene.instantiate() as Control
		stage.size = Vector2(720, 420)
		get_root().add_child(stage)
		await process_frame
		_expect(stage.get("model_root") != null,
			"%s must construct its original models, not a labelled placeholder." % path)
		get_root().remove_child(stage)
		stage.free()
		await process_frame
	_expect(AudioServer.bus_count == buses, "Leaving gameplay must not leak capture buses.")
	await _test_silent_soundcheck(buses)
	await _test_tools(buses)
	settings.call("set_value", Options.INPUT, previous)
	await create_timer(0.15, true, false, true).timeout
	_finish()

func _test_preferences(game: Node, settings: Node, session: Node) -> void:
	var previous_mode: Variant = settings.call("get_value", Options.MODE)
	var previous_hot_seat: Variant = settings.call("get_value", Options.HOT_SEAT)
	for mode in 4:
		settings.call("set_value", Options.MODE, mode)
		game.call("_show_lobby")
		await process_frame
		_expect(game.get("_lobby").get("tab") == [0, 1, 1, 2][mode],
			"Solo preferences must open the corresponding railway, Quick or workshop tab.")
	session.call("configure_multiplayer", 0)
	for mode in 3:
		settings.call("set_value", Options.HOT_SEAT, mode)
		game.call("_show_lobby")
		await process_frame
		var focus := game.get("_lobby").get("first_focus") as Button
		_expect(focus.text.begins_with(["Duel", "Two Capos", "Split the Stands"][mode]),
			"The saved hot-seat preference must be the actual initial keyboard/controller action.")
	session.call("configure_single_player")
	settings.call("set_value", Options.MODE, previous_mode)
	settings.call("set_value", Options.HOT_SEAT, previous_hot_seat)
	var store := get_root().get_node("Store")
	store.call("add_points", Options.GAME_ID, 100)
	_expect(store.call("purchase", Options.GAME_ID, "tb_fabric_tarp")
		and store.call("purchase", Options.GAME_ID, "tb_fabric_silk"),
		"Fabric fixtures must buy their real store items.")
	game.call("_fabric_selected", 1)
	var banner: RefCounted = game.get("_banner")
	_expect(banner.get("fabric") == 1
		and store.call("equipped_id", Options.GAME_ID, "tb_fabric") == "tb_fabric_tarp",
		"Workshop fabric and the equipped store fabric must remain one selection.")
	var tarp: Image = banner.call("render_image")
	_expect(store.call("equip", Options.GAME_ID, "tb_fabric_silk", "tb_fabric"),
		"The real Store signal must equip a purchased fabric.")
	_expect(banner.get("fabric") == 2 and tarp.get_data() != (banner.call("render_image") as Image).get_data(),
		"Store changes must update the actual banner image; silk cannot be a tarp alias.")
	game.call("_equipment_changed", Options.GAME_ID, "tb_fabric", "unknown-fabric")
	_expect(banner.get("fabric") == 2, "An invalid fabric id must keep the last valid design.")
	game.call("_show_lobby")
	await process_frame

func _test_rival_audio(game: Node) -> void:
	var previous: RefCounted = game.get("_state")
	var audio := game.get("_audio") as Node
	var state: RefCounted = (load("res://games/tifo_beato/match/match_state.gd") as Script).new(
		2026, 0, 0, {"walkin_seconds": 0.0, "half_seconds": 24.0, "rivals": 2})
	game.set("_state", state)
	game.set("_response_queue", {})
	var notes: Array = state.get("judge").get("notes")
	var note: Dictionary = notes[0]
	var at := float(note["t"])
	state.set("_stepped", at)
	state.set("time", at)
	audio.call("stop_voices")
	var cues: Array[Dictionary] = [{"kind": "air_horn", "beat": 0.6}]
	game.call("_update_match", at, cues)
	_expect((audio.get("_players") as Array).is_empty(),
		"A late rival cue arriving on a judged note must keep its caption without playing audio.")
	var response: Dictionary = state.get("chart").get("phases").filter(
		func(phase: Dictionary) -> bool: return phase["kind"] == "response")[0]
	at = float(response["end"]) - 2.0
	state.set("_stepped", at)
	state.set("time", at)
	audio.call("stop_voices")
	cues[0]["kind"] = "rival_drums"
	game.call("_update_match", at, cues)
	var players: Array = audio.get("_players")
	_expect(not players.is_empty(), "A safe response tail must really play the original rival pattern.")
	if not players.is_empty():
		var stream := (players[-1] as AudioStreamPlayer).stream as AudioStreamWAV
		var duration := float(stream.data.size()) / (2.0 * Audio.RATE)
		_expect(duration > 0.5 and duration <= 1.251,
			"Long rival patterns must end before the next protected call window.")
	audio.call("stop_voices")
	game.set("_state", previous)
	game.set("_response_queue", {})

func _test_response(audio: Node) -> void:
	var call: Array[Dictionary] = [{"grade": 0, "kind": "sing", "band": 1,
		"note": {"t": -0.08, "band": 0}, "error": 0.0}]
	audio.call("response", call, 0.0, 0.7, 0.0)
	var players: Array = audio.get("_players")
	var stream := (players[-1] as AudioStreamPlayer).stream as AudioStreamWAV
	var accepted := Audio.voice_samples(1)
	var intact := true
	for sample in 256:
		var actual := float(stream.data.decode_s16(sample * 2)) / 32767.0
		intact = intact and absf(actual - accepted[sample] * 0.78) < 0.0001
	_expect(intact, "A slightly early response must retain the whole accepted HIGH vowel, not target MID.")
	audio.call("stop_voices")
	call[0]["note"]["t"] = 2.0
	audio.call("response", call, 0.0, 0.7, 0.0)
	players = audio.get("_players")
	stream = (players[-1] as AudioStreamPlayer).stream as AudioStreamWAV
	var peak := 0
	for sample in range(roundi(Audio.RATE * 0.2), roundi(Audio.RATE * 0.45)):
		peak = maxi(peak, absi(stream.data.decode_s16(sample * 2)))
	_expect(peak > 1000, "The final accepted call must be audible even inside a short response buffer.")
	audio.call("stop_voices")

func _test_tools(buses: int) -> void:
	for name in ["sound_spike", "chart_preview"]:
		var packed := load("res://games/tifo_beato/tools/%s.tscn" % name) as PackedScene
		var tool := packed.instantiate()
		get_root().add_child(tool)
		await process_frame
		if name == "chart_preview":
			for chant in 24:
				tool.call("_select", chant)
				_expect(tool.get("_model").get("judge").get("attempts") == 0,
					"Inspecting original charts must never pretend to score a performance.")
		else:
			(tool.get("_audio") as Node).set("manual_time", 0.0)
			tool.call("_start")
			(tool.get("_audio") as Node).set("manual_time", 0.2)
			var event := InputEventKey.new()
			event.physical_keycode = KEY_F
			event.pressed = true
			get_root().push_input(event, true)
			(tool.get("_audio") as Node).set("manual_time", 0.3)
			tool.call("_process", 0.0)
			_expect(int(tool.get("_counts").get("onset", 0)) == 1,
				"Numeric diagnostics must report a genuinely routed button onset.")
			event.pressed = false
			get_root().push_input(event, true)
			tool.call("_stop")
		_expect(AudioServer.bus_count == buses, "Developer previews and Buttons diagnostics open no mic bus.")
		get_root().remove_child(tool)
		tool.free()
		await process_frame

func _test_silent_soundcheck(buses: int) -> void:
	for level in [0.0, 0.001]:
		var check: Control = (load("res://games/tifo_beato/ui/soundcheck.gd") as Script).new()
		get_root().add_child(check)
		await process_frame
		var source: RefCounted = check.get("_source")
		source.set("kind", 0)
		var mic: RefCounted = source.get("mic")
		mic.set("sample_rate", 8000.0)
		var samples := PackedFloat32Array()
		samples.resize(17600)
		samples.fill(level)
		source.get("_microphone_frames").append_array(mic.call("push_samples", samples))
		check.set("_started", true)
		check.get("_audio").set("manual_time", 2.2)
		check.call("_process", 0.0)
		_expect(bool(check.get("_failed")) == (level == 0.0),
			"Only exact digital silence, not a quiet room, must fail the room measurement.")
		_expect((check.get("_next") as Button).disabled == (level == 0.0),
			"Digital silence cannot offer a successful calibration step.")
		if level == 0.0:
			_expect((check.get("_status") as Label).text.contains("Digital silence")
				and not bool(check.get("profile").get("calibrated")),
				"Denied or muted sample streams need an explicit error, never a saved profile.")
		_expect(source.get("capture") == null and AudioServer.bus_count == buses,
			"The PCM regression must not open microphone hardware or leak a bus.")
		get_root().remove_child(check)
		check.free()
		await process_frame

func _compile_owned(path: String) -> void:
	var directory := DirAccess.open(path)
	for file in directory.get_files():
		if file.ends_with(".gd") and file != "scene_test.gd":
			var script := load(path.path_join(file)) as Script
			_expect(script != null and script.can_instantiate(),
				"Owned script must compile: " + path.path_join(file))
	for child in directory.get_directories():
		if not child.begins_with(".") and child != "tests":
			_compile_owned(path.path_join(child))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("Tifo Beato scene tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
