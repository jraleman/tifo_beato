extends RefCounted

## Seeded phrase sequencing keeps the exact notes when the tempo assist changes.

const Chants = preload("res://games/tifo_beato/chart/chants.gd")
const Chart = preload("res://games/tifo_beato/chart/chant_chart.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const HANDOFF_CAPTURE_TAIL := 0.58
const DISRUPTION_BEFORE := 0.75
const DISRUPTION_AFTER := 0.5
const DISRUPTION_TRANSIENT := 0.25
var phases: Array[Dictionary] = []
var notes: Array[Dictionary] = []
var beats: Array[float] = []
var duration := 0.0
var halftime_start := 0.0
var halftime_end := 0.0
var loop_count := 0
var speed := 1.0

func _init(seed_value := 1, pool := 0, speed_percent := 100, with_war := false,
	half_seconds := 120.0, walkin_seconds := 20.0) -> void:
	speed = clampf(float(speed_percent) / 100.0, 0.7, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var charts: Array[Chart] = []
	for chart in Chants.all():
		if chart.pool == pool:
			charts.append(chart)
	assert(not charts.is_empty(), "A group must have original chants.")
	phases.append({"t": 0.0, "end": walkin_seconds, "kind": "walkin",
		"lyric": "ELEVEN STRONG. FIND YOUR TEMPO.", "half": 1, "loop": -1, "beat": 0.6})
	duration = walkin_seconds
	for half in [1, 2]:
		var end_target := duration + half_seconds / speed
		while duration < end_target - 0.001:
			var chant := charts[rng.randi_range(0, charts.size() - 1)]
			var beat := 60.0 / chant.tempo / speed
			for phrase in chant.phrases:
				var start := duration
				var phase := {"t": start, "end": start + phrase.call_beats * beat,
					"kind": "sustain" if phrase.sustain else "call", "half": half,
					"lyric": phrase.lyric, "chant": chant.title, "loop": loop_count,
					"beat": beat, "template": phrase.notes.duplicate(true)}
				phases.append(phase)
				for note in phrase.notes:
					var entry := note.duplicate(true)
					entry["t"] = start + float(note["beat"]) * beat
					entry["duration"] = float(note["duration"]) * beat
					entry["phase"] = phases.size() - 1
					entry["id"] = notes.size()
					notes.append(entry)
				for pulse in ceili(phrase.call_beats):
					beats.append(start + pulse * beat)
				duration = float(phase["end"])
				if not phrase.sustain:
					phases.append({"t": duration, "end": duration + phrase.response_beats * beat,
						"kind": "response", "half": half, "lyric": phrase.lyric,
						"chant": chant.title, "loop": loop_count, "beat": beat,
						"call_phase": phases.size() - 1})
					duration += phrase.response_beats * beat
			loop_count += 1
		if half == 1:
			halftime_start = duration
			var break_seconds := 32.0
			if with_war:
				break_seconds = War.new(seed_value, 0, false,
					{"speed": speed_percent}).duration + 0.4
			phases.append({"t": duration, "end": duration + break_seconds, "kind": "halftime",
				"lyric": "HALF-TIME CHANT WAR" if with_war else "HALF-TIME. BREATHE.",
				"half": 1, "loop": -1, "beat": 0.5 / speed})
			duration += break_seconds
			halftime_end = duration

func phase_index(time: float) -> int:
	if time < 0.0:
		return 0
	for index in phases.size():
		if time >= float(phases[index]["t"]) and time < float(phases[index]["end"]):
			return index
	return phases.size() - 1

func phase_at(time: float) -> Dictionary:
	return phases[phase_index(time)]

func is_judging(time: float) -> bool:
	return time >= 0.0 and time < duration \
		and str(phase_at(time)["kind"]) in ["call", "sustain", "celebration", "defiance"]

## Shared verses get a safe count-in without changing a single authored note.
func insert_handoff_leads() -> void:
	var previous_loop := -1
	var rewritten: Array[Dictionary] = []
	var note_positions: Array[Dictionary] = []
	var shift := 0.0
	var old_halftime := halftime_start
	var old_halftime_end := halftime_end
	var shift_at_half := 0.0
	var shift_at_half_end := 0.0
	for index in phases.size():
		var phase := phases[index]
		if float(phase["t"]) == old_halftime:
			shift_at_half = shift
		if float(phase["t"]) == old_halftime_end:
			shift_at_half_end = shift
		var loop := int(phase["loop"])
		if loop > 0 and loop != previous_loop and str(phase["kind"]) in ["call", "sustain"]:
			var lead := float(phase["beat"]) * 2.0 + HANDOFF_CAPTURE_TAIL
			rewritten.append({"t": float(phase["t"]) + shift,
				"end": float(phase["t"]) + shift + lead, "kind": "handoff",
				"half": phase["half"], "loop": loop, "beat": phase["beat"],
				"lyric": "PASS THE MEGAPHONE. TWO BEATS TO PREPARE."})
			shift += lead
		if loop >= 0:
			previous_loop = loop
		var new_index := rewritten.size()
		note_positions.append({"phase": new_index, "shift": shift})
		phase["t"] = float(phase["t"]) + shift
		phase["end"] = float(phase["end"]) + shift
		if phase.has("call_phase"):
			phase["call_phase"] = new_index - 1
		rewritten.append(phase)
	for note in notes:
		var position := note_positions[int(note["phase"])]
		note["t"] = float(note["t"]) + float(position["shift"])
		note["phase"] = position["phase"]
	phases = rewritten
	duration += shift
	halftime_start += shift_at_half
	halftime_end += shift_at_half_end
	rebuild_beats()

## Extending a break preserves all future notes and both half-time boundaries.
func extend_phase(index: int, end: float) -> float:
	var old_end := float(phases[index]["end"])
	var shift := maxf(0.0, end - old_end)
	phases[index]["end"] = old_end + shift
	for later in range(index + 1, phases.size()):
		phases[later]["t"] = float(phases[later]["t"]) + shift
		phases[later]["end"] = float(phases[later]["end"]) + shift
	duration += shift
	if old_end <= halftime_start:
		halftime_start += shift
		halftime_end += shift
	rebuild_beats()
	return shift

func rebuild_beats() -> void:
	beats.clear()
	for phase in phases:
		if str(phase["kind"]) not in [
			"call", "sustain", "handoff", "walkin", "celebration", "defiance"]:
			continue
		var pulse := float(phase["t"])
		while pulse < float(phase["end"]) - 0.0001:
			beats.append(pulse)
			pulse += float(phase["beat"])

## Known output fits an empty tail, outside even the widest assisted note window.
func disruption_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for index in phases.size():
		var phase := phases[index]
		if str(phase["kind"]) not in ["call", "response"]:
			continue
		var beat := float(phase["beat"])
		var candidates: Array[float] = [float(phase["end"]) - beat * 0.375]
		if str(phase["kind"]) == "response":
			candidates.clear()
			for pulse in 4:
				candidates.append(float(phase["t"]) + beat * (pulse * 0.5 + 0.375))
		for time in candidates:
			var clear := true
			for note in notes:
				if bool(note.get("done", false)):
					continue
				var end := float(note["t"]) + float(note["duration"])
				if time >= float(note["t"]) - DISRUPTION_BEFORE \
					and time <= end + DISRUPTION_AFTER:
					clear = false
					break
			if clear:
				slots.append({"t": time, "beat": beat, "phase": index,
					"telegraph": maxf(0.0, time - beat * 4.0)})
				break
	return slots
