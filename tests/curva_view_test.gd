extends SceneTree

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Driver = preload("res://games/tifo_beato/tests/flow_fixture.gd")
const Stage = preload("res://games/tifo_beato/presentation/stage.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Build = preload("res://games/tifo_beato/workshop/build_race.gd")
const Steward = preload("res://games/tifo_beato/steward/steward_state.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Daily = preload("res://games/tifo_beato/career/daily_derby.gd")
var _failures := PackedStringArray()
var _folder := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Tifo Beato's curva suite requires a real Compatibility graphics window.")
		quit(1)
		return
	_folder = ProjectSettings.globalize_path("user://tifo_beato_render_checks").replace("/", "\\")
	_expect(DirAccess.make_dir_recursive_absolute(_folder) == OK, "Create scoped render artifacts.")
	var settings := get_root().get_node("Settings")
	settings.call("set_value", Options.INPUT, 1)
	settings.call("set_value", "accessibility/reduced_motion", true)
	GameCatalog.select(Options.GAME_ID)
	get_root().get_node("GameSession").call("configure_single_player")
	var scene := load("res://games/tifo_beato/gameplay.tscn") as PackedScene
	var game := scene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set("_request", {"mode": "quick", "ground": 4, "seed": 2026})
	game.call("_start_round")
	game.set_process(false)
	var state: RefCounted = game.get("_state")
	state.get("crowd").set("energy", 90.0)
	state.get("tifo").set("tier", 5)
	state.get("tifo").set("reveal_left", 8.0)
	var view := game.get("_view") as Control
	(view.get("tifo") as Node3D).call("present", 5, 8.0, 0.0, false, false)
	var hud := game.get("_match_hud") as Control
	hud.set("caption", "RIVAL TEMPO: follow your own guide. Every shape and every word remains readable.")
	get_root().min_size = Vector2i.ZERO
	for dimensions in [Vector2i(360, 640), Vector2i(640, 360), Vector2i(1280, 720),
		Vector2i(820, 1180), Vector2i(1920, 800)]:
		for scale_value in [1.0, 1.5]:
			get_root().size = dimensions
			settings.call("set_value", "ui/scale", scale_value)
			await process_frame
			await process_frame
			game.call("_resize_layout")
			hud.call("present")
			view.call("present")
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(get_root().size == dimensions, "The requested physical viewport must really be tested.")
			var controls := game.get("_controls") as Control
			var screen_transform := controls.get_screen_transform()
			for pad: Rect2 in controls.get("pads"):
				var physical := pad.size * Vector2(screen_transform.x.length(), screen_transform.y.length())
				_expect(physical.x >= 43.9 and physical.y >= 43.9,
					"Every independent pad must be at least 44 physical pixels: %s at %.1f." % [
						dimensions, scale_value])
			var lane: Rect2 = hud.call("lane_bounds")
			_expect(lane.end.y <= controls.global_position.y,
				"The rhythm lane must never overlap a held touch pad.")
			_expect(view.size.y * view.get_screen_transform().y.length() >= 40.0,
				"The live curva needs visible physical space at %s / %.1f." % [dimensions, scale_value])
			var camera := view.get("camera") as Camera3D
			var capo := view.get("capo") as Node3D
			var viewport := view.get("world_viewport") as SubViewport
			var head := camera.unproject_position(capo.global_position + Vector3(0, 3.4, 0))
			_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(head),
				"The actual capo's head must be in the rendered shot.")
			var image := viewport.get_texture().get_image()
			_expect(not image.is_empty(), "The real GPU must return a rendered stadium, not a placeholder.")
			var draw_calls := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,
				Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) + viewport.get_render_info(
					Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			_expect(draw_calls < 90, "Final draw-call budget includes visible and shadow passes: %d." % draw_calls)
			var name := "%dx%d_scale_%s.png" % [dimensions.x, dimensions.y, str(scale_value).replace(".", "_")]
			_expect(get_root().get_texture().get_image().save_png(_folder.path_join(name)) == OK,
				"Save the actual HUD and world screenshot.")
			print("%s / %.1f: world %s, %d draw calls" % [dimensions, scale_value, view.size, draw_calls])
			(game.get_node("%HudHelpButton") as Button).pressed.emit()
			for frame in 4:
				await process_frame
			hud.call("present")
			await process_frame
			await RenderingServer.frame_post_draw
			var heights: Vector2 = hud.call("layout_heights")
			lane = hud.call("lane_bounds")
			_expect(hud.global_position.y + heights.x <= lane.position.y
				and lane.end.y <= controls.global_position.y
				and get_root().get_visible_rect().encloses(controls.get_global_rect()),
				"Expanded Help must keep header, rhythm lane and pads separate at %s / %.1f." % [
					dimensions, scale_value])
			_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
				"help_" + name)) == OK, "Save the actual expanded controls.")
			(game.get_node("%HudHelpButton") as Button).pressed.emit()
	var tifo: Node3D = view.get("tifo")
	tifo.call("present", 0, 0.0, 0.0, false, false)
	tifo.call("present", 5, 8.0, 1.0, true, false)
	tifo.call("present", 5, 8.0, 1.2, true, false)
	_expect(float(tifo.get("_opacity")) > 0.1 and float(tifo.get("_opacity")) < 0.9,
		"Reduced-motion tifos must really cross-fade rather than pop.")
	tifo.call("present", 5, 8.0, 1.6, true, false)
	_expect(is_equal_approx(float(tifo.get("_opacity")), 1.0), "The cross-fade must finish.")
	await _test_real_input(game, settings)
	state = game.get("_state")
	var clips: Array = state.get("moments").call("finish", {"run": "render_checks",
		"seed": game.get("_seed"), "ground": game.get("_ground"), "pool": game.get("_pool"),
		"banner": game.get("_state").get("banner").call("to_data"),
		"outfit": view.get("outfit")})
	_expect(not clips.is_empty(), "Real rendered inputs must produce a replayable Best Moment.")
	await _test_cast_and_cameras(game, settings)
	get_root().remove_child(game)
	game.free()
	await process_frame
	await _test_expanded_workbench(settings, clips)
	await _test_advertised_models()
	await _test_intro(settings)
	print("Render artifacts: " + _folder)
	if _failures.is_empty():
		print("Tifo Beato Compatibility window tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _expect(condition: bool, text: String) -> void:
	if not condition:
		_failures.append(text)

func _test_intro(settings: Node) -> void:
	for dimensions in [Vector2i(360, 640), Vector2i(640, 360), Vector2i(1280, 720)]:
		for scale_value in [1.0, 1.5]:
			get_root().size = dimensions
			settings.call("set_value", "ui/scale", scale_value)
			await process_frame
			var intro := (load("res://games/tifo_beato/intro.tscn") as PackedScene).instantiate()
			get_root().add_child(intro)
			for card in 5:
				intro.set("_card", card)
				intro.call("_show_card")
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var screen: Rect2 = intro.get_viewport_rect()
				var copy := intro.get("_copy") as Control
				var image := intro.get("_image") as Control
				var actions := (intro.get("_next") as Control).get_parent() as Control
				_expect(screen.grow(0.5).encloses(copy.get_global_rect())
					and screen.grow(0.5).encloses(actions.get_global_rect()),
					"Every story card's complete copy and actions must fit at %s / %.1f / %d." % [
						dimensions, scale_value, card + 1])
				_expect(image.size.y * image.get_screen_transform().y.length() >= 40.0,
					"Story artwork needs visible space at %s / %.1f / %d." % [
						dimensions, scale_value, card + 1])
				for button: Control in actions.get_children():
					_expect(button.size.y * button.get_screen_transform().y.length() >= 43.9,
						"Story actions must retain their physical touch target.")
				_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
					"intro_%dx%d_scale_%s_card_%d.png" % [dimensions.x, dimensions.y,
						str(scale_value).replace(".", "_"), card + 1])) == OK,
					"Capture the actual story layout after text wrapping settles.")
			get_root().remove_child(intro)
			intro.free()
			await process_frame

