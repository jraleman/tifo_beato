extends Control

## Original models dress the shared setup, shop, museum and frozen share snapshot.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const View = preload("res://games/tifo_beato/world/curva_view.gd")
const Ground = preload("res://games/tifo_beato/world/ground_scenery.gd")
const Crowd = preload("res://games/tifo_beato/world/crowd_multimesh.gd")
const Capo = preload("res://games/tifo_beato/world/capo_rig.gd")
const Rival = preload("res://games/tifo_beato/world/rival_rig.gd")
const Props = preload("res://games/tifo_beato/world/props.gd")
const Drum = preload("res://games/tifo_beato/world/drum_model.gd")
const Tifo = preload("res://games/tifo_beato/world/tifo_view.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const Registration = preload("res://games/tifo_beato/game.gd")
@export var purpose := "gallery"
var world_viewport: SubViewport
var model_root: Node3D
var camera: Camera3D
var configured_id := ""
var _scene_root: Node3D
var _texture: TextureRect
var _data: Dictionary = {}
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _spin := false
var _time := 0.0
var _focus := Vector3(0, 1.4, 0)
var _distance := 5.0
var _diorama := false
var _records := Records.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_viewport = SubViewport.new()
	world_viewport.own_world_3d = true
	world_viewport.gui_disable_input = true
	world_viewport.transparent_bg = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_viewport)
	_texture = TextureRect.new()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture.texture = world_viewport.get_texture()
	add_child(_texture)
	_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resize)
	if purpose == "gallery":
		_records.load_file()
		Registration.refresh_gallery(GameCatalog.get_manifest(Options.GAME_ID), _records.data)
	configure(_data)
	_resize()

func configure(data: Dictionary) -> void:
	_data = data.duplicate(true)
	if not is_node_ready():
		return
	if _scene_root != null:
		world_viewport.remove_child(_scene_root)
		_scene_root.queue_free()
	_scene_root = Node3D.new()
	world_viewport.add_child(_scene_root)
	View.light_stage(_scene_root)
	var environment := _scene_root.get_child(0) as WorldEnvironment
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	model_root = Node3D.new()
	model_root.name = "AdvertisedOriginalModel"
	_scene_root.add_child(model_root)
	_diorama = false
	_focus = Vector3(0, 1.4, 0)
	_distance = 5.0
	var entry: Dictionary = data.get("item", data.get("character", data))
	configured_id = str(entry.get("id", "bucket"))
	var model := str(entry.get("model", entry.get("kind", "bucket")))
	if purpose == "character":
		_group(int(entry.get("pool", 0)), data)
	elif purpose == "store":
		_store(entry)
	elif purpose == "share":
		_share(data)
	elif model == "ground":
		_ground(int(entry.get("ground", 0)))
	elif model == "tifo":
		_tifo(int(entry.get("tier", 1)))
	elif model == "group":
		_group(int(entry.get("pool", 0)), data)
	elif model == "rival":
		model_root.add_child(Rival.new(int(entry.get("rival", 0))))
	elif model == "intro":
		_intro(int(entry.get("card", 0)))
	else:
		model_root.add_child(Props.make(model))
		if model == "flag":
			_focus.y = 2.5
			_distance = 7.0
	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 200.0
	_scene_root.add_child(camera)
	_frame()

func _group(pool: int, data: Dictionary) -> void:
	var capo := Capo.new()
	capo.player_color = data.get("player_color", Color("4da3ff"))
	capo.primary = Color("8c8f94") if pool == 1 else Options.BUCKET
	capo.outfit = {"hat": "tb_hat_fisher" if pool == 1 else "tb_hat_bobble",
		"drum": "tb_drum_bass" if pool == 2 else "tb_drum_bucket"}
	capo.position.x = -0.6
	model_root.add_child(capo)
	for index in 3:
		var fan := Builder.instance(Crowd.fan_mesh(), model_root, "SectionMate%d" % index)
		fan.position = Vector3(0.2 + index * 0.7, 0.0, -0.5)
		fan.scale = Vector3.ONE * 0.75
	if pool == 3:
		var flag := Props.make("flag")
		flag.scale = Vector3.ONE * 0.5
		flag.position.x = 1.2
		model_root.add_child(flag)
	elif pool == 4:
		var kazoo := Props.make("kazoo")
		kazoo.position.x = 1.2
		kazoo.scale = Vector3.ONE * 0.6
		model_root.add_child(kazoo)
	_distance = 5.3

func _store(entry: Dictionary) -> void:
	var kind := str(entry.get("kind", "drum"))
	if kind == "drum":
		Builder.instance(Drum.make(configured_id), model_root, "ActualStoreDrum")
		_focus.y = 0.5
		_distance = 2.8
	elif kind == "fabric":
		var banner := Banner.new()
		banner.fabric = ["tb_fabric_sheet", "tb_fabric_tarp", "tb_fabric_silk",
			"tb_fabric_glitter"].find(configured_id)
		_banner_quad(banner, Vector3(0, 1.2, 0), Vector2(3.6, 1.8))
		_distance = 3.5
	else:
		var capo := Capo.new()
		capo.outfit = {kind: configured_id}
		model_root.add_child(capo)
		capo.pose(60.0, false, 0.0, true)

func _ground(index: int) -> void:
	_diorama = true
	model_root.add_child(Ground.new(index))
	var fans := Crowd.new([11, 300, 900, 1800, 3000][index])
	model_root.add_child(fans)
	fans.present(65.0, 0.8, 0.1, 0.0, 1, true)
	var capo := Capo.new()
	capo.position = Vector3(0, 1.35, -5.1)
	capo.rotation.y = PI
	model_root.add_child(capo)
	_focus = Vector3(0, 2, 0)
	_distance = 54.0 if index == 3 else 50.0

