extends Node3D

## Painted wood, felt pitch and invented skylines, all batched into one surface.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
var ground := 0

func _init(index := 0) -> void:
	ground = clampi(index, 0, 4)

func _ready() -> void:
	var builder := Builder.new()
	var wood := Color("ad855a")
	var concrete := Color("8c8f94")
	builder.box(Vector3(0, -0.65, 0), Vector3(48, 1.2, 51), wood)
	builder.box(Vector3(0, 0, 11), Vector3(37, 0.18, 25), Options.PITCH)
	for stripe in 10:
		builder.box(Vector3(-16.65 + stripe * 3.7, 0.11, 11),
			Vector3(3.7, 0.015, 25), Color("569e4e") if stripe % 2 else Color("4a9145"))
	for z in [-1.5, 23.5]:
		builder.box(Vector3(0, 0.14, z), Vector3(37, 0.035, 0.12), Options.CREAM)
	for x in [-18.5, 0.0, 18.5]:
		builder.box(Vector3(x, 0.14, 11), Vector3(0.12, 0.035, 25), Options.CREAM)
	for side in [-1, 1]:
		var x: float = side * 18.8
		for z in [8.5, 13.5]:
			builder.beam(Vector3(x, 0.2, z), Vector3(x, 2.4, z), 0.16, Options.CREAM)
		builder.beam(Vector3(x, 2.4, 8.5), Vector3(x, 2.4, 13.5), 0.16, Options.CREAM)
		for line in 9:
			builder.beam(Vector3(x + side * 0.7, 0.2, 8.5 + line * 0.625),
				Vector3(x + side * 0.7, 2.3, 8.5 + line * 0.625), 0.03, Color("ddd5bd"))
	var steps := 3 if ground == 0 else 12
	for row in steps:
		builder.box(Vector3(0, 0.5 + row * 0.43, -9.0 - row * 1.25),
			Vector3(12 if ground == 0 else 42, 0.8, 1.6), concrete)
	for post in range(-6, 7):
		builder.cylinder(Vector3(post * 1.7, 1.5, -5.8), 0.06, 3.0, Options.NAVY)
	builder.beam(Vector3(-11, 2.3, -5.8), Vector3(11, 2.3, -5.8), 0.1, Options.NAVY)
	builder.box(Vector3(0, 1.2, -5.3), Vector3(2.7, 0.25, 1.6), wood)
	for side in [-1, 1]:
		builder.cylinder(Vector3(side * 22, 5.0, -15), 0.18, 10.0, Options.NAVY)
		builder.box(Vector3(side * 22, 10.0, -15), Vector3(2.8, 1.0, 0.5), Options.CREAM)
		for bulb in 4:
			builder.ellipsoid(Vector3(side * 22 - 0.9 + bulb * 0.6, 10.0, -14.7),
				Vector3.ONE * 0.3, Color.WHITE)
	if ground == 0:
		builder.box(Vector3(-9, 1.2, -18), Vector3(5, 2.6, 3.0), Color("ae573e"))
		builder.box(Vector3(-9, 2.8, -18), Vector3(5.6, 0.5, 3.6), Options.NAVY)
	elif ground == 1:
		for chimney in 3:
			builder.cylinder(Vector3(-14 + chimney * 12, 6.0, -24), 1.1,
				12.0 + chimney, Color("a75535"))
	elif ground == 2:
		for column in range(-4, 5):
			builder.cylinder(Vector3(column * 5, 5.0, -25), 0.65, 10.0, Options.CREAM)
		builder.box(Vector3(0, 10.2, -25), Vector3(43, 0.8, 2.0), Color("b67c58"))
	elif ground == 3:
		for rib in range(-5, 6):
			builder.beam(Vector3(rib * 4, 0, -24), Vector3(rib * 4, 12, -20), 0.24, wood)
			builder.beam(Vector3(rib * 4, 12, -20), Vector3(rib * 4, 12, -5), 0.24, wood)
		builder.box(Vector3(0, 12.2, -17), Vector3(44, 0.4, 18), Options.NAVY)
	else:
		for building in 11:
			var height := 4.0 + (building * 7 % 6)
			builder.box(Vector3(-23 + building * 4.5, height / 2, -25),
				Vector3(3, height, 2), Color("735d85"))
			builder.cylinder(Vector3(-23 + building * 4.5, height + 0.9, -25),
				0.8, 1.8, Color("f29045"), Vector3.ZERO, 6, 0.0)
	Builder.instance(builder.finish(), self, "PaintedGround")
	var label := Label3D.new()
	label.name = "GroundSign"
	label.text = str(Options.GROUNDS[ground]["title"]).to_upper()
	label.font_size = 48
	label.pixel_size = 0.015
	label.position = Vector3(0, 4.0 if ground == 0 else 8.0, -12 if ground == 0 else -23)
	label.modulate = Options.CREAM
	label.outline_size = 8
	add_child(label)