func _test_expanded_workbench(settings: Node, clips: Array) -> void:
	var game := (load("res://games/tifo_beato/gameplay.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	game.get("_creator").call("put_note", [0, 0, 0, 0, 0])
	game.get("_records").get("data")["moments"] = clips.duplicate(true)
	game.get("_records").get("data")["daily"] = {
		"2026-01-19": {"noise": 1234567, "stars": 3, "combo": 456, "streak": 19}}
	for dimensions in [Vector2i(360, 640), Vector2i(640, 360), Vector2i(1280, 720)]:
		for scale_value in [1.0, 1.5]:
			get_root().size = dimensions
			settings.call("set_value", "ui/scale", scale_value)
			await process_frame
			await process_frame
			for tab in range(4, 9):
				game.call("_show_lobby", tab)
				await process_frame
				await process_frame
				var lobby := game.get("_lobby") as Control
				var scroll := lobby.get("_scroll") as ScrollContainer
				var content := lobby.get("_content") as Control
				var suffix := "%dx%d_scale_%s_tab_%d" % [dimensions.x, dimensions.y,
					str(scale_value).replace(".", "_"), tab]
				_expect(lobby.get_viewport_rect().grow(0.5).encloses(
					(lobby.get("_panel") as Control).get_global_rect()),
					"The complete expanded workbench panel must fit: " + suffix)
				_expect(content.size.x <= scroll.size.x + 0.5,
					"Expanded workbench content must wrap without horizontal clipping: " + suffix)
				for button: BaseButton in content.find_children("*", "BaseButton", true, false):
					if not button.is_visible_in_tree():
						continue
					_expect(button.size.y * button.get_screen_transform().y.length() >= 43.9,
						"Expanded workbench actions need physical touch targets: " + suffix)
				await RenderingServer.frame_post_draw
				_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
					"workbench_" + suffix + ".png")) == OK, "Capture every actual expanded page.")
				if tab == 6:
					lobby.set("player_count", 2)
					lobby.call("_select_tab", 6)
					await process_frame
					var editor := lobby.get("editor") as Control
					(editor.get("_code") as TextEdit).text = "TB1.invalid.00000000"
					editor.call("_import")
					var buttons := editor.find_children("*", "Button", true, false)
					var import_button := buttons[-1] as Button
					import_button.grab_focus()
					await process_frame
					await process_frame
					var visible_part := import_button.get_global_rect().intersection(
						scroll.get_global_rect())
					_expect(visible_part.size.y * import_button.get_screen_transform().y.length() >= 43.9,
						"The code import action must remain reachable by focus: " + suffix)
					await RenderingServer.frame_post_draw
					_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
						"creator_import_" + suffix + ".png")) == OK,
						"Capture the real code box and validation status.")
			if not clips.is_empty():
				var background: RefCounted = game.get("_view").get("state")
				game.call("_show_replay", 0)
				await process_frame
				await process_frame
				game.call("_resize_layout")
				var seek := game.get("_replay_seek") as HSlider
				seek.value = seek.max_value
				seek.value = seek.min_value
				game.call("_update_replay", 0.0)
				_expect(seek.size.y * seek.get_screen_transform().y.length() >= 43.9,
					"The actual seek slider needs a physical touch target at every UI scale.")
				var replay_view := game.get("_view") as Control
				var replay_state: RefCounted = game.get("_state")
				replay_state.get("chaos").set("active", "power_cut")
				replay_view.call("present")
				_expect((replay_view.get("_floodlight") as DirectionalLight3D).light_energy < 0.5,
					"Seeking must immediately reconstruct recorded power-cut lighting.")
				replay_state.get("chaos").set("active", "")
				replay_state.get("tifo").set("tier", 3)
				replay_state.get("tifo").set("reveal_left", 5.0)
				replay_view.call("present")
				_expect(is_equal_approx(
					(replay_view.get("_floodlight") as DirectionalLight3D).light_energy,
					float(replay_view.get_script().get_script_constant_map()["KEY_LIGHT_ENERGY"]))
					and is_equal_approx(float(replay_view.get("tifo").get("_opacity")), 1.0),
					"Backward seeking cannot inherit earlier lighting or tifo fades.")
				game.call("_update_replay", 0.0)
				var toolbar := game.get("_replay_toolbar") as Control
				var panel := game.get("_replay_panel") as Control
				_expect(panel.get_viewport_rect().grow(0.5).encloses(panel.get_global_rect())
					and toolbar.size.x <= panel.size.x + 0.5,
					"The seek and replay toolbar must wrap inside the viewport.")
				_expect(game.get("_source").get("capture") == null,
					"Actual rendered replay must never open microphone capture.")
				await RenderingServer.frame_post_draw
				_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
					"moment_%dx%d_scale_%s.png" % [dimensions.x, dimensions.y,
						str(scale_value).replace(".", "_")])) == OK,
					"Capture the actual seekable 3D replay, not a static placeholder.")
				game.call("_show_lobby", 8)
				await process_frame
				_expect(game.get("_state") == background
					and game.get("_view").get("state") == background,
					"Closing replay restores the original lobby's background model.")
	await _test_expanded_scenery(game, settings)
	get_root().remove_child(game)
	game.free()
	await process_frame

