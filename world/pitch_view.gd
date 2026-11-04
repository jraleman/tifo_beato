extends Node3D

## Toy players and ball read the five-zone match; energy effects are visible poses.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Sim = preload("res://games/tifo_beato/match/match_sim.gd")
var players: MultiMeshInstance3D
var ball: MeshInstance3D
var _glow: MultiMeshInstance3D

func _ready() -> void:
	var figure := Builder.new()
	figure.box(Vector3(0, 0.6, 0), Vector3(0.55, 0.7, 0.38), Color.WHITE)
	figure.ellipsoid(Vector3(0, 1.2, 0), Vector3.ONE * 0.55, Color.WHITE)
	figure.box(Vector3(0, 0.2, 0), Vector3(0.55, 0.4, 0.32), Color("30343a"))
	players = _multi(figure.finish(), 14, "ToyFootballers")
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	ball = MeshInstance3D.new()
	ball.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff6d8")
	ball.material_override = material
	ball.name = "HeavyToyBall"
	add_child(ball)
	var flames := Builder.new()
	flames.cylinder(Vector3(0, 0.7, 0), 0.4, 1.6, Color("f4c430"),
		Vector3.ZERO, 6, 0.0)
	_glow = _multi(flames.finish(), 7, "CartoonEnergyFlames")
	_glow.visible = false

func present(sim: Sim, energy: float, time: float, reduced: bool) -> void:
	if players == null:
		return
	for index in 14:
		var home := index < 7
		var slot := index % 7
		var x := (slot % 3 - 1) * 5.4 + (sim.zone - 2) * 2.2
		var z := 4.2 + slot / 3 * 5.7 + (1.8 if home else 0.0)
		if slot == 6:
			x = -17.0 if home else 17.0
			z = 11.0
			if not home and energy >= 70.0 and not reduced:
				x += sin(time * 20.0) * 0.12
		else:
			x += sin(time * 2.5 + index) * (0.0 if reduced else 0.6)
		var transform := Transform3D(Basis.IDENTITY, Vector3(x, 0.15, z))
		players.multimesh.set_instance_transform(index, transform)
		players.multimesh.set_instance_color(index, Color("f4c430") if home else Color("d64541"))
		if home:
			_glow.multimesh.set_instance_transform(index, transform)
	var possession := -1.0 if sim.home_possession else 1.0
	ball.position = Vector3((sim.zone - 2) * 7.0, 0.43, 11 + (0.0 if reduced else sin(time * 2.0) * 2.0))
	ball.scale = Vector3(1.0, 0.75, 1.0) if energy > 50.0 and possession > 0 else Vector3.ONE
	_glow.visible = energy >= 70.0

func _multi(mesh: Mesh, count: int, node_name: String) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	node.material_override = Builder.material()
	add_child(node)
	return node
