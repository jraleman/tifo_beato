extends RefCounted

## Adapted batching primitives; original toy details use one lit vertex-color surface.

var _surface := SurfaceTool.new()
var _count := 0

func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func box(at: Vector3, dimensions: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_append(mesh, Transform3D(Basis.from_euler(rotation), at), color)

func cylinder(at: Vector3, radius: float, height: float, color: Color,
	rotation := Vector3.ZERO, segments := 12, top_ratio := 1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * top_ratio
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	_append(mesh, Transform3D(Basis.from_euler(rotation), at), color)

func ellipsoid(at: Vector3, dimensions: Vector3, color: Color, segments := 10) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 4
	_append(mesh, Transform3D(Basis.from_scale(dimensions), at), color)

func beam(a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, a.distance_to(b), thickness)
	_append(mesh, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())),
		(a + b) * 0.5), color)

func finish() -> ArrayMesh:
	assert(_count > 0, "A toy mesh must contain geometry.")
	_surface.index()
	return _surface.commit()

func _append(mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index in indices:
		_surface.set_color(color)
		_surface.set_normal((normal_basis * normals[index]).normalized())
		_surface.add_vertex(transform * vertices[index])
		_count += 1

static func material() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.roughness = 0.86
	return result

static func instance(mesh: Mesh, parent: Node3D, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material()
	parent.add_child(node)
	return node