func _test_expanded_scenery(game: Node, settings: Node) -> void:
	var activities: Array[Dictionary] = [
		{"mode": "away_bus", "ground": 0, "tempo": 180},
		{"mode": "away_station", "ground": 0},
		{"mode": "derby_ritual", "ground": 3, "ritual": "mural"},
		{"mode": "derby_ritual", "ground": 3, "ritual": "pub"},
		{"mode": "derby_ritual", "ground": 3, "ritual": "bakery"},
		{"mode": "derby_ritual", "ground": 3, "ritual": "barber"},
	]
	for dimensions in [Vector2i(360, 640), Vector2i(640, 360), Vector2i(1280, 720)]:
		get_root().size = dimensions
		settings.call("set_value", "ui/scale", 1.5 if dimensions.x < 1000 else 1.0)
		await process_frame
		await process_frame
		for request in activities:
			game.get("_audio").set("manual_time", 0.0)
			game.set("_request", request)
			game.call("_start_round")
			game.set_process(false)
			await process_frame
			var driver := Driver.new(game, dimensions.x < 1000)
			for tick in 600:
				driver.tick(4)
				if tick % 100 == 0:
					await process_frame
			driver.release_all()
			await process_frame
			await RenderingServer.frame_post_draw
			var view := game.get("_view") as Control
			var viewport := view.get("world_viewport") as SubViewport
			var camera := view.get("camera") as Camera3D
			var travel := view.get("_travel") as Node3D
			var name := "%s_%s_%dx%d" % [request["mode"], request.get("ritual", ""),
				dimensions.x, dimensions.y]
			_expect(travel != null, "The selected activity must use its actual new scenery: " + name)
			_expect(game.get("_controls").get("pads").size() == 6,
				"Practice must not advertise unavailable Fury/power pads.")
			if travel == null:
				continue
			var screen := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(1)
			for node: VisualInstance3D in travel.find_children("*", "VisualInstance3D", true, false):
				_expect(_geometry_fits(node, camera, screen),
					"All original travel/ritual geometry and signs must fit: %s / %s" % [name, node.name])
			if request.get("ritual", "") == "mural":
				_expect(travel.get("_painted") > 1,
					"Genuine mural hits must reveal the actual banner texture.")
			if request["mode"] == "away_bus":
				travel.call("present", 0.13, 0.6, false)
				_expect(absf((travel.get("wipers")[0] as Node3D).rotation.z) > 0.1,
					"The original bus wipers must really follow the beat.")
				travel.call("present", 0.13, 0.6, true)
				_expect(is_zero_approx((travel.get("wipers")[0] as Node3D).rotation.z),
					"Reduced motion must freeze the decorative wipers.")
			_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
				"activity_" + name + ".png")) == OK, "Capture real new scenery and judged input.")

