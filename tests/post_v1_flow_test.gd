extends SceneTree

## All expanded activities are driven by dispatched keys/touches, not assigned scores.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Driver = preload("res://games/tifo_beato/tests/flow_fixture.gd")
const Creator = preload("res://games/tifo_beato/chart/chant_creator.gd")
const Daily = preload("res://games/tifo_beato/career/daily_derby.gd")
const Moments = preload("res://games/tifo_beato/match/best_moments.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
var _failures := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameCatalog.select(Options.GAME_ID)
	var settings := get_root().get_node("Settings")
	settings.call("set_value", Options.INPUT, 1)
	settings.call("set_value", Options.RIVALS, 2)
	settings.call("set_value", "accessibility/reduced_motion", true)
	var creator := Creator.new()
	creator.notes = [[0, 0, 0, 0, 0], [0, 4, 0, 0, 0],
		[2, 8, 4, 0, 1], [4, 12, 4, 0, 0],
		[3, 16, 8, 1, 1], [0, 26, 0, 0, 0], [4, 28, 4, 0, 0]]
	var scenarios: Array[Dictionary] = [
		{"mode": "away_bus", "ground": 0, "tempo": 180, "touch": true, "latency": 400.0},
		{"mode": "away_station", "ground": 0, "latency": 400.0},
		{"mode": "away_hostile", "ground": 2, "pitch_shift": 1},
		{"mode": "derby_ritual", "ground": 3, "ritual": "mural", "touch": true},
		{"mode": "derby_ritual", "ground": 3, "ritual": "rehearsal"},
		{"mode": "derby_ritual", "ground": 3, "ritual": "pub"},
		{"mode": "derby_ritual", "ground": 3, "ritual": "bakery", "touch": true},
		{"mode": "derby_ritual", "ground": 3, "ritual": "barber"},
		{"mode": "creator_record", "ground": 0},
		{"mode": "creator_practice", "ground": 0, "chant": creator.payload(), "touch": true},
		{"mode": "creator_challenge", "ground": 0, "chant": creator.payload()},
		{"mode": "career", "ground": 0, "stop": 1, "prepared": true,
			"travel": "station", "travel_chosen": true},
		{"mode": "career", "ground": 3, "stop": 3, "prepared": true, "travel_chosen": true},
		{"mode": "daily", "touch": true, "latency": -100.0},
	]
	var session := get_root().get_node("GameSession")
	var store := get_root().get_node("Store")
	for request in scenarios:
		if str(request["mode"]) == "creator_challenge":
			session.call("configure_multiplayer", 0)
		else:
			session.call("configure_single_player")
		var game := (load("res://games/tifo_beato/gameplay.tscn") as PackedScene).instantiate()
		get_root().add_child(game)
		await process_frame
		await process_frame
		var records: RefCounted = game.get("_records")
		var stars: Dictionary = records.get("data")["stars"].duplicate(true)
		var banner: Dictionary = game.get("_banner").call("to_data")
		var wallet := int(store.call("points", Options.GAME_ID))
		game.get("_audio").set("manual_time", 0.0)
		game.get("_creator").set("tempo", 120)
		for seat in 2:
			game.get("_button_profiles")[seat].set("latency_ms",
				float(request.get("latency", 400.0 if seat == 0 else -100.0)))
		request["seed"] = 2026
		game.set("_request", request)
		game.call("_start_round")
		game.set_process(false)
		await process_frame
		if request["mode"] == "daily":
			var daily := Daily.challenge(Daily.today())
			_expect(int(game.get("_ground")) == int(daily["ground"]) \
				and int(game.get("_pool")) == int(daily["pool"]) \
				and int(game.get("_seed")) == int(daily["seed"]),
				"Daily must override selected/unlocked ground, group and seed.")
		if request["mode"] == "career" and int(request["ground"]) == 3:
			_expect(float(game.get("_state").get("life").get("morale")) > 100.0 \
				and float(game.get("_match_configuration")["crowd_scale"]) > 1.0,
				"Actual derby kickoff consumes earned ritual preparation.")
		var driver := Driver.new(game, bool(request.get("touch", false)))
		driver.pitch_shift = int(request.get("pitch_shift", 0))
		var ticks := 0
		var handoffs := 0
		while bool(game.get("_round_active")) and ticks < 130000:
			if bool(game.get("_input_locked")):
				driver.release_all()
				game.call("_process", 0.0)
				var ready := game.get("_ready_button") as Button
				_expect(ready != null and not ready.disabled, "Real release unlocks expanded-mode handoffs.")
				if ready == null:
					break
				ready.pressed.emit()
				handoffs += 1
				await process_frame
			driver.tick(4)
			ticks += 1
			if ticks % 400 == 0:
				await process_frame
		driver.release_all()
		_expect(bool(game.get("_set_complete")), "Genuine events must complete %s / %s; stage %s, ticks %d."
			% [request["mode"], request.get("ritual", ""), game.get("_stage"), ticks])
		var after := int(store.call("points", Options.GAME_ID))
		var ranked: bool = str(request["mode"]) in ["career", "daily"]
		_expect(after > wallet and after - wallet <= 120 if ranked else after == wallet,
			"Only completed ranked matches pay one bounded reward.")
		if request["mode"] != "career":
			_expect(records.get("data")["stars"] == stars, "Expanded side activities cannot advance career.")
		_expect(game.get("_source").get("capture") == null, "Buttons and completed modes open no microphone.")
		var states: Array = game.get("_completed_states")
		for state: RefCounted in states:
			print("Expanded judge %s: %d/%d, accuracy %.3f, deaths %d" % [
				request["mode"], state.get("judge").get("hits"), state.get("judge").get("attempts"),
				state.get("judge").call("accuracy"), state.get("life").get("deaths")])
			if float(state.get("judge").call("accuracy")) <= 0.94:
				var shown := 0
				for result: Dictionary in game.get("_all_results"):
					if int(result["grade"]) == 3 and shown < 8:
						print("Expanded missed: %s" % result)
						shown += 1
			_expect(float(state.get("judge").call("accuracy")) > 0.94 \
				and int(state.get("judge").get("hits")) > 0,
				"%s must be genuinely judged with calibrated event input." % request["mode"])
		if request["mode"] == "creator_record":
			_expect(game.get("_creator").get("notes").size() >= 6 \
				and Creator.validate(game.get("_creator").call("payload")).is_empty(),
				"Actual recording records classified keys into an editable, valid draft.")
			await _test_editor(game)
		if request["mode"] == "creator_challenge":
			_expect(handoffs == 1 and states.size() == 2 \
				and int(game.get("_scores")[0]) == int(game.get("_scores")[1]),
				"Both Creator challengers play the identical saved chart with independent trims.")
		if request["mode"] == "derby_ritual":
			_expect(float(records.get("data")["derby"][request["ritual"]]) > 90.0,
				"Ritual quality comes from actual judged play.")
			_expect(game.get("_banner").call("to_data") == banner,
				"Painting a community mural must not overwrite the match banner.")
		if request["mode"] == "daily":
			var date := str(game.get("_request")["date"])
			_expect(records.get("data")["daily"].has(date) \
				and int(records.get("data")["daily"][date]["streak"]) == 1,
				"A completed Daily records its frozen local date once.")
			_expect(not (game.get("_war_results") as Array).is_empty(),
				"The daily's seeded rival must actually perform a halftime sing-off.")
			await _test_replay(game)
			_expect(int(game.get("_ground")) == int(game.get("_selected_ground")) \
				and int(game.get("_pool")) == int(game.get("_selected_pool")),
				"Daily unlock bypass must not leak into the normal lobby.")
		_expect(Moments.valid(records.get("data")["moments"]),
			"Completed genuine play stores only bounded, valid Best Moments.")
		var frozen: Dictionary = game.call("_share_payload")
		game.call("_end_round")
		game.call("_finish_round")
		_expect(int(store.call("points", Options.GAME_ID)) == after \
			and game.call("_share_payload") == frozen,
			"Expanded modes keep settlement idempotent and share data frozen.")
		print("Expanded %s/%s: %s, %d ticks, %d handoffs, %d Tokens" % [
			request["mode"], request.get("ritual", ""), game.get("_scores"),
			ticks, handoffs, after - wallet])
		get_root().remove_child(game)
		game.free()
		await process_frame
	await create_timer(0.2, true, false, true).timeout
	if _failures.is_empty():
		print("Tifo Beato post-v1 genuine-input flow tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _test_editor(game: Node) -> void:
	await process_frame
	var lobby := game.get("_lobby") as Control
	var editor := lobby.get("editor") as Control
	_expect(editor != null, "Recording returns to the real Creator workbench.")
	if editor == null:
		return
	editor.call("_save")
	_expect(game.get("_records").get("data")["chants"].has("0"),
		"The workbench's Save action writes the recorded draft.")
	var old: Dictionary = game.get("_creator").call("payload")
	var code := editor.get("_code") as TextEdit
	code.text = "TB1.invalid"
	editor.call("_import")
	_expect(game.get("_creator").call("payload") == old,
		"Invalid imported code leaves the live draft intact and reports an error.")
	var imported := Creator.new()
	imported.notes = [[0, 0, 0, 0, 0], [4, 8, 4, 0, 0]]
	imported.lyric = 3
	code.text = imported.code()
	editor.call("_import")
	await process_frame
	_expect(game.get("_creator").call("payload") == imported.payload(),
		"Valid offline code actually refreshes the editable workbench.")

func _test_replay(game: Node) -> void:
	var records: RefCounted = game.get("_records")
	var clips: Array = records.get("data")["moments"]
	_expect(not clips.is_empty(), "Full genuine matches must produce replayable moments.")
	if clips.is_empty():
		return
	var before: Dictionary = records.get("data").duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(Records.SAVE_PATH)
	var wallet := int(get_root().get_node("Store").call("points", Options.GAME_ID))
	game.call("_show_replay", 0)
	await process_frame
	_expect(str(game.get("_stage")) == "replay" and not bool(game.get("_round_active")),
		"Best Moments is a read-only viewer, not a new shell round.")
	var seek := game.get("_replay_seek") as HSlider
	for at in [seek.max_value, seek.min_value, (seek.max_value + seek.min_value) * 0.5]:
		seek.value = at
		game.call("_process", 0.1)
		game.call("_process", 0.0)
	_expect(game.get("_source").get("capture") == null \
		and records.get("data") == before \
		and FileAccess.get_file_as_bytes(Records.SAVE_PATH) == bytes \
		and int(get_root().get_node("Store").call("points", Options.GAME_ID)) == wallet,
		"Playing/seeking a replay writes no data, opens no mic and pays no Tokens.")
	game.call("_show_lobby", 8)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
