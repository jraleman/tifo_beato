extends RefCounted

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")

static func make(id: String) -> ArrayMesh:
	var builder := Builder.new()
	var tin := id.ends_with("tin")
	var bass := id.ends_with("bass")
	var golden := id.ends_with("golden")
	var height := 0.42 if tin else (1.1 if bass else 0.8)
	var radius := 0.6 if tin else (0.85 if bass else 0.48)
	var color := Color("d64541") if tin else (Options.NAVY if bass else (
		Options.BUCKET if golden else Color("8c8f94")))
	builder.cylinder(Vector3(0, height * 0.5, 0), radius, height, color,
		Vector3.ZERO, 16, 1.0 if bass or tin else 1.12)
	builder.cylinder(Vector3(0, height + 0.015, 0), radius * 1.12, 0.055, Options.CREAM)
	builder.beam(Vector3(-0.15, height + 0.04, -0.2),
		Vector3(0.4, height + 0.18, 0.25), 0.065, Color("ad855a"))
	builder.beam(Vector3(0.15, height + 0.05, -0.2),
		Vector3(-0.4, height + 0.16, 0.25), 0.065, Color("ad855a"))
	if bass:
		for index in 8:
			var angle := index * TAU / 8.0
			builder.box(Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius),
				Vector3(0.08, height, 0.08), Color("8c8f94"))
	elif golden:
		for index in 8:
			builder.cylinder(Vector3(cos(index * TAU / 8) * 0.5, 0.4,
				sin(index * TAU / 8) * 0.5), 0.055, 0.7, Color("ae873c"))
	return builder.finish()