func _test_real_input(game: Node, settings: Node) -> void:
	var setups: Array[Dictionary] = [
		{"size": Vector2i(360, 640), "scale": 1.5, "touch": true, "ground": 0},
		{"size": Vector2i(640, 360), "scale": 1.5, "touch": true, "ground": 2},
		{"size": Vector2i(1280, 720), "scale": 1.0, "touch": false, "ground": 4},
	]
	for setup in setups:
		settings.call("set_value", Options.RIVALS, 0 if setup["ground"] == 4 else 2)
		get_root().size = setup["size"]
		settings.call("set_value", "ui/scale", setup["scale"])
		await process_frame
		await process_frame
		game.get("_audio").set("manual_time", 0.0)
		game.set("_request", {"mode": "quick", "ground": setup["ground"], "seed": 2026})
		game.call("_start_round")
		game.set_process(false)
		await process_frame
		var driver := Driver.new(game, bool(setup["touch"]))
		for tick in 6000:
			driver.tick(4)
			if tick % 100 == 0:
				await process_frame
		driver.release_all()
		var judge: RefCounted = game.get("_state").get("judge")
		_expect(int(judge.get("hits")) >= 24 and float(judge.call("accuracy")) > 0.95,
			"Native window input must really judge the chart at %s; hits=%s, accuracy=%s." % [
				setup["size"], judge.get("hits"), judge.call("accuracy")])
		_expect(game.get("_source").get("capture") == null, "Rendered Buttons play must open no mic.")
		await process_frame
		await RenderingServer.frame_post_draw
		var view := game.get("_view") as Control
		_expect(view.size.y * view.get_screen_transform().y.length() >= 40.0,
			"Actual grades, captions and inventory cannot squeeze the live world below 40 pixels.")
		var controls := game.get("_controls") as Control
		var lane: Rect2 = game.get("_match_hud").call("lane_bounds")
		_expect(lane.end.y <= controls.global_position.y,
			"The played rhythm lane must remain above all physical touch pads.")
		_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
			"actual_input_%dx%d.png" % [setup["size"].x, setup["size"].y])) == OK,
			"Save actual judged-input images, not only time-zero presentation fixtures.")
		print("Native input %s: %s genuine hits." % [setup["size"], judge.get("hits")])
	if not bool(game.call("hud_controls_expanded")):
		(game.get_node("%HudHelpButton") as Button).pressed.emit()
	game.call("_set_capture_inset", 260.0)
	await process_frame
	var controls := game.get("_controls") as Control
	_expect(controls.position.y + controls.size.y <= game.get_viewport().get_visible_rect().size.y - 260.0,
		"Tutorial captions need reserved space below the actual pads.")
	game.call("_set_capture_inset", 0.0)

