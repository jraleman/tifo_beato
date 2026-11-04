extends RefCounted

## Small visual checkpoints and judged events replay without opening an input source.

const KINDS := ["fury", "tornado", "tifo", "off_key"]
const TITLES := ["One whole Curva Fury", "The heroic scarf tornado",
	"The biggest tifo", "A wonderfully off-key disaster"]
const PHASES := ["walkin", "call", "sustain", "response", "halftime",
	"handoff", "celebration", "defiance"]
const CHAOS := ["", "seagull", "drum_skin", "power_cut", "beach_balls", "rain", "kazoo"]
const DISRUPTIONS := ["", "air_horn", "trumpet", "rival_drums", "inflatable"]
const POWERS := ["", "megaphone", "drum", "tornado", "ref"]
const NOTES := ["beat", "shout", "sing", "hold", "rest"]
const LIMIT := 12
const WINDOW := 300
var frames: Array[Array] = []
var judgments: Array[Array] = []
var candidates: Dictionary = {}
var _next_sample := 0

func capture(row: Array, force := false) -> void:
	var at := int(row[0])
	if not force and at < _next_sample:
		return
	_next_sample = at + 50
	if not frames.is_empty() and int(frames[-1][0]) == at:
		frames[-1] = row.duplicate()
	else:
		frames.append(row.duplicate())
	while not frames.is_empty() and int(frames[0][0]) < at - WINDOW:
		frames.pop_front()
	for clip: Dictionary in candidates.values():
		if at <= int(clip["at"]) + WINDOW:
			_append_row(clip["frames"], row)

func judged(at: float, result: Dictionary) -> void:
	var row: Array = [roundi(at * 100.0), int(result["grade"]),
		NOTES.find(str(result["kind"])), int(result.get("band", 0)), int(result.get("seat", 0))]
	judgments.append(row)
	while not judgments.is_empty() and int(judgments[0][0]) < int(row[0]) - WINDOW:
		judgments.pop_front()
	for clip: Dictionary in candidates.values():
		if int(row[0]) <= int(clip["at"]) + WINDOW:
			(clip["judgments"] as Array).append(row.duplicate())

func nominate(kind: String, at: float, quality: int) -> void:
	assert(kind in KINDS, "Unknown Best Moment.")
	var rank := clampi(quality, 0, 100)
	if candidates.has(kind) and int(candidates[kind]["rank"]) >= rank:
		return
	candidates[kind] = {"kind": kind, "at": roundi(at * 100.0), "rank": rank,
		"frames": frames.duplicate(true), "judgments": judgments.duplicate(true)}

func finish(context: Dictionary) -> Array:
	var result: Array = []
	for kind: String in candidates:
		var clip: Dictionary = candidates[kind].duplicate(true)
		if (clip["frames"] as Array).size() < 2:
			continue
		clip.merge(context.duplicate(true))
		clip["id"] = ("%s:%s:%s" % [context["run"], kind, clip["at"]]).sha256_text()
		result.append(clip)
	return result

static func merge(first: Array, second: Array) -> Array:
	var by_id: Dictionary = {}
	for clip: Dictionary in first + second:
		var id := str(clip["id"])
		if not by_id.has(id) or (clip["frames"] as Array).size() \
			> (by_id[id]["frames"] as Array).size():
			by_id[id] = clip.duplicate(true)
	var combined: Array = by_id.values()
	combined.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) > str(b["id"]) if int(a["rank"]) == int(b["rank"]) \
			else int(a["rank"]) > int(b["rank"]))
	return combined.slice(0, LIMIT)

