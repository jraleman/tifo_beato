extends RefCounted

## CPU capos perform ordinary acoustic frames; the judge has no CPU shortcut.

const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
var notes: Array[Dictionary] = []
var _attacked: Dictionary = {}

func _init(pattern: Array[Dictionary] = [], accuracy := 1.0, seed_value := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for source in pattern:
		var note := source.duplicate(true)
		if rng.randf() > accuracy:
			continue
		note["t"] = float(note["t"]) + (
			rng.randf_range(-0.07, 0.07) if accuracy < 1.0 else 0.0)
		notes.append(note)

func frame_at(time: float) -> Frame:
	var level := 0.0
	var flux := 0.0
	var voiced := false
	var cents := 0.0
	for index in notes.size():
		var note := notes[index]
		var start := float(note["t"])
		var kind := str(note["kind"])
		var duration := maxf(0.22, float(note.get("duration", 0.3)))
		if kind == "rest":
			continue
		if time >= start and time < start + (0.04 if kind == "beat" else duration):
			level = 1.0
			voiced = kind == "sing" or (
				kind == "hold" and str(note.get("hold_kind", "shout")) == "sing")
			cents = int(note.get("band", 0)) * 500.0
			if not _attacked.has(index):
				_attacked[index] = true
				flux = 1.0
	return Frame.new(time, level, flux, voiced, cents, 1.0 if voiced else 0.0)
