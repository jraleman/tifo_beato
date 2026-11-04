extends RefCounted

## Original toy props are shared by their gameplay, workshop and museum appearances.

const Builder = preload("res://games/tifo_beato/world/mesh_builder.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Capo = preload("res://games/tifo_beato/world/capo_rig.gd")
const Drum = preload("res://games/tifo_beato/world/drum_model.gd")

static func make(kind: String, primary := Options.BUCKET) -> Node3D:
	var root := Node3D.new()
	root.name = "Original_" + kind
	var builder := Builder.new()
	match kind:
		"bucket":
			Builder.instance(Drum.make("tb_drum_bucket"), root, "BucketAndTwoSpoons")
		"seagull":
			builder.ellipsoid(Vector3(0, 1.0, 0), Vector3(1.3, 0.7, 0.65), Options.CREAM)
			builder.ellipsoid(Vector3(0.5, 1.3, 0), Vector3.ONE * 0.5, Color.WHITE)
			builder.cylinder(Vector3(0.88, 1.25, 0), 0.14, 0.5, Color("f29045"),
				Vector3(0, 0, PI / 2), 6, 0.0)
			for side in [-1, 1]:
				builder.box(Vector3(0, 1.2, side * 0.85), Vector3(0.55, 0.1, 1.4),
					Color.WHITE, Vector3(side * 0.2, 0, 0))
				builder.box(Vector3(0, 1.2, side * 1.45), Vector3(0.5, 0.1, 0.25), Options.NAVY)
			builder.ellipsoid(Vector3(0.59, 1.35, 0.24), Vector3.ONE * 0.09, Options.NAVY)
		"beach_balls":
			for index in 5:
				builder.ellipsoid(Vector3((index - 2) * 0.8, 0.6 + index % 2 * 0.5, 0),
					Vector3.ONE * 0.9, primary if index % 2 == 0 else Color("69b3d0"))
				builder.box(Vector3((index - 2) * 0.8, 0.65 + index % 2 * 0.5, 0.44),
					Vector3(0.75, 0.12, 0.045), Options.CREAM)
		"ball":
			builder.ellipsoid(Vector3.ZERO, Vector3.ONE * 0.95, primary)
			builder.box(Vector3(0, 0, 0.46), Vector3(0.82, 0.13, 0.04), Options.CREAM)
		"umbrella", "rain":
			for index in 3:
				var x := (index - 1) * 1.6
				builder.cylinder(Vector3(x, 1.2, 0), 0.05, 2.4, Options.NAVY)
				builder.cylinder(Vector3(x, 2.2, 0), 0.85, 0.45,
					primary if index % 2 == 0 else Options.NAVY, Vector3.ZERO, 12, 0.0)
				builder.ellipsoid(Vector3(x, 2.5, 0), Vector3.ONE * 0.16, Options.CREAM)
		"flag":
			builder.cylinder(Vector3(-0.7, 2.8, 0), 0.075, 5.6, Color("ad855a"))
			builder.box(Vector3(0.7, 4.4, 0), Vector3(2.8, 1.7, 0.06), primary)
			for stripe in 3:
				builder.box(Vector3(0.7, 3.85 + stripe * 0.55, 0.05),
					Vector3(2.8, 0.2, 0.025), Options.NAVY)
		"kazoo", "kevin":
			var kevin := Capo.new()
			kevin.primary = Color("4f9d4a")
			root.add_child(kevin)
			builder.cylinder(Vector3(-0.15, 1.8, 0.85), 0.1, 0.8, Color("f48fb1"),
				Vector3(PI / 2, 0, 0), 8)
			builder.cylinder(Vector3(-0.15, 1.95, 0.8), 0.12, 0.2, Options.CREAM)
		"steward", "coat":
			builder.box(Vector3(0, 1.15, 0), Vector3(0.85, 1.2, 0.65), Color("a5cf56"))
			for side in [-1, 1]:
				builder.box(Vector3(side * 0.25, 0.4, 0), Vector3(0.3, 0.8, 0.35), Options.NAVY)
				builder.box(Vector3(side * 0.45, 1.1, 0), Vector3(0.25, 1.0, 0.3), Color("a5cf56"))
			builder.box(Vector3(0, 1.0, 0.35), Vector3(0.86, 0.14, 0.06), Options.CREAM)
			builder.ellipsoid(Vector3(0, 2.0, 0), Vector3.ONE * 0.85, Color("dfa77d"))
			builder.ellipsoid(Vector3(0, 2.4, 0), Vector3(1, 0.25, 0.8), Options.NAVY)
			builder.box(Vector3(0, 2.38, 0.45), Vector3(1.0, 0.1, 0.55), Options.NAVY)
			for side in [-1, 1]:
				builder.box(Vector3(side * 0.17, 2.04, 0.4), Vector3(0.11, 0.1, 0.06), Options.NAVY)
			builder.box(Vector3(0.55, 1.25, 0.45), Vector3(0.7, 0.9, 0.07), Color("ad855a"))
		"drum_skin":
			Builder.instance(Drum.make("tb_drum_bucket"), root, "SplitBucket")
			builder.beam(Vector3(-0.4, 0.86, -0.1), Vector3(0.1, 0.87, 0.1), 0.05, Options.NAVY)
			builder.beam(Vector3(0.1, 0.87, 0.1), Vector3(0.4, 0.87, -0.2), 0.05, Options.NAVY)
		"power_cut":
			for side in [-1, 1]:
				builder.cylinder(Vector3(side * 1.0, 1.6, 0), 0.08, 3.2, Options.NAVY)
				builder.box(Vector3(side * 1.0, 3.1, 0), Vector3(1.3, 0.6, 0.4), Color("8c8f94"))
				builder.box(Vector3(side * 1.0, 3.1, 0.25), Vector3(1.0, 0.35, 0.06), Color("30343a"))
		"air_horn", "trumpet":
			builder.cylinder(Vector3(0, 1.5, 0), 0.15, 2.0, Color("ae873c"),
				Vector3(0, 0, PI / 2), 12, 2.4)
			builder.box(Vector3(-0.6, 0.7, 0), Vector3(0.45, 1.0, 0.4),
				Color("d64541") if kind == "air_horn" else Options.NAVY)
			if kind == "trumpet":
				for valve in 3:
					builder.cylinder(Vector3(valve * 0.25 - 0.3, 1.7, 0), 0.06, 0.4, Options.CREAM)
		"rival_drums":
			for side in [-1, 1]:
				var drum := Builder.instance(Drum.make("tb_drum_tin"), root, "WrongTempo%d" % side)
				drum.position = Vector3(side * 0.7, 0.0, 0.0)
		"inflatable":
			builder.ellipsoid(Vector3(0, 2.8, 0), Vector3(3.2, 4.0, 2.0), Color("69b3d0"))
			for side in [-1, 1]:
				builder.ellipsoid(Vector3(side * 0.7, 3.7, 0.9), Vector3.ONE * 0.8, Options.CREAM)
				builder.ellipsoid(Vector3(side * 0.7, 3.7, 1.25), Vector3.ONE * 0.25, Options.NAVY)
			builder.box(Vector3(0, 2.4, 1.0), Vector3(2.0, 0.35, 0.1), primary)
		_:
			push_error("Tifo Beato: unknown prop " + kind)
			return root
	if kind not in ["bucket", "rival_drums"]:
		Builder.instance(builder.finish(), root, "PaintedToyProp")
	return root
