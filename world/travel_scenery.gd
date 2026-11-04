extends Node3D

## Original cutaway toys keep travel and neighbourhood rituals visibly distinct.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
var kind := "bus"
var wipers: Array[Node3D] = []
var mural: MeshInstance3D
var _mural_image: Image
var _painted := -1

func _init(activity := "bus") -> void:
	kind = activity

func _ready() -> void:
	name = "Original_" + kind
	var mesh := Builder.new()
	mesh.box(Vector3(0, 0.1, -5), Vector3(15, 0.2, 9), Color("555c69"))
	if kind == "bus":
		_bus(mesh)
	elif kind == "station":
		_station(mesh)
	else:
		_neighbourhood(mesh)
	Builder.instance(mesh.finish(), self, "OriginalTravelGeometry")

func _bus(mesh: RefCounted) -> void:
	mesh.box(Vector3(0, 1.1, -5), Vector3(12, 1.2, 5), Options.BUCKET)
	mesh.box(Vector3(0, 3.2, -7.5), Vector3(11.5, 3.0, 0.18), Color("466982"))
	for x in [-5.7, 0.0, 5.7]:
		mesh.beam(Vector3(x, 1.8, -7.5), Vector3(x, 5.0, -7.5), 0.16, Options.CREAM)
	mesh.beam(Vector3(-5.8, 5, -7.5), Vector3(5.8, 5, -7.5), 0.18, Options.CREAM)
	for x in [-4.3, 4.3]:
		for z in [-7.4, -2.6]:
			mesh.cylinder(Vector3(x, 0.75, z), 0.85, 0.45, Color("202b39"),
				Vector3(PI * 0.5, 0, 0))
	for x in [-4.0, -1.5, 1.5, 4.0]:
		mesh.box(Vector3(x, 2.0, -6.0), Vector3(1.3, 0.4, 1.5), Color("496f83"))
		mesh.ellipsoid(Vector3(x, 3.0, -6.0), Vector3(0.65, 0.75, 0.65), Color("e3b38d"))
		mesh.box(Vector3(x, 2.45, -6), Vector3(0.8, 0.7, 0.6), Options.NAVY)
	for x in [-2.0, 2.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 2.5, -7.25)
		add_child(pivot)
		var blade := Builder.new()
		blade.beam(Vector3.ZERO, Vector3(0, 1.8, 0), 0.12, Color("172439"))
		Builder.instance(blade.finish(), pivot, "BeatWiper")
		wipers.append(pivot)
	_sign("AWAY SCARVES - POTHOLE = REST", Vector3(0, 5.8, -7.4))

func _station(mesh: RefCounted) -> void:
	mesh.box(Vector3(0, 0.6, -6), Vector3(14, 0.8, 6), Color("b0a494"))
	mesh.box(Vector3(0, 1.1, -2.9), Vector3(14, 0.1, 0.35), Options.BUCKET)
	for x in [-6.0, -2.0, 2.0, 6.0]:
		mesh.cylinder(Vector3(x, 3.5, -8), 0.25, 5, Color("6c8581"))
		mesh.beam(Vector3(x, 6, -8), Vector3(x, 6.8, -5), 0.22, Color("6c8581"))
	mesh.box(Vector3(0, 6.9, -6.8), Vector3(14.5, 0.2, 4), Color("6c8581"))
	mesh.box(Vector3(3.8, 2, -6.6), Vector3(3.2, 0.25, 0.9), Color("a97d54"))
	for x in [2.4, 5.2]:
		mesh.box(Vector3(x, 1.5, -6.6), Vector3(0.15, 1, 0.7), Color("172439"))
	mesh.cylinder(Vector3(0, 5.7, -7.7), 0.65, 0.18, Options.CREAM,
		Vector3(PI * 0.5, 0, 0))
	mesh.beam(Vector3(0, 5.7, -7.55), Vector3(0, 6.2, -7.55), 0.08, Options.NAVY)
	_sign("PLATFORM FORZA - CALL, THEN LISTEN", Vector3(0, 7.5, -7.8))

func _neighbourhood(mesh: RefCounted) -> void:
	mesh.box(Vector3(0, 3, -8), Vector3(13, 5.5, 0.6),
		Color("c5ab8a") if kind != "mural" else Color("b8b7b0"))
	if kind == "mural":
		mural = MeshInstance3D.new()
		mural.name = "ActualPaintedMural"
		var quad := QuadMesh.new()
		quad.size = Vector2(8, 4)
		mural.mesh = quad
		mural.position = Vector3(0, 3.2, -7.65)
		var material := StandardMaterial3D.new()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mural.material_override = material
		add_child(mural)
	else:
		mesh.box(Vector3(3, 2.6, -7.6), Vector3(3, 3.5, 0.2), Color("426176"))
		mesh.box(Vector3(-3.2, 2.7, -7.6), Vector3(3.5, 2.8, 0.2), Color("d6cfad"))
		if kind == "bakery":
			for index in 4:
				mesh.ellipsoid(Vector3(-4.3 + index * 0.7, 2.2, -7.2),
					Vector3(0.7, 0.35, 0.4), Color("c98843"))
		elif kind == "barber":
			for index in 8:
				mesh.cylinder(Vector3(0.6, 1.8 + index * 0.3, -7.4), 0.2, 0.3,
					Color("b95458") if index % 2 == 0 else Options.CREAM)
	_sign({"mural": "COMMUNITY MURAL", "pub": "THE SCARF AND SPOON - QUIZ NIGHT",
		"bakery": "ELEVEN ROLLS BAKERY", "barber": "ONE LAST TRIM",
		"rehearsal": "INTER NEBULA REHEARSAL"}.get(kind, "DERBY WEEK"),
		Vector3(0, 6.4, -7.6))

func set_mural(image: Image, progress: float) -> void:
	if mural == null:
		return
	var width := maxi(1, roundi(image.get_width() * clampf(progress, 0.0, 1.0)))
	if width == _painted and _mural_image == image:
		return
	_painted = width
	_mural_image = image
	(mural.material_override as StandardMaterial3D).albedo_texture = ImageTexture.create_from_image(
		image.get_region(Rect2i(0, 0, width, image.get_height())))
	var size_x := 8.0 * width / image.get_width()
	(mural.mesh as QuadMesh).size.x = size_x
	mural.position.x = -4.0 + size_x * 0.5

func present(at: float, beat: float, reduced_motion: bool) -> void:
	for index in wipers.size():
		wipers[index].rotation.z = 0.0 if reduced_motion else sin(at / beat * TAU) * 0.6

func _sign(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "CuratedTravelSign"
	label.text = text
	label.font_size = 30
	label.pixel_size = 0.009
	label.modulate = Options.CREAM
	label.position = at
	add_child(label)
