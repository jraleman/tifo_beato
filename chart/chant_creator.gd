extends RefCounted

## Only bounded musical data crosses the clipboard, never Resources or recorded audio.

const Chart = preload("res://games/tifo_beato/chart/chant_chart.gd")
const Phrase = preload("res://games/tifo_beato/chart/chant_phrase.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Words = preload("res://games/tifo_beato/career/word_list.gd")
const KINDS := ["beat", "shout", "sing", "hold", "rest"]
const RESPONSES := ["Echo", "Clapback", "Harmony"]
const MAX_NOTES := 64
const MAX_CODE := 8192
const SLOTS := 8
const VOICE_SECONDS := Classifier.SUSTAIN_SECONDS + 0.01
var tempo := 100
var bars := 2
var lyric := 0
var response := 0
var notes: Array[Array] = []
var recording_start := 0.0
var recording := false

func payload() -> Dictionary:
	return {"v": 1, "tempo": tempo, "bars": bars, "lyric": lyric,
		"response": response, "notes": notes.duplicate(true)}

func restore(value: Dictionary) -> String:
	var error := validate(value)
	if not error.is_empty():
		return error
	tempo = int(value["tempo"])
	bars = int(value["bars"])
	lyric = int(value["lyric"])
	response = int(value["response"])
	notes.assign(canonical(value)["notes"])
	return ""

func begin(at: float) -> void:
	notes.clear()
	recording_start = at
	recording = true

func capture(events: Array[Event]) -> void:
	if not recording:
		return
	var beat_seconds := 60.0 / tempo
	for event in events:
		if event.kind not in [Event.ONSET, Event.SHOUT, Event.SING]:
			continue
		var grid := roundi((event.t - recording_start) / beat_seconds * 4.0)
		if grid < 0 or grid >= bars * 16:
			continue
		var kind := 0 if event.kind == Event.ONSET else (2 if event.kind == Event.SING else 1)
		var duration := 0 if kind == 0 else maxi(ceili(VOICE_SECONDS / beat_seconds * 4.0),
			roundi(maxf(0.2, event.duration) / beat_seconds * 4.0))
		duration = mini(duration, bars * 16 - grid)
		var held := duration >= 8
		var existing := -1
		for index in notes.size():
			if int(notes[index][1]) == grid:
				existing = index
				break
		var note: Array = [3 if held else kind, grid, duration,
			clampi(event.band, -1, 1), 1 if event.voiced else 0]
		if existing >= 0:
			if kind > 0 or int(notes[existing][0]) == 0:
				notes[existing] = note
		elif notes.size() < MAX_NOTES:
			notes.append(note)
	notes.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))

func put_note(note: Array, index := -1) -> String:
	var edited := payload()
	var entries: Array = edited["notes"]
	if index >= 0 and index < entries.size():
		entries[index] = note.duplicate()
	else:
		entries.append(note.duplicate())
	var error := validate(edited)
	if not error.is_empty():
		return error
	notes.assign(entries)
	notes.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	return ""

func to_chart(empty := false) -> Chart:
	var chart := Chart.new()
	chart.id = "creator_" + JSON.stringify(payload()).sha256_text().left(12)
	chart.title = Words.BANNERS[lyric] + " - YOUR CHANT"
	chart.tempo = tempo
	chart.response_style = response
	var phrase := Phrase.new()
	phrase.lyric = Words.BANNERS[lyric]
	phrase.call_beats = bars * 4.0
	phrase.response_beats = maxf(4.0, phrase.call_beats * 0.5) if response == 1 \
		else phrase.call_beats
	if not empty:
		for note in notes:
			phrase.notes.append({"kind": KINDS[int(note[0])], "beat": int(note[1]) / 4.0,
				"duration": int(note[2]) / 4.0, "band": int(note[3]),
				"hold_kind": "sing" if int(note[4]) == 1 else "shout"})
	chart.phrases.append(phrase)
	return chart

func code() -> String:
	var text := JSON.stringify(payload())
	return "TB1." + Marshalls.raw_to_base64(text.to_utf8_buffer()) + "." + text.sha256_text().left(8)

