extends RefCounted

## Sustains keep their onset timestamp so classification delay is not timing error.

const ONSET := &"onset"
const CLAP := &"clap"
const SHOUT := &"shout"
const SING := &"sing"
const SILENCE := &"silence"
var t := 0.0
var end_t := 0.0
var kind: StringName = ONSET
var band := 0
var level := 0.0
var duration := 0.0
var voiced := false

func _init(time := 0.0, event_kind: StringName = ONSET, amplitude := 1.0,
	pitch_band := 0, held_seconds := 0.0, is_voiced := false) -> void:
	t = time
	end_t = time + held_seconds
	kind = event_kind
	level = amplitude
	band = pitch_band
	duration = held_seconds
	voiced = is_voiced