func _test_cast_and_cameras(game: Node, settings: Node) -> void:
	get_root().size = Vector2i(1280, 720)
	settings.call("set_value", "ui/scale", 1.0)
	var view := game.get("_view") as Control
	var state: RefCounted = game.get("_state")
	settings.call("set_value", "accessibility/reduced_motion", false)
	view.call("configure_activity", state, "match")
	var response: Dictionary = state.get("chart").get("phases").filter(func(phase: Dictionary) -> bool:
		return phase["kind"] == "response")[0]
	state.get("tifo").set("tier", 5)
	state.get("tifo").set("reveal_left", 8.0)
	state.set("time", float(response["t"]) + 0.3)
	view.set("_phase", -1)
	view.call("present")
	_expect(view.get("_shot") == 2, "An actual response may cut to a ready tifo.")
	state.set("time", float(response["end"]) - 0.7)
	view.call("present")
	_expect(view.get("_shot") == 0, "The camera must return to the fence before the next call.")
	state.set("time", float(response["t"]) + 0.3)
	view.set("_phase", -1)
	view.call("set_reduced_motion", true)
	_expect(view.get("_shot") == 0, "Reduced motion must park even a pending tifo cut.")
	var modes: Array[Dictionary] = []
	for rival in 5:
		modes.append({"name": "rival_%d" % rival, "kind": "war", "model": War.new(2026, rival)})
	modes.append({"name": "two_humans", "kind": "war", "model": War.new(2026, 0, true)})
	modes.append({"name": "flag_steward", "kind": "steward", "model": Steward.new("flag")})
	modes.append({"name": "coat_steward", "kind": "steward", "model": Steward.new("coat")})
	modes.append({"name": "actual_workshop", "kind": "workshop", "model": Build.new(Banner.new(), 24, 2026)})
	for entry in modes:
		view.call("configure_activity", entry["model"], entry["kind"])
		view.call("present")
		await process_frame
		await RenderingServer.frame_post_draw
		var image := (view.get("world_viewport") as SubViewport).get_texture().get_image()
		_expect(image.save_png(_folder.path_join(str(entry["name"]) + ".png")) == OK,
			"Render the actual war/steward/workshop activity cast.")
		var camera := view.get("camera") as Camera3D
		for actor in [view.get("capo"), view.get("opponent")]:
			if actor != null:
				var head := camera.unproject_position((actor as Node3D).global_position + Vector3(0, 3.4, 0))
				_expect(Rect2(Vector2.ZERO, Vector2(image.get_size())).has_point(head),
					"Every current activity performer needs to stay in shot.")
		if str(entry["name"]) == "rival_4":
			var war: War = entry["model"]
			var turn := war.phases[1]
			for half in 2:
				war.advance(float(turn["call_t"]) + float(turn["beat"]) * (1.0 + half * 4.0))
				view.call("present")
				var rigs: Array = view.get("opponent").get("rigs")
				_expect(is_zero_approx((rigs[half].get_node("ToyCapoBody") as Node3D).rotation.z)
					and not is_zero_approx((rigs[1 - half].get_node("ToyCapoBody") as Node3D).rotation.z),
					"The Twins must really pass the lead halfway through their original call.")
	view.call("configure_activity", state, "match")
	for kind in ["seagull", "drum_skin", "power_cut", "beach_balls", "rain", "kazoo",
		"air_horn", "trumpet", "rival_drums", "inflatable"]:
		state.get("chaos").set("active", kind if kind in ["seagull", "drum_skin",
			"power_cut", "beach_balls", "rain", "kazoo"] else "")
		state.get("disruptions").set("active", kind)
		for tick in 20:
			state.set("time", float(state.get("time")) + 0.1)
			view.call("present")
		await process_frame
		await RenderingServer.frame_post_draw
		var viewport := view.get("world_viewport") as SubViewport
		_expect(viewport.get_texture().get_image().save_png(_folder.path_join(kind + ".png")) == OK,
			"Render every actual chaos and disruption prop.")
		if kind != "beach_balls":
			_expect((view.get("effects")[kind] as Node3D).visible, "The named live prop must be visible.")
		else:
			_expect((view.get("beach_balls")[7] as Node3D).visible, "Untapped balls must really obstruct.")
	settings.call("set_value", "accessibility/reduced_motion", true)
	state.get("fury").set("protection_left", 6.0)
	view.call("present")
	_expect((view.get("_tornado") as Node3D).visible,
		"Scarf Tornado must have a real visible original model, including with reduced effects.")
	_expect(is_zero_approx((view.get("_tornado") as Node3D).rotation.y),
		"Reduced motion must freeze the scarf tornado.")
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport := view.get("world_viewport") as SubViewport
	var draw_calls := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,
		Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) + viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_expect(draw_calls < 90, "The original tornado must stay within the final visible/shadow budget.")
	_expect(get_root().get_texture().get_image().save_png(_folder.path_join(
		"actual_scarf_tornado.png")) == OK, "Capture the original visible scarf tornado.")

