extends Node3D

## Chunky original fence rig; the same outfit dresses gameplay and shell previews.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Drum = preload("res://games/tifo_beato/world/drum_model.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
var player_color := Color("4da3ff")
var primary := Options.BUCKET
var outfit: Dictionary = {}
var crest := 0
var rival := -1
var _arm: Node3D
var _body: Node3D
var _built := false

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_body = Node3D.new()
	_body.name = "ToyCapoBody"
	add_child(_body)
	var builder := Builder.new()
	var skin := Color("dfa77d")
	var coat := primary
	if str(outfit.get("jacket", "")).ends_with("bomber"):
		coat = Options.NAVY
	elif str(outfit.get("jacket", "")).ends_with("fur"):
		coat = Color("ad855a")
	builder.box(Vector3(0, 1.1, 0), Vector3(0.8, 1.1, 0.6), coat)
	for side in [-1, 1]:
		builder.box(Vector3(side * 0.25, 0.4, 0), Vector3(0.28, 0.8, 0.32), Options.NAVY)
		builder.box(Vector3(side * 0.25, 0.08, 0.14), Vector3(0.4, 0.18, 0.55), Color("30343a"))
	builder.ellipsoid(Vector3(0, 1.95, 0), Vector3(0.9, 0.95, 0.85), skin)
	for side in [-1, 1]:
		builder.box(Vector3(side * 0.18, 2.02, 0.39), Vector3(0.14, 0.1, 0.06), Color("30343a"))
		builder.box(Vector3(side * 0.2, 2.17, 0.4), Vector3(0.3, 0.1, 0.09),
			Options.NAVY, Vector3(0, 0, side * 0.15))
	builder.box(Vector3(0, 1.65, 0.34), Vector3(0.94, 0.22, 0.13), player_color)
	builder.box(Vector3(-0.3, 1.35, 0.36), Vector3(0.2, 0.65, 0.12), primary)
	var hat := str(outfit.get("hat", "tb_hat_bobble"))
	if hat.ends_with("cone"):
		builder.cylinder(Vector3(0, 2.65, 0), 0.48, 0.9, Color("f29045"), Vector3.ZERO, 10, 0.0)
	elif hat.ends_with("crown"):
		builder.cylinder(Vector3(0, 2.4, 0), 0.46, 0.25, Options.BUCKET)
		for side in [-1, 0, 1]:
			builder.cylinder(Vector3(side * 0.27, 2.65, 0.05), 0.1, 0.3,
				Options.BUCKET, Vector3.ZERO, 6, 0.0)
	elif hat.ends_with("fisher"):
		builder.ellipsoid(Vector3(0, 2.35, 0), Vector3(1.0, 0.32, 0.9), Options.NAVY)
		builder.box(Vector3(0, 2.3, 0.45), Vector3(1.0, 0.09, 0.55), Options.NAVY)
	else:
		builder.ellipsoid(Vector3(0, 2.35, 0), Vector3(1.0, 0.45, 0.95), primary)
		builder.ellipsoid(Vector3(0, 2.6, 0), Vector3.ONE * 0.28, Options.CREAM)
	if rival == 3:
		builder.box(Vector3(0, 1.86, 0.43), Vector3(0.5, 0.1, 0.06), Options.NAVY)
	Builder.instance(builder.finish(), _body, "PaintedCapo")
	var charge := Banner.new()
	charge.crest = crest
	charge.primary = primary
	var badge := MeshInstance3D.new()
	badge.name = "OriginalClubCharge"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.24)
	badge.mesh = quad
	badge.position = Vector3(0, 1.17, 0.306)
	var badge_material := StandardMaterial3D.new()
	badge_material.albedo_texture = ImageTexture.create_from_image(
		charge.render_image().get_region(Rect2i(61, 9, 46, 35)))
	badge_material.roughness = 1.0
	badge.material_override = badge_material
	_body.add_child(badge)
	_arm = Node3D.new()
	_arm.name = "MegaphoneArm"
	_arm.position = Vector3(0.47, 1.55, 0)
	_body.add_child(_arm)
	var arm := Builder.new()
	arm.cylinder(Vector3(0, -0.35, 0), 0.15, 0.8, coat)
	arm.ellipsoid(Vector3(0, -0.8, 0), Vector3.ONE * 0.34, skin)
	var mega := str(outfit.get("megaphone", "tb_mega_plastic"))
	var mega_color := Color("f29045") if mega.ends_with("cone") else (
		Options.BUCKET if mega.ends_with("megatron") or mega.ends_with("horn") else Options.CREAM)
	var mega_scale := 1.7 if mega.ends_with("megatron") else (1.35 if mega.ends_with("horn") else 1.0)
	arm.cylinder(Vector3(0, -0.78, 0.45), 0.13 * mega_scale, 0.8 * mega_scale, mega_color,
		Vector3(PI / 2.0, 0, 0), 12, 3.0)
	if mega.ends_with("cone"):
		arm.cylinder(Vector3(0, -0.78, 0.68), 0.27, 0.1, Options.CREAM,
			Vector3(PI / 2.0, 0, 0), 12, 1.0)
	Builder.instance(arm.finish(), _arm, "Megaphone")
	var drum := str(outfit.get("drum", "tb_drum_bucket"))
	var bucket := Builder.instance(Drum.make(drum), self, "OriginalBucketDrum")
	bucket.position = Vector3(-1.1, 0, 0.2)
	var scarf := str(outfit.get("scarf", "tb_scarf_bars"))
	var trim := Builder.new()
	if scarf.ends_with("checks"):
		for row in 3:
			for column in 4:
				if (row + column) % 2 == 0:
					trim.box(Vector3(-0.34 + column * 0.21, 1.58 + row * 0.08, 0.42),
						Vector3(0.18, 0.075, 0.025), Options.CREAM)
	elif scarf.ends_with("fringe"):
		for thread in 5:
			trim.box(Vector3(-0.39 + thread * 0.05, 0.98, 0.44),
				Vector3(0.03, 0.28, 0.025), Options.CREAM)
	if scarf != "tb_scarf_bars":
		Builder.instance(trim.finish(), _body, "ScarfPattern")
	if str(outfit.get("jacket", "")).ends_with("fur"):
		var fur := Builder.new()
		for side in [-1, 1]:
			fur.ellipsoid(Vector3(side * 0.42, 1.38, 0), Vector3.ONE * 0.55, Color("ad855a"))
		Builder.instance(fur.finish(), _body, "FauxFurCollar")
	if rival == 2:
		var arms := Builder.new()
		for index in 6:
			var angle := index * TAU / 6.0
			arms.beam(Vector3(0, 1.1, -0.1),
				Vector3(sin(angle) * 1.1, 1.1 + cos(angle) * 0.65, -0.1), 0.18, coat)
		Builder.instance(arms.finish(), _body, "EightToyArms")
	_built = true

func pose(energy: float, dead: bool, time: float, reduced: bool) -> void:
	if not _built:
		return
	_body.rotation.z = 0.2 if dead else 0.0
	_arm.rotation.x = 0.2 if dead else (-1.3 if reduced else -1.2 - minf(energy / 100.0, 1.0) * 0.2)
	_body.position.y = 0.0 if reduced or dead else sin(time * 5.0) * energy * 0.0008
