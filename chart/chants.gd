extends RefCounted

## Twenty-four newly authored rhythm/contour studies, not existing terrace tunes.

const Chart = preload("res://games/tifo_beato/chart/chant_chart.gd")
const Phrase = preload("res://games/tifo_beato/chart/chant_phrase.gd")
const TITLES := [
	"Bucket Overture", "Eleven Strong", "Kevin Keeps Time", "Spoons Aloft", "Rec Refrain",
	"Grey Scarf Morning", "The Long Way Home", "Tea Before Kickoff", "Fence Lullaby", "Old Gold",
	"Tin Roof Roll", "Four Wooden Spoons", "Bass Drum Parade", "Double Bucket", "Terrace Engine",
	"Cards to the Sky", "Paint the Stand", "The Folded Flag", "Mosaic Morning", "Fringe Benefits",
	"Kazoo Orbit", "Seagull Shuffle", "Beach Ball Bounce", "The Curva Comet",
]
const TEMPOS := [
	100, 108, 96, 112, 104, 78, 84, 90, 74, 94, 138, 150, 132, 162, 144,
	106, 114, 98, 118, 110, 126, 142, 120, 156,
]

static func all() -> Array[Chart]:
	var charts: Array[Chart] = []
	for index in TITLES.size():
		charts.append(make(index))
	return charts

static func make(index: int) -> Chart:
	assert(index >= 0 and index < TITLES.size(), "Unknown original chant.")
	var chart := Chart.new()
	chart.id = "tb_chant_%02d" % (index + 1)
	chart.title = TITLES[index]
	chart.tempo = TEMPOS[index]
	chart.pool = mini(4, index / 5)
	for verse in 2:
		var phrase := Phrase.new()
		phrase.lyric = ["FOR-ZA {CLUB}!", "THE SCARVES GO UP!", "KEEP THE BUCKET GOING!"][
			(index + verse) % 3]
		var band := ((index + verse) % 3) - 1
		match chart.pool:
			1:
				phrase.sustain = verse == 1
				phrase.notes = [_note(0.0, "sing", 1.5, band),
					_note(2.0, "hold", 2.0, 0, "sing"),
					_note(4.5, "sing", 1.5, -band), _note(6.5, "rest", 1.0)]
			2:
				var spacing := 0.25 if (index + verse) % 2 else 0.5
				for hit in roundi(6.0 / spacing):
					phrase.notes.append(_note(hit * spacing, "beat"))
				phrase.notes.append(_note(6.0, "shout", 0.5))
				phrase.notes.append(_note(7.0, "rest", 0.5))
			3:
				phrase.notes = [_note(0.0, "beat"), _note(0.75, "beat"),
					_note(1.5, "shout", 0.5), _note(2.5, "beat"),
					_note(3.0, "rest", 0.75), _note(4.0, "sing", 1.0, band),
					_note(5.5, "beat"), _note(6.0, "rest", 1.0)]
			4:
				phrase.notes = [_note(0.0, "beat"), _note(0.5, "beat"),
					_note(1.25, "shout", 0.5), _note(2.5, "sing", 0.75, band),
					_note(3.75, "beat"), _note(4.5, "hold", 1.0, -band, "sing"),
					_note(6.0, "rest", 1.0)]
			_:
				phrase.notes = [_note(0.0, "beat"), _note(1.0, "shout", 0.5),
					_note(2.0 + verse * 0.25, "beat"), _note(3.0, "sing", 0.75, band),
					_note(4.5, "hold", 1.0, 0, "shout"), _note(6.0, "rest", 1.0)]
		chart.phrases.append(phrase)
	return chart

static func _note(beat: float, kind: String, duration := 0.0, band := 0,
	hold_kind := "shout") -> Dictionary:
	return {"beat": beat, "kind": kind, "duration": duration, "band": band,
		"hold_kind": hold_kind}