func _test_advertised_models() -> void:
	var stage := Stage.new()
	stage.purpose = "capture"
	stage.size = Vector2(960, 540)
	get_root().add_child(stage)
	await process_frame
	var signatures: Dictionary = {}
	for exhibit in Options.GALLERY_EXHIBITS:
		stage.purpose = "capture"
		stage.call("configure", exhibit)
		var signature: String = await _model_image(stage, "gallery_" + str(exhibit["id"]))
		var family := str(exhibit["model"])
		if family in ["tifo", "rival", "group", "ground"]:
			_expect(signature not in signatures.get(family, []),
				"Advertised %s exhibits cannot be aliases of the same rendered model." % family)
			if not signatures.has(family):
				signatures[family] = []
			signatures[family].append(signature)
	signatures.clear()
	for item in Options.STORE_ITEMS:
		stage.purpose = "store"
		stage.call("configure", {"item": item})
		var signature: String = await _model_image(stage, "store_" + str(item["id"]))
		var family := str(item["kind"])
		_expect(signature not in signatures.get(family, []),
			"Every purchasable %s needs its own real model or cloth texture." % family)
		if not signatures.has(family):
			signatures[family] = []
		signatures[family].append(signature)
	stage.purpose = "share"
	for mode in ["quick", "workshop", "daily", "mural"]:
		var data := {"tb_mode_snapshot": mode, "tb_banner_snapshot": Banner.new().to_data(),
			"tb_club_snapshot": "BUCKETWICK ROVERS", "tb_ground_snapshot": 0,
			"tb_score_snapshot": [4200], "tb_stars": 3, "tb_football": "1 : 2"}
		if mode == "daily":
			data["tb_daily_snapshot"] = Daily.challenge("2026-01-19")
			data["tb_ground_snapshot"] = data["tb_daily_snapshot"]["ground"]
			data["tb_daily_streak"] = 365
			data["tb_assisted"] = true
		elif mode == "mural":
			data["tb_mode_snapshot"] = "derby_ritual"
			data["tb_mural_snapshot"] = true
		stage.call("configure", data)
		await _model_image(stage, "frozen_share_" + mode)
	get_root().remove_child(stage)
	stage.free()
	await process_frame