func _tifo(tier: int) -> void:
	var banner := Banner.new()
	banner.from_data(_records.data["banner"])
	var fans := Crowd.new(300)
	fans.primary = banner.primary
	fans.secondary = banner.secondary
	model_root.add_child(fans)
	fans.present(90.0, 0.9, 0.02, 0.0, tier, true)
	var tifo := Tifo.new()
	model_root.add_child(tifo)
	tifo.configure(fans.seats, banner)
	tifo.present(tier, 8.0, 0.0, false, false)
	_focus = Vector3(0, 4, -11)
	_distance = 26.0

func _share(data: Dictionary) -> void:
	if not data.has("tb_banner_snapshot"):
		model_root.add_child(Props.make("bucket"))
		_focus.y = 0.5
		_distance = 2.8
		return
	var banner := Banner.new()
	banner.from_data(data.get("tb_banner_snapshot", {}))
	var capo := Capo.new()
	capo.outfit = data.get("tb_outfit_snapshot", {})
	capo.player_color = data.get("secondary_color", Color("4da3ff"))
	capo.primary = banner.primary
	capo.position.x = -1.5
	model_root.add_child(capo)
	capo.pose(80.0, false, 0.0, true)
	if str(data.get("tb_mode_snapshot", "")) == "workshop" or bool(data.get("tb_mural_snapshot", false)):
		capo.scale = Vector3.ONE * 0.55
		capo.position.x = -2.2
		_banner_quad(banner, Vector3(0.2, 1.7, -0.6), Vector2(4.8, 2.4))
		_placard("%.0f%% QUALITY | %d MISHAPS" % [banner.quality, banner.mishaps.size()],
			Vector3(0, 3.4, 0))
		_distance = 6.5
		return
	_banner_quad(banner, Vector3(0.75, 1.6, -0.6), Vector2(3.4, 1.7))
	var ground := int(data.get("tb_ground_snapshot", 0))
	var scores: Array = data.get("tb_score_snapshot", [0])
	_placard("%s\n%s | %d STARS\nNOISE %d | FOOTBALL %s%s" % [
		str(data.get("tb_club_snapshot", "YOUR CURVA")), Options.GROUNDS[ground]["title"],
		int(data.get("tb_stars", 0)), int(scores[0]), str(data.get("tb_football", "0 : 0")),
		" | ASSISTED" if bool(data.get("tb_assisted", false)) else ""], Vector3(0, 3.8, 0))
	if data.has("tb_daily_snapshot"):
		var daily: Dictionary = data["tb_daily_snapshot"]
		_placard("DAILY %s | SEED %d\n%s | %s\n%s | STREAK %d%s" % [
			daily["date"], daily["seed"], Options.GROUPS[int(daily["pool"])]["title"],
			Options.GROUNDS[ground]["title"], daily["title"], int(data.get("tb_daily_streak", 0)),
			" | ASSISTED" if bool(data.get("tb_assisted", false)) else ""],
			Vector3(0, -0.5, 0))
	_focus = Vector3(0, 1.4, 0)
	_distance = 7.4

func _placard(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "FrozenPerformanceFacts"
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.008
	label.modulate = Options.CREAM
	label.outline_modulate = Options.NAVY
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	model_root.add_child(label)

func _intro(card: int) -> void:
	if card == 0:
		_ground(0)
	elif card == 1:
		model_root.add_child(Props.make("bucket"))
		_focus.y = 0.5
		_distance = 2.8
	elif card == 2:
		_ground(4)
	elif card == 3:
		model_root.add_child(Props.make("kevin"))
	else:
		var capo := Capo.new()
		model_root.add_child(capo)
		capo.pose(90.0, false, 0.0, true)
		var fence := Builder.new()
		fence.beam(Vector3(-1.8, 1.0, 0.2), Vector3(1.8, 1.0, 0.2), 0.1, Options.NAVY)
		for side in [-1, 1]:
			fence.cylinder(Vector3(side * 1.2, 0.8, 0.2), 0.08, 1.6, Options.NAVY)
		Builder.instance(fence.finish(), model_root, "TheFence")

func _banner_quad(banner: Banner, at: Vector3, dimensions: Vector2) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = dimensions
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(banner.render_image())
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.35 if banner.fabric == 2 else 1.0
	mesh.material_override = material
	mesh.position = at
	model_root.add_child(mesh)

func set_view(yaw: float, pitch: float, zoom: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -0.9, 0.9)
	_zoom = clampf(zoom, 0.6, 1.8)
	_frame()

func set_auto_spin(value: bool) -> void:
	_spin = value

func _process(delta: float) -> void:
	var settings := get_tree().root.get_node_or_null("Settings")
	if settings != null and bool(settings.call("reduced_motion_enabled")):
		return
	if _spin:
		_time += delta
		_yaw += delta * 0.22
		_frame()

func _frame() -> void:
	if camera == null:
		return
	var offset := Vector3(29, 27, 37) if _diorama else Vector3(3.5, 2.3, 6.0)
	offset = offset.rotated(Vector3.RIGHT, _pitch).rotated(Vector3.UP, _yaw)
	camera.position = _focus + offset
	camera.look_at(_focus)
	var aspect := maxf(0.25, size.x / maxf(1.0, size.y))
	camera.size = maxf(_distance, _distance * 1.45 / aspect) / _zoom

func _resize() -> void:
	if world_viewport == null:
		return
	var scale_factor := minf(1.0, 1200.0 / maxf(1.0, maxf(size.x, size.y)))
	world_viewport.size = Vector2i(maxi(1, roundi(size.x * scale_factor)),
		maxi(1, roundi(size.y * scale_factor)))
	_frame()
