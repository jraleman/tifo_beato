extends Node3D

## Five section batches carry 11 to 3,000 representative fans, not narrative counts.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const SHADER = preload("res://games/tifo_beato/world/crowd.gdshader")
var seats: Array[Transform3D] = []
var sections: Array[MultiMeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var count := 11
var primary := Options.BUCKET
var secondary := Options.NAVY
var scarf_pattern := 0

func _init(fan_count := 11) -> void:
	count = clampi(fan_count, 11, 3000)

func _ready() -> void:
	var figure := fan_mesh()
	var columns := 6 if count == 11 else 50
	var rows := ceili(float(count) / columns)
	for section in 5:
		var number := (count + 4 - section) / 5
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = figure
		multi.instance_count = number
		var node := MultiMeshInstance3D.new()
		node.name = "CurvaSection%d" % section
		node.multimesh = multi
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("primary", primary)
		material.set_shader_parameter("secondary", secondary)
		material.set_shader_parameter("scarf_pattern", scarf_pattern)
		node.material_override = material
		add_child(node)
		sections.append(node)
		materials.append(material)
		for local in number:
			var index := local * 5 + section
			var col := index % columns
			var row := index / columns
			var at := Vector3((col - (columns - 1) * 0.5) * (1.25 if count == 11 else 0.78),
				0.9 + (row if count == 11 else row / 5) * 0.43,
				-9.0 - row * (1.6 if count == 11 else 0.25))
			var scale_factor := 1.0 if count == 11 else 0.42
			var transform := Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), at)
			multi.set_instance_transform(local, transform)
			multi.set_instance_color(local, Color.WHITE)
			multi.set_instance_custom_data(local, Color(
				float((index * 7919) % 1009) / 1009.0, float(index % 2), 0, 1))
			while seats.size() <= index:
				seats.append(Transform3D.IDENTITY)
			seats[index] = transform

func present(energy: float, sync_value: float, scatter_value: float,
	time: float, tier: int, reduced: bool) -> void:
	for material in materials:
		material.set_shader_parameter("energy", energy)
		material.set_shader_parameter("sync", sync_value)
		material.set_shader_parameter("scatter", scatter_value)
		material.set_shader_parameter("clock", 0.0 if reduced else time)
		material.set_shader_parameter("raised", 1.0 if tier > 0 else energy / 140.0)
		material.set_shader_parameter("reduced_motion", reduced)
		material.set_shader_parameter("scarf_pattern", scarf_pattern)
		material.set_shader_parameter("primary", primary)
		material.set_shader_parameter("secondary", secondary)

static func fan_mesh() -> ArrayMesh:
	var builder := Builder.new()
	builder.box(Vector3(0, 0.9, 0), Vector3(0.65, 0.85, 0.45), Color(0.3, 0.4, 0.6, 0.8))
	for side in [-1, 1]:
		builder.box(Vector3(side * 0.2, 0.3, 0), Vector3(0.24, 0.6, 0.28), Color("30343a"))
		builder.cylinder(Vector3(side * 0.5, 1.0, 0), 0.13, 0.75,
			Color(0.86, 0.65, 0.48, 0.25), Vector3(0, 0, side * 0.25), 8)
	builder.ellipsoid(Vector3(0, 1.65, 0), Vector3(0.72, 0.78, 0.68), Color("dfa77d"))
	builder.box(Vector3(0, 1.31, 0.28), Vector3(0.85, 0.2, 0.12), Color(1, 1, 1, 0.5))
	builder.box(Vector3(-0.25, 1.1, 0.3), Vector3(0.18, 0.45, 0.12), Color(1, 1, 1, 0.5))
	for side in [-1, 1]:
		builder.box(Vector3(side * 0.16, 1.75, 0.32), Vector3(0.22, 0.09, 0.06), Options.NAVY)
	return builder.finish()