func _model_image(stage: Control, name: String) -> String:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport := stage.get("world_viewport") as SubViewport
	var image := viewport.get_texture().get_image()
	_expect(not image.is_empty(), "The GPU must draw the actual advertised " + name)
	_expect(image.save_png(_folder.path_join(name + ".png")) == OK, "Save model evidence for " + name)
	var camera := stage.get("camera") as Camera3D
	var screen := Rect2(Vector2.ZERO, Vector2(image.get_size())).grow(1.0)
	var meshes := 0
	for node in (stage.get("model_root") as Node).find_children("*", "VisualInstance3D", true, false):
		if not (node as VisualInstance3D).is_visible_in_tree():
			continue
		meshes += 1
		_expect(_geometry_fits(node as VisualInstance3D, camera, screen),
			"The complete advertised geometry must fit: %s / %s" % [name, node.name])
	_expect(meshes > 0, "An advertised model cannot be an empty stage: " + name)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func _geometry_fits(node: VisualInstance3D, camera: Camera3D, screen: Rect2) -> bool:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if not screen.has_point(camera.unproject_position(node.global_transform * vertex)):
					return false
		return true
	if node is Label3D:
		var transform := node.global_transform
		if (node as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			transform.basis = camera.global_basis.scaled(node.global_basis.get_scale())
		var faces := (node as Label3D).generate_triangle_mesh().get_faces()
		for vertex in faces:
			if not screen.has_point(camera.unproject_position(transform * vertex)):
				return false
		return true
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		var mesh_bounds := multi.mesh.get_aabb()
		for instance in multi.instance_count:
			var transform := node.global_transform * multi.get_instance_transform(instance)
			for corner in 8:
				if not screen.has_point(camera.unproject_position(transform * mesh_bounds.get_endpoint(corner))):
					return false
		return true
	return false
