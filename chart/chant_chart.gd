extends Resource

## Original relative-contour charts, independent of any audio recording.

const Phrase = preload("res://games/tifo_beato/chart/chant_phrase.gd")
@export var id := ""
@export var title := ""
@export var tempo := 100.0
@export var pool := 0
@export var response_style := 0
@export var phrases: Array[Phrase] = []

func duration_beats() -> float:
	var total := 0.0
	for phrase in phrases:
		total += phrase.call_beats + (0.0 if phrase.sustain else phrase.response_beats)
	return total

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if tempo < 60.0 or tempo > 180.0 or phrases.is_empty():
		errors.append("Invalid tempo or empty chart: " + id)
	for phrase in phrases:
		for note in phrase.notes:
			var beat := float(note["beat"])
			if absf(beat * 4.0 - roundf(beat * 4.0)) > 0.0001:
				errors.append("Off-grid note: " + id)
			if beat < 0.0 or beat + float(note.get("duration", 0.0)) > phrase.call_beats:
				errors.append("Note outside its call: " + id)
	return errors
