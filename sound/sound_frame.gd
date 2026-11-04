extends RefCounted

## Source-independent, normalized measurements on the sample/audio clock.

var t := 0.0
var level := 0.0
var flux := 0.0
var voiced := false
var cents := 0.0
var clarity := 0.0
var raw_level := 0.0

func _init(time := 0.0, amplitude := 0.0, onset_flux := 0.0,
	is_voiced := false, pitch_cents := 0.0, confidence := 0.0) -> void:
	t = time
	level = maxf(0.0, amplitude)
	raw_level = level
	flux = maxf(0.0, onset_flux)
	voiced = is_voiced
	cents = pitch_cents
	clarity = clampf(confidence, 0.0, 1.0)
