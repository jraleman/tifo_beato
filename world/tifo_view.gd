extends Node3D

## One card batch samples the actual saved banner, mishaps included.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
var cards: MultiMeshInstance3D
var banner_mesh: MeshInstance3D
var mascot: MeshInstance3D
var smoke: MultiMeshInstance3D
var image: Image
var _seats: Array[Transform3D] = []
var _banner := Banner.new()
var _target_tier := 0
var _draw_tier := 0
var _fade_start := 0.0
var _fade_from := 0.0
var _opacity := 0.0

func configure(seats: Array[Transform3D], design: Banner) -> void:
	_seats = seats
	_banner = design
	image = design.render_image()
	if cards == null:
		_build()
	cards.multimesh.instance_count = seats.size()
	for index in seats.size():
		var seat := seats[index]
		seat.origin += Vector3(0, 1.9 * seat.basis.get_scale().y, 0.2)
		cards.multimesh.set_instance_transform(index, seat)
		var columns := 6 if seats.size() == 11 else 50
		var rows := ceili(float(seats.size()) / columns)
		var x := mini(image.get_width() - 1, floori(float(index % columns) / columns * image.get_width()))
		var y := mini(image.get_height() - 1, floori(float(index / columns) / rows * image.get_height()))
		cards.multimesh.set_instance_color(index, image.get_pixel(x, y))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	banner_mesh.material_override = material

func present(tier: int, reveal: float, time: float, reduced: bool, intense: bool) -> void:
	if cards == null:
		return
	var target := tier if reveal > 0.0 else 0
	if target != _target_tier:
		_fade_start = time
		_fade_from = _opacity
		_target_tier = target
		if target > 0:
			_draw_tier = target
	var alpha := clampf((time - _fade_start) / 0.45, 0.0, 1.0) if reduced else 1.0
	_opacity = lerpf(_fade_from, 1.0 if target > 0 else 0.0, alpha)
	if not reduced:
		_fade_from = _opacity
		_fade_start = time - 0.45
	for node in [cards, banner_mesh, smoke, mascot]:
		var material := node.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = _opacity
	cards.visible = _draw_tier >= 2 and _opacity > 0.001
	banner_mesh.visible = _draw_tier >= 3 and _opacity > 0.001
	smoke.visible = _draw_tier >= 4 and _opacity > 0.001
	mascot.visible = _draw_tier >= 5 and _opacity > 0.001
	mascot.position.y = 5.0 if reduced else 5.0 + sin(time * 0.5) * 0.18
	for index in smoke.multimesh.instance_count:
		var size := 2.0 + (0.0 if reduced else sin(time * (0.2 if not intense else 0.4) + index) * 0.3)
		var at := Vector3(-14 + index * 4.0, 6.0 + (index % 3), -15.0)
		smoke.multimesh.set_instance_transform(index,
			Transform3D(Basis.from_scale(Vector3.ONE * size), at))
		smoke.multimesh.set_instance_color(index, _banner.primary if index % 2 else _banner.secondary)

func _build() -> void:
	cards = MultiMeshInstance3D.new()
	cards.name = "ActualBannerMosaic"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var card := BoxMesh.new()
	card.size = Vector3(0.8, 0.65, 0.06)
	multi.mesh = card
	cards.multimesh = multi
	cards.material_override = Builder.material()
	add_child(cards)
	banner_mesh = MeshInstance3D.new()
	banner_mesh.name = "FiftyMetreBanner"
	var quad := QuadMesh.new()
	quad.size = Vector2(21, 10.5)
	banner_mesh.mesh = quad
	banner_mesh.material_override = Builder.material()
	banner_mesh.position = Vector3(0, 6.0, -7.5)
	add_child(banner_mesh)
	var owl := Builder.new()
	owl.ellipsoid(Vector3(0, 2.1, 0), Vector3(6, 6, 3.5), _banner.primary)
	for side in [-1, 1]:
		owl.ellipsoid(Vector3(side * 1.2, 3.0, 1.5), Vector3(2.1, 2.3, 0.7), Color.WHITE)
		owl.ellipsoid(Vector3(side * 1.2, 3.0, 1.9), Vector3.ONE * 0.75, Color("1d2a4a"))
		owl.cylinder(Vector3(side * 2.0, 5.0, 0), 0.7, 2.0, _banner.secondary,
			Vector3(0, 0, side * -0.3), 8, 0.0)
	owl.cylinder(Vector3(0, 2.5, 2), 0.5, 1.0, Color("f29045"),
		Vector3(PI / 2.0, 0, 0), 6, 0.0)
	mascot = Builder.instance(owl.finish(), self, "UnholyInflatableOwl")
	mascot.position = Vector3(0, 5, -19)
	smoke = MultiMeshInstance3D.new()
	smoke.name = "SoftCartoonSmoke"
	var smoke_multi := MultiMesh.new()
	smoke_multi.transform_format = MultiMesh.TRANSFORM_3D
	smoke_multi.use_colors = true
	var puff := SphereMesh.new()
	puff.radius = 0.7
	puff.height = 1.4
	puff.radial_segments = 10
	puff.rings = 4
	smoke_multi.mesh = puff
	smoke_multi.instance_count = 8
	smoke.multimesh = smoke_multi
	var smoke_material := StandardMaterial3D.new()
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.roughness = 1.0
	smoke.material_override = smoke_material
	add_child(smoke)
	present(0, 0.0, 0.0, true, false)