static func decode(code_text: String) -> Dictionary:
	if code_text.length() > MAX_CODE:
		return {"error": "Chant code is too long."}
	var parts := code_text.strip_edges().split(".")
	if parts.size() != 3 or parts[0] != "TB1" or parts[2].length() != 8:
		return {"error": "Use a complete TB1 chant code."}
	var encoded := str(parts[1])
	if encoded.is_empty() or encoded.length() % 4 != 0:
		return {"error": "Chant code is truncated."}
	for character in encoded:
		if character not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=":
			return {"error": "Chant code contains an invalid character."}
	var padding := encoded.find("=")
	if padding >= 0 and (padding < encoded.length() - 2 \
		or encoded.substr(padding).replace("=", "") != ""):
		return {"error": "Chant code has invalid padding."}
	var bytes := Marshalls.base64_to_raw(encoded)
	if Marshalls.raw_to_base64(bytes) != encoded:
		return {"error": "Chant code is not canonical Base64."}
	for byte in bytes:
		if byte < 32 or byte > 126:
			return {"error": "Chant code must contain only musical JSON data."}
	var text := bytes.get_string_from_ascii()
	if text.sha256_text().left(8) != parts[2]:
		return {"error": "Chant code checksum does not match."}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"error": "Chant code is not valid musical data."}
	var error := validate(parser.data)
	return {"error": error, "data": canonical(parser.data)} if error.is_empty() else {"error": error}

static func canonical(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in ["v", "tempo", "bars", "lyric", "response"]:
		result[field] = int(value[field])
	var entries: Array[Array] = []
	for note: Array in value["notes"]:
		var row: Array = []
		for number: Variant in note:
			row.append(int(number))
		entries.append(row)
	result["notes"] = entries
	return result

static func validate(value: Variant) -> String:
	if not value is Dictionary:
		return "A chant must contain musical data."
	for field in ["v", "tempo", "bars", "lyric", "response"]:
		if not integer(value.get(field)):
			return "Chant settings must be whole numbers."
	if int(value["v"]) != 1:
		return "Unsupported chant version."
	if int(value["tempo"]) < 60 or int(value["tempo"]) > 180 \
		or int(value["bars"]) < 1 or int(value["bars"]) > 8:
		return "Use 60-180 BPM and 1-8 bars."
	if int(value["lyric"]) < 0 or int(value["lyric"]) >= Words.BANNERS.size() \
		or int(value["response"]) < 0 or int(value["response"]) >= RESPONSES.size():
		return "Choose curated lyrics and a known response style."
	var entries: Variant = value.get("notes")
	if not entries is Array or entries.is_empty() or entries.size() > MAX_NOTES:
		return "A chant needs 1-64 notes."
	var limit := int(value["bars"]) * 16
	for note: Variant in entries:
		if not note is Array or note.size() != 5:
			return "Invalid note data."
		for number: Variant in note:
			if not integer(number):
				return "Notes must lie on the sixteenth grid."
		if int(note[0]) < 0 or int(note[0]) >= KINDS.size() \
			or int(note[1]) < 0 or int(note[1]) >= limit \
			or int(note[2]) < 0 or int(note[1]) + int(note[2]) > limit \
			or int(note[3]) < -1 or int(note[3]) > 1 or int(note[4]) not in [0, 1]:
			return "A note falls outside its chant."
		if int(note[0]) == 0 and int(note[2]) != 0 \
			or int(note[0]) != 0 and int(note[2]) == 0:
			return "Only Beats have zero duration."
		if int(note[0]) in [1, 2, 3] \
			and int(note[2]) * 60.0 / (int(value["tempo"]) * 4.0) < VOICE_SECONDS - 0.000001:
			return "Shout, Sing and Hold notes need at least 160 ms at the chosen tempo."
	for index in entries.size():
		var first: Array = entries[index]
		for later in range(index + 1, entries.size()):
			var second: Array = entries[later]
			var overlap := int(first[1]) < int(second[1]) + maxi(1, int(second[2])) \
				and int(second[1]) < int(first[1]) + maxi(1, int(first[2]))
			if overlap and (int(first[0]) == 4 or int(second[0]) == 4 \
				or int(first[0]) > 0 and int(second[0]) > 0 \
				or int(first[1]) == int(second[1])):
				return "Leave Rests silent and separate conflicting attacks."
	return ""

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value))
