extends SceneTree

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Driver = preload("res://games/tifo_beato/tests/flow_fixture.gd")
var _failures := PackedStringArray()
var _calibrated_split := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameCatalog.select(Options.GAME_ID)
	var settings := get_root().get_node("Settings")
	settings.call("set_value", Options.INPUT, 1)
	settings.call("set_value", Options.RIVALS, 2)
	settings.call("set_value", "accessibility/reduced_motion", true)
	var session := get_root().get_node("GameSession")
	var scenarios: Array[Dictionary] = [
		{"mode": "quick", "ground": 0}, {"mode": "quick", "ground": 0, "touch": true, "batch": 1},
		{"mode": "workshop", "ground": 0, "touch": true}, {"mode": "flag", "ground": 0},
		{"mode": "coat", "ground": 0, "touch": true}, {"mode": "war", "ground": 0, "rival": 3},
		{"mode": "career", "ground": 0, "stop": 2, "prepared": true},
		{"mode": "duel", "ground": 0},
		{"mode": "two_capos", "ground": 4, "touch": true, "pool": 2, "latency": [400.0, -100.0]},
		{"mode": "split", "ground": 0},
	]
	var quick: Array[int] = []
	for request in scenarios:
		if str(request["mode"]) in ["duel", "two_capos", "split"]:
			session.call("configure_multiplayer", 0)
		else:
			session.call("configure_single_player")
		var packed := load("res://games/tifo_beato/gameplay.tscn") as PackedScene
		var game := packed.instantiate()
		get_root().add_child(game)
		await process_frame
		await process_frame
		var records: RefCounted = game.get("_records")
		var stars: Dictionary = records.get("data")["stars"].duplicate(true)
		var store := get_root().get_node("Store")
		var wallet := int(store.call("points", Options.GAME_ID))
		(game.get("_audio") as Node).set("manual_time", 0.0)
		request["seed"] = 2026
		if request.has("latency"):
			for seat in 2:
				game.get("_button_profiles")[seat].set("latency_ms", request["latency"][seat])
		if request.has("pool"):
			game.set("_pool", int(request["pool"]))
		game.set("_request", request)
		game.call("_start_round")
		game.set_process(false)
		await process_frame
		var driver := Driver.new(game, bool(request.get("touch", false)))
		var ticks := 0
		var handoffs := 0
		while bool(game.get("_round_active")) and ticks < 125000:
			if bool(game.get("_input_locked")):
				driver.release_all()
				game.call("_process", 0.0)
				if str(request["mode"]) == "split" and int(game.get("_card_seat")) == 1 \
					and not _calibrated_split:
					_expect(int(store.call("points", Options.GAME_ID)) == wallet,
						"Split must not pay or end the shell round after P1.")
					_calibrated_split = true
					await _calibrate_pending_split(game)
				var ready := game.get("_ready_button") as Button
				_expect(ready != null and not ready.disabled, "Released handoff must be confirmable.")
				if ready == null:
					break
				ready.pressed.emit()
				handoffs += 1
				await process_frame
			driver.tick(int(request.get("batch", 4)))
			ticks += 1
			if ticks % 500 == 0:
				await process_frame
		driver.release_all()
		_expect(bool(game.get("_set_complete")), "Real events must finish %s; stage=%s, ticks=%d." % [
			request["mode"], game.get("_stage"), ticks])
		var states: Array = game.get("_completed_states")
		for state: RefCounted in states:
			_expect(int(state.call("stars")) >= 3 and state.get("judge").get("hits") > 0,
				"%s must finish with genuine judged keyboard/touch hits." % request["mode"])
			if request.has("latency"):
				if float(state.get("judge").call("accuracy")) <= 0.95:
					print("Late-seat diagnostic: accuracy=%s deaths=%s" % [
						state.get("judge").call("accuracy"), state.get("life").get("deaths")])
					var missed := 0
					for result: Dictionary in game.get("_all_results"):
						if int(result["grade"]) == 3 and missed < 20:
							print("Late miss: %s" % result)
							missed += 1
				_expect(float(state.get("judge").call("accuracy")) > 0.95,
					"Maximum positive/negative seat timing cannot drop correct attacks or Holds.")
				_expect(not (state.get("_goal_counts") as Dictionary).is_empty(),
					"Two Capos must actually author and score optional goals through its handoffs.")
		if str(request["mode"]) == "quick":
			quick.append(int(game.get("_scores")[0]))
		if str(request["mode"]) != "career":
			_expect(records.get("data")["stars"] == stars, "Only Career may advance career stars.")
		elif not states.is_empty():
			_expect(int(game.get("_career").call("best_stars", 0, 2)) >= 3 \
				and (game.get("_war_results") as Array).size() == 1,
				"Career's last stop must really run its steward check and halftime war.")
		if str(request["mode"]) in ["duel", "two_capos", "split"]:
			_expect(handoffs > 0, "A full hot-seat set must contain actual named handoffs.")
		if str(request["mode"]) == "split":
			_expect(states.size() == 2 and int(game.get("_scores")[0]) == int(game.get("_scores")[1]),
				"Both Split seats must finish the identical seed, including measured P2 timing.")
		var after := int(store.call("points", Options.GAME_ID))
		if str(request["mode"]) in ["workshop", "flag", "coat"]:
			_expect(after == wallet, "Build and steward practice must pay no Tokens.")
		else:
			_expect(after > wallet and after - wallet <= 120, "One bounded payout follows the whole set.")
		var frozen: Dictionary = game.call("_share_payload")
		game.get("_banner").set("text", 3)
		game.call("_end_round")
		game.call("_finish_round")
		_expect(int(store.call("points", Options.GAME_ID)) == after, "Repeated finish cannot double-bank.")
		_expect(game.call("_share_payload") == frozen, "Finished share snapshots must not read later edits.")
		print("%s: %s, %d handoffs, %d Tokens" % [
			request["mode"], game.get("_scores"), handoffs, after - wallet])
		get_root().remove_child(game)
		game.free()
		await process_frame
	_expect(quick.size() == 2 and quick[0] == quick[1],
		"Keyboard and independent touch must give identical results under different render batching.")
	await create_timer(0.2, true, false, true).timeout
	if _failures.is_empty():
		print("Tifo Beato complete input-flow tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _calibrate_pending_split(game: Node) -> void:
	game.call("_open_soundcheck", 1)
	await process_frame
	var check := game.get("_soundcheck") as Control
	var audio := check.get("_audio") as Node
	audio.set("manual_time", 0.0)
	check.set_process(false)
	check.call("_advance_step")
	for pulse in range(2, 8):
		audio.set("manual_time", pulse * 0.6 + 0.06)
		var event := InputEventKey.new()
		event.keycode = int(check.get("bindings")[0])
		event.physical_keycode = event.keycode
		event.pressed = true
		get_root().push_input(event, true)
		check.call("_process", 0.0)
		audio.set("manual_time", pulse * 0.6 + 0.10)
		event.pressed = false
		get_root().push_input(event, true)
		check.call("_process", 0.0)
	audio.set("manual_time", 5.0)
	check.call("_process", 0.0)
	(check.get("_next") as Button).pressed.emit()
	await process_frame
	_expect(game.get("_soundcheck") == null and bool(game.get("_input_locked")),
		"A measured soundcheck must preserve the pending Split action, not resume P1.")
	_expect(absf(float(game.get("_button_profiles")[1].get("latency_ms")) - 60.0) < 12.0,
		"The fixture must save an actual measured six-tap timing profile.")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
