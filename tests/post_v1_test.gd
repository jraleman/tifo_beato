extends SceneTree

## Expanded modes retain the ordinary judge and merge-only progress contracts.

const Away = preload("res://games/tifo_beato/career/away_days.gd")
const Derby = preload("res://games/tifo_beato/career/derby_week.gd")
const Creator = preload("res://games/tifo_beato/chart/chant_creator.gd")
const Daily = preload("res://games/tifo_beato/career/daily_derby.gd")
const Moments = preload("res://games/tifo_beato/match/best_moments.gd")
const State = preload("res://games/tifo_beato/match/match_state.gd")
const Disruptions = preload("res://games/tifo_beato/match/disruptions.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
var _failures := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_travel()
	_test_derby()
	_test_creator()
	_test_daily()
	_test_moments()
	_test_progress()
	_test_boundaries_and_authored_ids()
	if _failures.is_empty():
		print("Tifo Beato post-v1 model tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _test_travel() -> void:
	for kind in ["bus", "station"]:
		var chant := Away.chart(kind)
		_expect(chant.validate().is_empty(), "Travel charts must be valid ordinary chants.")
		var state := State.new(9, 0, 0, Away.configuration(kind))
		_expect(state.chart.halftime_start == state.chart.duration \
			and not state.disruptions.slots.size(), "Travel is a single safe stage, not a football match.")
		if kind == "station":
			var rest: Dictionary = {}
			for note in state.judge.notes:
				if str(note["kind"]) == "rest":
					rest = note
					break
			_expect(not rest.is_empty(), "Station echoes must have real silence opportunities.")
			for tick in range(1, ceili((float(rest["t"]) + float(rest["duration"]) + 0.1) * 100.0)):
				var now := tick / 100.0
				state.advance(now)
				state.consume(Frame.new(now, 0.8 if now >= float(rest["t"]) else 0.0))
			_expect(bool(rest["rest_broken"]), "Calling over the station echo must break its Rest.")
	var slots: Array[Dictionary] = []
	for index in 60:
		slots.append({"t": index * 10.0, "telegraph": index * 10.0 - 4.0,
			"phase": index, "beat": 1.0})
	for setting in [0, 1]:
		var ordinary := Disruptions.new(slots, 8, setting)
		var hostile := Disruptions.new(slots, 8, setting, true)
		_expect(hostile.slots.size() == ordinary.slots.size() * 2,
			"Hostile grounds double safe slots, including Gentle rivals.")
	_expect(Disruptions.new(slots, 8, 2, true).slots.is_empty(),
		"Hostile grounds must still respect Rivals Off.")

func _test_derby() -> void:
	var preparation: Dictionary = {}
	Derby.record(preparation, "pub", 80.0)
	Derby.record(preparation, "pub", 20.0)
	_expect(float(preparation["pub"]) == 80.0, "Replayed rituals cannot regress.")
	for ritual in Derby.RITUALS:
		Derby.record(preparation, ritual, 100.0)
		if ritual != "mural":
			for chant in Derby.charts(ritual):
				_expect(chant.validate().is_empty(), "Every ritual uses valid original charts.")
	var bonus := Derby.bonuses(preparation)
	_expect(int(bonus["morale"]) == 25 and is_equal_approx(float(bonus["crowd_scale"]), 1.25),
		"Five rituals have a bounded, non-stacking preparation bonus.")
	var state := State.new(3, 3, 0,
		{"morale_bonus": bonus["morale"], "crowd_scale": bonus["crowd_scale"]})
	_expect(state.life.morale == 125.0, "Derby preparation raises actual starting morale.")
	_expect(not Derby.valid({"pub": NAN}), "Non-finite preparation must not enter saves.")

func _test_creator() -> void:
	var creator := Creator.new()
	creator.tempo = 120
	creator.begin(1.0)
	var events: Array[Event] = [Event.new(1.06), Event.new(1.5, Event.SING, 1.0, 1, 1.0, true)]
	creator.capture(events)
	creator.recording = false
	_expect(creator.notes.size() == 2 and int(creator.notes[0][1]) == 0 \
		and int(creator.notes[1][0]) == 3, "Live events quantize, including voiced Holds.")
	_expect(Creator.validate(creator.payload()).is_empty() \
		and creator.to_chart().validate().is_empty(), "Recorded data becomes a real ChantChart.")
	var decoded := Creator.decode(creator.code())
	_expect(str(decoded["error"]).is_empty() and decoded["data"] == creator.payload(),
		"Chant codes round-trip musical data exactly.")
	for bad in ["TB1.====.12345678", creator.code().left(-1), "TB1." + "A".repeat(9000),
		"res://malicious.tres", "TB1.AA==AAAA.12345678"]:
		_expect(not str(Creator.decode(bad)["error"]).is_empty(), "Malformed chant codes are refused.")
	var old := creator.payload()
	_expect(not creator.put_note([4, 0, 4, 0, 0]).is_empty() and creator.payload() == old,
		"Conflicting Rest edits must leave the working chant intact.")
	var invalid := old.duplicate(true)
	invalid["notes"] = [[2, 0, 9999, 0, 1]]
	_expect(not creator.restore(invalid).is_empty() and creator.payload() == old,
		"Out-of-bounds imports cannot replace the working chant.")
	invalid = old.duplicate(true)
	invalid["lyric"] = "unreviewed free text"
	_expect(not Creator.validate(invalid).is_empty(), "Creator lyrics remain curated ids.")
	var short_voice := Creator.new()
	short_voice.begin(0.0)
	short_voice.capture([Event.new(0.0, Event.SING, 1.0, 0, 0.15, true)])
	short_voice.recording = false
	var voice_duration := float(short_voice.notes[0][2]) * 60.0 / (short_voice.tempo * 4.0)
	var state := State.new(9, 0, 0, {"walkin_seconds": 0.0, "practice": true,
		"single_pass": true, "custom_charts": [short_voice.to_chart()]})
	for tick in 50:
		var now := tick / 100.0
		state.advance(now)
		var sounding := now < voice_duration
		state.consume(Frame.new(now, 0.9 if sounding else 0.0,
			1.0 if tick == 0 else 0.0, sounding, 0.0, 1.0 if sounding else 0.0))
	_expect(state.judge.hits == 1, "Quantized short voices must remain physically classifiable.")
	invalid = short_voice.payload()
	invalid["notes"] = [[2, 0, 1, 0, 1]]
	_expect(not Creator.validate(invalid).is_empty(),
		"Edits and imports must refuse sustains too short for the shared classifier.")

func _test_daily() -> void:
	_expect(Daily.challenge("2026-11-04") == Daily.challenge("2026-11-04"),
		"Every installation gets identical choices for the same local date.")
	_expect(Daily.challenge("2026-11-04")["seed"] != Daily.challenge("2026-11-05")["seed"],
		"Changing local dates changes the seed.")
	_expect(not Daily.valid_date("2026-02-29") and Daily.valid_date("2028-02-29") \
		and Daily.adjacent("2028-02-28", 1) == "2028-02-29" \
		and Daily.adjacent("2026-12-31", 1) == "2027-01-01",
		"Calendar boundaries include leap days without DST arithmetic.")
	var history: Dictionary = {}
	Daily.record(history, "2026-11-04", 100, 2, 4)
	Daily.record(history, "2026-11-04", 50, 1, 2)
	Daily.record(history, "2026-11-06", 120, 3, 6)
	Daily.record(history, "2026-11-05", 110, 3, 5)
	_expect(int(history["2026-11-04"]["noise"]) == 100 \
		and Daily.streak(history, "2026-11-06") == 3,
		"Duplicate plays cannot inflate streaks; a backfilled day closes a real date gap.")
	_expect(Daily.streak(history, "2026-11-08") == 0,
		"A missed whole calendar day breaks the current streak.")
	var challenge := Daily.challenge("2026-11-04")
	var state := State.new(int(challenge["seed"]), int(challenge["ground"]),
		int(challenge["pool"]), {"daily_modifier": challenge["modifier"]})
	_expect(state.chaos.get("_queue") == [challenge["modifier"]],
		"The daily modifier changes actual scheduled match content.")

func _test_moments() -> void:
	var state := State.new(2026, 0, 0, {"walkin_seconds": 0.0})
	state.advance(1.0)
	state.fury.charge = 100.0
	state.activate_fury()
	state.advance(3.0)
	var clips := state.moments.finish({"run": "test", "seed": 2026,
		"ground": 0, "pool": 0, "banner": state.banner.to_data(), "outfit": {}})
	_expect(not clips.is_empty() and Moments.valid(clips),
		"A real Fury produces a bounded replayable moment.")
	if clips.is_empty():
		return
	var replay := State.new(2026)
	var row: Array = clips[0]["frames"][-1]
	Moments.apply(replay, clips[0], float(row[0]) / 100.0)
	_expect(replay.visual_checkpoint() == row, "Replay reconstructs the recorded 3D model state.")
	_expect(replay.judge.score == 0.0 and replay.player_hits == [0, 0],
		"Read-only replay never scores or invents new judged hits.")
	var merged := Moments.merge(clips, clips)
	_expect(merged.size() == clips.size(), "Stale progress views cannot duplicate moments.")
	var damaged := clips.duplicate(true)
	damaged[0]["frames"][0][17] = 999
	_expect(not Moments.valid(damaged), "Invalid replay indices are rejected before rendering.")

func _test_progress() -> void:
	var path := "user://tifo_post_v1_%d.cfg" % Time.get_ticks_usec()
	var first := Records.new()
	var stale := Records.new()
	var chant := Creator.new()
	chant.notes = [[0, 0, 0, 0, 0]]
	first.load_file(path)
	stale.load_file(path)
	first.save_chant(0, chant.payload())
	Derby.record(first.data["derby"], "pub", 90.0)
	Daily.record(first.data["daily"], "2026-11-04", 900, 3, 9)
	_expect(first.save_file(path) == OK, "New progress fields save.")
	chant.lyric = 1
	stale.save_chant(1, chant.payload())
	Derby.record(stale.data["derby"], "pub", 20.0)
	Daily.record(stale.data["daily"], "2026-11-05", 1000, 4, 10)
	_expect(stale.save_file(path) == OK, "Stale writers merge rather than erase other fields.")
	var loaded := Records.new()
	loaded.load_file(path)
	_expect(loaded.data["chants"].size() == 2 and float(loaded.data["derby"]["pub"]) == 90.0 \
		and Daily.streak(loaded.data["daily"], "2026-11-05") == 2,
		"Chant slots, ritual bests and daily streaks survive stale writer merges.")
	_expect(DirAccess.remove_absolute(path) == OK, "The suite cleans up only its own save.")

func _test_boundaries_and_authored_ids() -> void:
	var state := State.new(9, 0, 0, Away.configuration("bus"))
	var at := float(state.chart.phases[1]["t"])
	_expect(state.chart.is_judging(at - 0.00000000001),
		"Sub-microsecond floating error cannot erase a boundary attack.")
	var notes: Array[Dictionary] = [{"t": 0.6, "duration": 0.6, "kind": "rest", "band": 0}]
	var judge := Judge.new(notes)
	judge.observe(Frame.new(1.2 - 0.00000000001, 1.0))
	_expect(not bool(judge.notes[0]["rest_broken"]),
		"The next attack cannot break a Rest that ended at that same sample boundary.")
	state = State.new(9)
	state.time = 21.0
	state.call("_drum_solo")
	var ids: Array[int] = []
	for note in state.judge.notes:
		if int(note["id"]) >= 10000:
			ids.append(int(note["id"]))
	state.time = 21.5
	state.call("_drum_solo")
	for note in state.judge.notes:
		if float(note["t"]) >= state.time + float(state.phase()["beat"]) \
			and int(note["id"]) >= 10000:
			_expect(int(note["id"]) not in ids,
				"Reauthored solos must never reuse a previously playable note id.")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
