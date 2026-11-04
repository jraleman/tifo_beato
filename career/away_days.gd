extends RefCounted

## Travel is optional preparation, never a new gate on an existing career.

const Chart = preload("res://games/tifo_beato/chart/chant_chart.gd")
const Phrase = preload("res://games/tifo_beato/chart/chant_phrase.gd")
const TITLES := {"bus": "Bus singalong", "station": "Station echo",
	"hostile": "Hostile away end"}

static func is_away(stop: int) -> bool:
	return stop % 2 == 1

static func chart(kind: String, tempo := 100) -> Chart:
	assert(kind in ["bus", "station"], "Unknown travel stage.")
	var result := Chart.new()
	result.id = "away_" + kind
	result.title = TITLES[kind]
	result.tempo = clampi(tempo, 60, 180)
	for line in (4 if kind == "bus" else 16):
		var phrase := Phrase.new()
		if kind == "bus":
			phrase.lyric = "WIPERS: BEAT. POTHOLE: REST. SCARVES UP!"
			phrase.call_beats = 8.0
			phrase.response_beats = 4.0
			for pulse in 6:
				phrase.notes.append(_note(float(pulse), "sing" if pulse == 4 else "beat",
					0.5 if pulse == 4 else 0.0, line % 3 - 1))
			phrase.notes.append(_note(6.0, "rest", 2.0))
		else:
			phrase.lyric = "CALL. ONE BEAT. LET THE STATION ANSWER."
			phrase.call_beats = 1.0
			phrase.response_beats = 2.0
			var kind_name: String = ["beat", "shout", "sing"][line % 3]
			phrase.notes.append(_note(0.0, kind_name,
				0.5 if kind_name != "beat" else 0.0, line % 3 - 1))
		result.phrases.append(phrase)
	return result

static func configuration(kind: String, tempo := 100) -> Dictionary:
	return {"custom_charts": [chart(kind, tempo)], "single_pass": true,
		"walkin_seconds": 1.5, "practice": true, "response_rests": kind == "station"}

static func _note(beat: float, kind: String, duration := 0.0, band := 0) -> Dictionary:
	return {"beat": beat, "kind": kind, "duration": duration,
		"band": band, "hold_kind": "sing" if kind == "sing" else "shout"}
