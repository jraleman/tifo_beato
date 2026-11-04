extends Control

## Isolated Compatibility world under GameShell, with safe response-only camera cuts.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const State = preload("res://games/tifo_beato/match/match_state.gd")
const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Ground = preload("res://games/tifo_beato/world/ground_scenery.gd")
const Crowd = preload("res://games/tifo_beato/world/crowd_multimesh.gd")
const Capo = preload("res://games/tifo_beato/world/capo_rig.gd")
const Pitch = preload("res://games/tifo_beato/world/pitch_view.gd")
const Tifo = preload("res://games/tifo_beato/world/tifo_view.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Props = preload("res://games/tifo_beato/world/props.gd")
const Rival = preload("res://games/tifo_beato/world/rival_rig.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Steward = preload("res://games/tifo_beato/steward/steward_state.gd")
const Build = preload("res://games/tifo_beato/workshop/build_race.gd")
const Travel = preload("res://games/tifo_beato/world/travel_scenery.gd")
var world_viewport: SubViewport
var camera: Camera3D
var world: Node3D
var crowd: Crowd
var capo: Capo
var pitch: Pitch
var tifo: Tifo
var state: State
var reduced_motion := false
var intense_effects := true
var ground := 0
var primary := Options.BUCKET
var secondary := Options.NAVY
var player_color := Color("4da3ff")
var outfit: Dictionary = {}
var crest := 0
var scarf_pattern := 0
var active_seat := 0
var first_player_color := Color("4da3ff")
var second_player_color := Color("ff5c6c")
var activity: RefCounted
var activity_kind := "match"
var activity_context := "rehearsal"
var opponent: Node3D
var effects: Dictionary = {}
var beach_balls: Array[Node3D] = []
var _image: TextureRect
var _shot := 0
var _phase := -1
var _activity_root: Node3D
var _carried_banner: MeshInstance3D
var _floodlight: DirectionalLight3D
var _environment: WorldEnvironment
var _last_time := 0.0
var _banner_mishaps := -1
var _ground_root: Node3D
var _travel: Travel
var _tornado: Node3D
var _crowd_scale := 1.0
var _mural_progress := -1
var _mural_image: Image

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_viewport = SubViewport.new()
	world_viewport.name = "TifoWorldViewport"
	world_viewport.own_world_3d = true
	world_viewport.gui_disable_input = true
	world_viewport.size = Vector2i(1280, 720)
	world_viewport.msaa_3d = Viewport.MSAA_2X
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_viewport)
	_image = TextureRect.new()
	_image.name = "StadiumImage"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.texture = world_viewport.get_texture()
	add_child(_image)
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build()
	resized.connect(_resize)
	_resize()

func configure(match_state: State) -> void:
	state = match_state
	var crowd_scale := float(state.get("_settings").get("crowd_scale", 1.0))
	if ground != state.ground or not is_equal_approx(crowd_scale, _crowd_scale):
		ground = state.ground
		_crowd_scale = crowd_scale
		if is_node_ready():
			build()
	if tifo != null:
		tifo.configure(crowd.seats, state.banner)
		(_carried_banner.material_override as StandardMaterial3D).albedo_texture = \
			ImageTexture.create_from_image(tifo.image)
	_phase = -1

func configure_activity(value: RefCounted, kind: String) -> void:
	activity = value
	activity_kind = kind
	_last_time = 0.0
	_banner_mishaps = -1
	if world != null:
		for prop: Node3D in effects.values():
			prop.visible = false
		for ball in beach_balls:
			ball.visible = false
		tifo.present(0, 0.0, 0.0, false, false)
		_build_activity()
	_frame_camera()

func build() -> void:
	if world != null:
		world_viewport.remove_child(world)
		world.queue_free()
	world = Node3D.new()
	world.name = "OriginalToyStadium"
	world_viewport.add_child(world)
	light_stage(world, ground == 4)
	_environment = world.get_child(0) as WorldEnvironment
	_floodlight = world.get_node("WarmFloodlight") as DirectionalLight3D
	_ground_root = Ground.new(ground)
	world.add_child(_ground_root)
	var count: int = [11, 300, 900, 1800, 3000][ground]
	crowd = Crowd.new(roundi(count * _crowd_scale))
	crowd.primary = primary
	crowd.secondary = secondary
	crowd.scarf_pattern = scarf_pattern
	world.add_child(crowd)
	capo = Capo.new()
	capo.player_color = player_color
	capo.primary = primary
	capo.outfit = outfit
	capo.crest = crest
	capo.position = Vector3(0, 1.35, -5.1)
	capo.scale = Vector3.ONE * 1.65
	capo.rotation.y = PI
	world.add_child(capo)
	pitch = Pitch.new()
	world.add_child(pitch)
	tifo = Tifo.new()
	world.add_child(tifo)
	var design := state.banner if state != null else Banner.new()
	tifo.configure(crowd.seats, design)
	effects.clear()
	beach_balls.clear()
	for kind in ["seagull", "drum_skin", "power_cut", "rain", "kazoo",
		"air_horn", "trumpet", "rival_drums", "inflatable"]:
		var prop := Props.make(kind, primary)
		prop.visible = false
		prop.position = Vector3(9, 2, -10)
		world.add_child(prop)
		effects[kind] = prop
	(effects["seagull"] as Node3D).position = Vector3(0, 9, -9)
	(effects["drum_skin"] as Node3D).position = Vector3(-1.8, 1.35, -4.8)
	(effects["rain"] as Node3D).position = Vector3(-6, 3, -11)
	(effects["kazoo"] as Node3D).position = Vector3(5, 2, -8)
	_carried_banner = MeshInstance3D.new()
	_carried_banner.name = "ActualStolenBanner"
	var stolen := QuadMesh.new()
	stolen.size = Vector2(4.0, 2.0)
	_carried_banner.mesh = stolen
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(tifo.image)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_carried_banner.material_override = material
	_carried_banner.position = Vector3(0, -0.2, 0.6)
	effects["seagull"].add_child(_carried_banner)
	for index in 8:
		var ball := Props.make("ball", primary if index % 2 == 0 else secondary)
		ball.visible = false
		ball.position = Vector3(-8 + index * 2.2, 5.0 + index % 3, -6)
		world.add_child(ball)
		beach_balls.append(ball)
	_tornado = Node3D.new()
	_tornado.name = "OriginalScarfTornado"
	_tornado.position = Vector3(5, 2, -7)
	world.add_child(_tornado)
	var ribbons := Builder.new()
	for index in 24:
		var angle := index * TAU / 6.0
		var radius := 0.7 + index * 0.075
		ribbons.box(Vector3(cos(angle) * radius, index * 0.18, sin(angle) * radius),
			Vector3(0.9, 0.12, 0.3), primary if index % 2 == 0 else secondary,
			Vector3(0, -angle, 0.2))
	Builder.instance(ribbons.finish(), _tornado, "SpinningOriginalScarves")
	_tornado.hide()
	camera = Camera3D.new()
	camera.name = "FencePitchTifoCamera"
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 200.0
	world.add_child(camera)
	_activity_root = null
	_build_activity()
	_frame_camera()

func _build_activity() -> void:
	if _activity_root != null:
		world.remove_child(_activity_root)
		_activity_root.queue_free()
	_activity_root = Node3D.new()
	_activity_root.name = "ActualActivityCast"
	world.add_child(_activity_root)
	opponent = null
	_travel = null
	_mural_progress = -1
	_mural_image = null
	var travel_scene := activity_kind in ["away_bus", "away_station", "derby_ritual", "mural"]
	_ground_root.visible = not travel_scene
	pitch.visible = not travel_scene
	crowd.visible = not travel_scene
	tifo.visible = not travel_scene
	_tornado.visible = false
	capo.position.x = 0.0
	capo.rotation.y = PI
	if activity_kind in ["war", "steward", "workshop", "mural", "derby_ritual"]:
		capo.position.x = -3.0
		capo.rotation.y = 0.35
	if travel_scene:
		var kind := activity_kind.trim_prefix("away_")
		if kind == "derby_ritual":
			kind = activity_context
		_travel = Travel.new(kind)
		_activity_root.add_child(_travel)
		capo.position.x = -2.5 if kind == "mural" else 0.0
	if activity is War:
		var war := activity as War
		if war.cpu_rival:
			opponent = Rival.new(war.rival)
		else:
			var other := Capo.new()
			other.player_color = second_player_color
			other.primary = primary
			other.outfit = outfit
			other.crest = crest
			opponent = other
		opponent.position = Vector3(3, 1.35, -5.1)
		opponent.rotation.y = -0.35
		opponent.scale = Vector3.ONE * 1.65
		_activity_root.add_child(opponent)
	elif activity is Steward:
		opponent = Props.make("steward")
		opponent.position = Vector3(3, 1.35, -5.1)
		opponent.scale = Vector3.ONE * 1.65
		_activity_root.add_child(opponent)
		var item := Props.make("flag" if (activity as Steward).kind == "flag" else "bucket", primary)
		item.position = Vector3(-4.0, 1.35, -4.8)
		item.scale = Vector3.ONE * 0.7
		_activity_root.add_child(item)

func present() -> void:
	if state == null or crowd == null:
		return
	if activity != null and activity_kind != "match":
		_present_activity()
		return
	var phase := state.phase()
	var index := state.phase_index()
	if index != _phase:
		_phase = index
		if str(phase["kind"]) == "response" and not reduced_motion:
			_shot = 2 if state.tifo.reveal_left > 0.0 else (
				1 if state.goal_moment_left > 0.0 else 0)
		_frame_camera()
	if str(phase["kind"]) == "response" and float(phase["end"]) - state.time < 0.8 \
		and _shot != 0:
		_shot = 0
		_frame_camera()
	crowd.primary = primary
	crowd.secondary = secondary
	crowd.scarf_pattern = 2 if str(outfit.get("scarf", "")).ends_with("checks") else (
		4 if str(outfit.get("scarf", "")).ends_with("fringe") else scarf_pattern)
	crowd.present(state.crowd.energy, state.crowd.sync, state.crowd.phase_scatter,
		state.time, state.tifo.tier if state.tifo.reveal_left > 0 else 0, reduced_motion)
	capo.pose(state.crowd.energy, state.life.dead, state.time, reduced_motion)
	pitch.present(state.sim, state.crowd.energy, state.time, reduced_motion)
	tifo.present(state.tifo.tier, state.tifo.reveal_left, state.time, reduced_motion,
		intense_effects, not state.visual_phase.is_empty())
	_present_effects()

func _present_activity() -> void:
	var now := float(activity.get("time"))
	var player_energy := 65.0
	if activity is War:
		var war := activity as War
		capo.player_color = first_player_color
		player_energy = 85.0 if war.input_seat() == 0 else 20.0
		if opponent is Rival:
			var leading_half := -1
			if war.phase > 0:
				var turn: Dictionary = war.phases[war.phase]
				leading_half = 0 if now - float(turn["call_t"]) < float(turn["beat"]) * 4.0 else 1
			(opponent as Rival).pose(now, reduced_motion, war.input_seat() < 0, leading_half)
		elif opponent is Capo:
			(opponent as Capo).pose(85.0 if war.input_seat() == 1 else 20.0,
				false, now, reduced_motion)
	elif activity is Steward:
		var steward := activity as Steward
		opponent.rotation.y = 0.0 if steward.watching(now) else -PI * 0.5
		capo.position.x = -3.0 + minf(2.0, steward.progress * 0.1)
	elif activity is Build:
		var build := activity as Build
		if build.banner.mishaps.size() != _banner_mishaps:
			_banner_mishaps = build.banner.mishaps.size()
			tifo.configure(crowd.seats, build.banner)
		if activity_kind == "mural" and _travel != null:
			if _mural_image == null or _mural_progress != build.judge.hits:
				_mural_image = build.banner.render_image()
				_mural_progress = build.judge.hits
			_travel.set_mural(_mural_image,
				float(build.judge.hits) / maxf(1, build.judge.notes.size()))
		else:
			tifo.present(3, 1.0, now, false, false)
	if _travel != null:
		var beat := float((activity as State).phase()["beat"]) if activity is State else 0.6
		_travel.present(now, beat, reduced_motion)
		player_energy = (activity as State).crowd.energy if activity is State else player_energy
	capo.pose(player_energy, false, now, reduced_motion)
	crowd.present(65, 0.8, 0.1, now, 1, reduced_motion)

func _present_effects() -> void:
	var active := state.chaos.active
	_tornado.visible = state.fury.protection_left > 0.0
	_tornado.rotation.y = 0.0 if reduced_motion else state.time * 2.5
	for kind: String in effects:
		(effects[kind] as Node3D).visible = kind == active or kind == state.disruptions.active \
			or kind == "rain" and "rain" in state.chaos.successes
	var bucket := capo.get_node_or_null("OriginalBucketDrum") as MeshInstance3D
	if bucket != null:
		bucket.visible = active != "drum_skin"
	(effects["rain"] as Node3D).scale.y = 0.45 if active == "rain" else 1.0
	for index in beach_balls.size():
		beach_balls[index].visible = active == "beach_balls" and index >= state.chaos.progress
		if not reduced_motion:
			beach_balls[index].position.y = 5.0 + index % 3 + sin(state.time * 0.8 + index) * 0.35
		else:
			beach_balls[index].position.y = 5.0 + index % 3
	if not reduced_motion:
		(effects["seagull"] as Node3D).position.x = sin(state.time * 0.4) * 7.0
	else:
		(effects["seagull"] as Node3D).position.x = 0.0
	var dt := clampf(state.time - _last_time, 0.0, 0.1)
	_last_time = state.time
	var lighting := 0.22 if active == "power_cut" else 1.0
	if not state.visual_phase.is_empty():
		_floodlight.light_energy = lighting * 1.4
		_environment.environment.ambient_light_energy = lighting * 0.65
		return
	_floodlight.light_energy = lerpf(_floodlight.light_energy, lighting * 1.4, dt * 2.0)
	_environment.environment.ambient_light_energy = lerpf(
		_environment.environment.ambient_light_energy, lighting * 0.65, dt * 2.0)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_shot = 0
	_frame_camera()
	present()

func set_intense_effects(value: bool) -> void:
	intense_effects = value
	present()

func _resize() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var pixels := size
	pixels *= minf(1.0, 1440.0 / maxf(size.x, size.y))
	world_viewport.size = Vector2i(maxi(1, roundi(pixels.x)), maxi(1, roundi(pixels.y)))
	_frame_camera()

func _frame_camera() -> void:
	if camera == null or size.y <= 0:
		return
	var focus := Vector3(0, 3, 0)
	var offset := Vector3(19, 17, 27)
	focus = Vector3(0, 4, -10)
	if _shot == 1:
		focus = Vector3(0, 0, 10)
		offset = Vector3(22, 28, 28)
	elif _shot == 2:
		focus = Vector3(0, 5, -12)
		offset = Vector3(0, 21, 38)
	camera.position = focus + offset
	camera.look_at(focus)
	var aspect := maxf(0.1, size.x / size.y)
	camera.size = maxf(40.0, 66.0 / aspect)
	if _shot == 0:
		camera.size = maxf(24.0, 42.0 / aspect)
	if activity_kind in ["war", "steward", "workshop", "away_bus", "away_station",
		"derby_ritual", "mural"]:
		var arena_focus := Vector3(0, 3.5, -5.0)
		camera.position = arena_focus + Vector3(5, 5, 15)
		camera.look_at(arena_focus)
		camera.size = maxf(16.0, 20.0 / aspect)
		if activity_kind in ["away_bus", "away_station", "derby_ritual", "mural"]:
			camera.size = maxf(11.0, 18.0 / aspect)

static func light_stage(root: Node3D, sunset := false) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("53425e") if sunset else Color("202c40")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff6d8")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.name = "WarmFloodlight"
	light.light_color = Color("fff6d8")
	light.light_energy = 1.4
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	root.add_child(light)
