extends SceneTree

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Driver = preload("res://games/tifo_beato/tests/flow_fixture.gd")
const Stage = preload("res://games/tifo_beato/presentation/stage.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Build = preload("res://games/tifo_beato/workshop/build_race.gd")
const Steward = preload("res://games/tifo_beato/steward/steward_state.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
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
	var tifo: Node3D = view.get("tifo")
	tifo.call("present", 0, 0.0, 0.0, false, false)
	tifo.call("present", 5, 8.0, 1.0, true, false)
	tifo.call("present", 5, 8.0, 1.2, true, false)
	_expect(float(tifo.get("_opacity")) > 0.1 and float(tifo.get("_opacity")) < 0.9,
		"Reduced-motion tifos must really cross-fade rather than pop.")
	tifo.call("present", 5, 8.0, 1.6, true, false)
	_expect(is_equal_approx(float(tifo.get("_opacity")), 1.0), "The cross-fade must finish.")
	await _test_real_input(game, settings)
	await _test_cast_and_cameras(game, settings)
	get_root().remove_child(game)
	game.free()
	await process_frame
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
	for mode in ["quick", "workshop"]:
		stage.call("configure", {"tb_mode_snapshot": mode, "tb_banner_snapshot": Banner.new().to_data(),
			"tb_club_snapshot": "BUCKETWICK ROVERS", "tb_ground_snapshot": 0,
			"tb_score_snapshot": [4200], "tb_stars": 3, "tb_football": "1 : 2"})
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
