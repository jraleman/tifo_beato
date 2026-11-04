extends RefCounted

## Best ritual performances merge; repeating a ritual cannot stack its bonus.

const Chart = preload("res://games/tifo_beato/chart/chant_chart.gd")
const Phrase = preload("res://games/tifo_beato/chart/chant_phrase.gd")
const Chants = preload("res://games/tifo_beato/chart/chants.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const RITUALS := ["mural", "rehearsal", "pub", "bakery", "barber"]
const TITLES := ["Paint the community mural", "Rehearse the derby chants",
	"Rally the pub quiz", "Rally the bakery", "Rally the barber"]

static func record(preparation: Dictionary, ritual: String, quality: float) -> void:
	assert(ritual in RITUALS, "Unknown derby ritual.")
	preparation[ritual] = maxf(float(preparation.get(ritual, 0.0)),
		clampf(quality, 0.0, 100.0))

static func bonuses(preparation: Dictionary) -> Dictionary:
	var total := 0.0
	for ritual in RITUALS:
		total += clampf(float(preparation.get(ritual, 0.0)), 0.0, 100.0) / 100.0
	return {"morale": roundi(total * 5.0), "crowd_scale": 1.0 + total * 0.05,
		"fans": roundi(total * 0.05 * int(Options.GROUNDS[3]["crowd"]))}

static func charts(ritual: String) -> Array[Chart]:
	if ritual == "rehearsal":
		var originals: Array[Chart] = []
		for chant in Chants.all():
			if chant.pool == 4:
				originals.append(chant)
				if originals.size() == 2:
					break
		return originals
	var chant := Chart.new()
	chant.id = "derby_" + ritual
	chant.title = TITLES[RITUALS.find(ritual)]
	chant.tempo = 100.0
	for line in 3:
		var phrase := Phrase.new()
		phrase.lyric = {"pub": "ELEVEN STRONG! THE QUIZ CAN WAIT.",
			"bakery": "SCARVES UP! SAVE US A ROLL.",
			"barber": "KEEP IT GOING! ONE LAST TRIM."}[ritual]
		phrase.call_beats = 8.0
		phrase.response_beats = 4.0
		for pulse in [0, 1, 2, 4, 6]:
			phrase.notes.append({"beat": float(pulse),
				"kind": "sing" if pulse == 4 else "beat",
				"duration": 0.75 if pulse == 4 else 0.0,
				"band": line - 1, "hold_kind": "sing"})
		phrase.notes.append({"beat": 7.0, "kind": "rest", "duration": 1.0,
			"band": 0, "hold_kind": "shout"})
		chant.phrases.append(phrase)
	return [chant]

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		var quality: Variant = value[key]
		if key not in RITUALS or not (quality is int or quality is float) \
			or not is_finite(float(quality)) or float(quality) < 0.0 or float(quality) > 100.0:
			return false
	return true