static func apply(state: RefCounted, clip: Dictionary, seconds: float) -> void:
	var rows: Array = clip["frames"]
	var target := roundi(seconds * 100.0)
	var index := 0
	for candidate in rows.size():
		if int(rows[candidate][0]) > target:
			break
		index = candidate
	var row: Array = rows[index]
	state.set("time", clampf(seconds, int(rows[0][0]) / 100.0, int(rows[-1][0]) / 100.0))
	var life: RefCounted = state.get("life")
	life.set("life", float(row[1]))
	life.set("morale", float(row[2]))
	life.set("dead", int(row[22]) == 1)
	var crowd: RefCounted = state.get("crowd")
	crowd.set("energy", float(row[3]))
	crowd.set("sync", int(row[4]) / 100.0)
	crowd.set("phase_scatter", int(row[5]) / 1000.0)
	var fury: RefCounted = state.get("fury")
	fury.set("charge", float(row[6]))
	fury.set("active_left", int(row[7]) / 100.0)
	fury.set("active_power", POWERS[int(row[8])])
	fury.set("power_left", int(row[9]) / 100.0)
	fury.set("protection_left", int(row[9]) / 100.0 if int(row[8]) == 3 else 0.0)
	state.get("tifo").set("tier", int(row[10]))
	state.get("tifo").set("reveal_left", int(row[11]) / 100.0)
	var sim: RefCounted = state.get("sim")
	sim.set("home", int(row[12]))
	sim.set("away", int(row[13]))
	sim.set("zone", int(row[14]))
	sim.set("home_possession", int(row[15]) == 1)
	sim.set("time", int(row[16]) / 100.0)
	state.get("chaos").set("active", CHAOS[int(row[17])])
	state.get("chaos").set("progress", int(row[18]))
	state.get("disruptions").set("active", DISRUPTIONS[int(row[19])])
	state.set("visual_phase", {"kind": PHASES[int(row[20])], "beat": int(row[21]) / 1000.0,
		"lyric": TITLES[KINDS.find(str(clip["kind"]))], "index": int(row[20]),
		"t": int(rows[0][0]) / 100.0, "end": int(rows[-1][0]) / 100.0})

static func valid(value: Variant) -> bool:
	if not value is Array or value.size() > LIMIT:
		return false
	for clip: Variant in value:
		if not clip is Dictionary or not clip.get("id") is String \
			or str(clip["id"]).length() != 64 or clip.get("kind") not in KINDS:
			return false
		for key in ["rank", "at", "seed", "ground", "pool"]:
			if not _integer(clip.get(key)) or int(clip[key]) < 0:
				return false
		if int(clip["rank"]) > 100 or int(clip["ground"]) > 4 or int(clip["pool"]) > 4:
			return false
		for key in ["banner", "outfit"]:
			if not clip.get(key) is Dictionary:
				return false
		var rows: Variant = clip.get("frames")
		if not rows is Array or rows.size() < 2 or rows.size() > 128:
			return false
		var previous := -1
		for row: Variant in rows:
			if not row is Array or row.size() != 23:
				return false
			for number: Variant in row:
				if not _integer(number) or int(number) < 0 or int(number) > 100000000:
					return false
			if int(row[0]) < previous or int(row[8]) >= POWERS.size() \
				or int(row[17]) >= CHAOS.size() or int(row[19]) >= DISRUPTIONS.size() \
				or int(row[20]) >= PHASES.size() or int(row[21]) <= 0 \
				or int(row[14]) > 4 or int(row[22]) > 1:
				return false
			previous = int(row[0])
		var hits: Variant = clip.get("judgments")
		if not hits is Array or hits.size() > 128:
			return false
		for hit: Variant in hits:
			if not hit is Array or hit.size() != 5:
				return false
			for number: Variant in hit:
				if not _integer(number):
					return false
			if int(hit[0]) < 0 or int(hit[1]) not in [0, 1, 2, 3] \
				or int(hit[2]) < 0 or int(hit[2]) >= NOTES.size() \
				or int(hit[3]) not in [-1, 0, 1] or int(hit[4]) not in [0, 1]:
				return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value))

func _append_row(rows: Array, row: Array) -> void:
	if not rows.is_empty() and int(rows[-1][0]) == int(row[0]):
		rows[-1] = row.duplicate()
	elif rows.size() < 128:
		rows.append(row.duplicate())
