extends RefCounted

## One deterministic match composes judging, life, crowd, football and spectacle.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Chart = preload("res://games/tifo_beato/chart/match_chart.gd")
const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
const Life = preload("res://games/tifo_beato/match/chant_life.gd")
const Fury = preload("res://games/tifo_beato/match/fury.gd")
const Crowd = preload("res://games/tifo_beato/match/crowd_state.gd")
const Sim = preload("res://games/tifo_beato/match/match_sim.gd")
const Tifo = preload("res://games/tifo_beato/match/tifo_director.gd")
const Disruptions = preload("res://games/tifo_beato/match/disruptions.gd")
const Chaos = preload("res://games/tifo_beato/match/chaos_events.gd")
const Commentator = preload("res://games/tifo_beato/match/commentator.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Gate = preload("res://games/tifo_beato/sound/bleed_gate.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Chant = preload("res://games/tifo_beato/chart/chant_chart.gd")
const Moments = preload("res://games/tifo_beato/match/best_moments.gd")
var chart: Chart
var judge: Judge
var life := Life.new()
var fury := Fury.new()
var crowd: Crowd
var sim: Sim
var tifo := Tifo.new()
var disruptions: Disruptions
var chaos: Chaos
var commentator := Commentator.new()
var classifier := Classifier.new()
var gate := Gate.new()
var banner := Banner.new()
var ground := 0
var pool := 0
var seed_value := 1
var time := 0.0
var complete := false
var active_player := 0
var two_capos := false
var player_points: Array[float] = [0.0, 0.0]
var player_hits: Array[int] = [0, 0]
var player_attempts: Array[int] = [0, 0]
var events: Array[Dictionary] = []
var event_log: Array[Dictionary] = []
var classified: Array[Event] = []
var moments := Moments.new()
var visual_phase: Dictionary = {}
var bonus := 0.0
var goal_moment_left := 0.0
var goal_moment := ""
var goal_hits := 0
var goal_pending := ""
var chart_revision := 0
var keeper_full_half := false
var _phase := -1
var _stepped := 0.0
var _latency_ms := 0.0
var _last_shout := -100.0
var _last_power_combo := 0
var _was_judging := false
var _last_call_end := -100.0
var _drum_start := -100.0
var _drum_end := -100.0
var _settings: Dictionary = {}
var _goal_counts: Dictionary = {}
var _goal_key := -1
var _keeper_half := 0
var _keeper_held := true
var _keeper_high := false
var _last_combo_tier := 0
var _low_life_warning := false
var _poetry_blocked_until := 0.0
var _recent_level := 0.0
var _next_note_id := 10000

func _init(seed_number := 1, ground_index := 0, group_pool := 0,
	configuration: Dictionary = {}, with_war := false) -> void:
	seed_value = seed_number
	ground = clampi(ground_index, 0, 4)
	pool = clampi(group_pool, 0, 4)
	_settings = configuration.duplicate(true)
	_settings["pool"] = pool
	var custom: Array[Chant] = []
	custom.assign(configuration.get("custom_charts", []))
	chart = Chart.new(seed_value, pool, int(configuration.get("speed", 100)), with_war,
		float(configuration.get("half_seconds", 120.0)),
		float(configuration.get("walkin_seconds", 20.0)), custom,
		bool(configuration.get("single_pass", false)))
	if bool(configuration.get("response_rests", false)):
		for index in chart.phases.size():
			var phrase := chart.phases[index]
			if str(phrase["kind"]) == "response":
				chart.notes.append({"id": chart.notes.size(), "phase": index,
					"t": float(phrase["t"]) + 0.18, "kind": "rest", "band": 0,
					"duration": maxf(0.01, float(phrase["end"]) - float(phrase["t"]) - 0.36),
					"hold_kind": "shout"})
		chart.notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["t"]) < float(b["t"]))
	two_capos = bool(configuration.get("two_capos", false))
	if two_capos:
		chart.insert_handoff_leads()
	judge = Judge.new(chart.notes, _settings)
	life.never_dies = bool(configuration.get("never_dies", false))
	life.drain_scale = 0.75 if pool == 1 else 1.0
	if bool(configuration.get("recording", false)):
		life.drain_scale = 0.0
	life.morale_max = 100.0 + clampf(float(configuration.get("morale_bonus", 0.0)), 0.0, 25.0)
	life.morale = life.morale_max
	crowd = Crowd.new(roundi(int(Options.GROUNDS[ground]["crowd"])
		* clampf(float(configuration.get("crowd_scale", 1.0)), 1.0, 1.25)))
	sim = Sim.new(seed_value)
	tifo.max_tier = int(Options.GROUNDS[ground]["tiers"])
	tifo.streak_needed = 9 if pool == 3 else 12
	disruptions = Disruptions.new(chart.disruption_slots(), seed_value,
		2 if bool(configuration.get("practice", false)) else int(configuration.get("rivals", 0)),
		bool(configuration.get("hostile", false)))
	chaos = Chaos.new(seed_value, ground, pool == 4)
	chaos.enabled = not bool(configuration.get("practice", false))
	if configuration.has("daily_modifier"):
		chaos.set_lineup([str(configuration["daily_modifier"])])
	var responses: Array[float] = []
	for phrase in chart.phases:
		if str(phrase["kind"]) == "response":
			responses.append(float(phrase["t"]))
	chaos.schedule(responses)
	commentator.enabled = bool(configuration.get("commentator", true))
	commentator.cooldown = [12.0, 6.0, 3.0][clampi(int(configuration.get("chattiness", 1)), 0, 2)]
	_latency_ms = float(configuration.get("latency_ms", 0.0))
	classifier.noise_floor = float(configuration.get("noise_floor", 0.01))
	classifier.band_width = float(configuration.get("band_width", 250.0))
	gate.headphones = bool(configuration.get("headphones", false))

func phase() -> Dictionary:
	return visual_phase if not visual_phase.is_empty() else chart.phase_at(time)

func phase_index() -> int:
	return int(visual_phase["index"]) if not visual_phase.is_empty() else chart.phase_index(time)

func judging(at: float) -> bool:
	return chart.is_judging(at) or at >= _drum_start and at < _drum_end

func capture_tail() -> float:
	return maxf(0.0, _latency_ms) / 1000.0 + 0.18

## Output and classified events must share the same compensated clock.
func register_output(audio_time: float, level: float, duration: float) -> void:
	gate.register_output(audio_time - _latency_ms / 1000.0, level, duration)

func noise() -> int:
	return roundi((judge.score + bonus) * float(Options.GROUNDS[ground]["size_scale"]))

func stars() -> int:
	if not complete or life.walkout:
		return 0
	var accuracy := judge.accuracy()
	if accuracy >= 0.93 and life.deaths == 0 and judge.best_combo >= 64:
		return 5
	if accuracy >= 0.85 and not tifo.revealed.is_empty():
		return 4
	# A successful rally must be able to earn the three-star rally achievement.
	if accuracy >= 0.75 and (life.deaths == 0 or life.rallied):
		return 3
	return 2 if accuracy >= 0.6 else 1

func consume(raw: Frame) -> void:
	classified.clear()
	if complete:
		return
	var frame := Frame.new(raw.t - _latency_ms / 1000.0, raw.level, raw.flux,
		raw.voiced, raw.cents, raw.clarity)
	var in_call := judging(frame.t)
	var classify_tail := _was_judging and frame.t < _last_call_end + 0.18
	if not in_call and not classify_tail:
		if bool(_settings.get("response_rests", false)) \
			and str(chart.phase_at(frame.t)["kind"]) == "response" \
			and gate.accepts_level(frame.t, frame.level):
			judge.observe(frame)
		if _was_judging:
			classifier.reset()
		_was_judging = false
		return
	if in_call:
		_was_judging = true
		_last_call_end = float(chart.phase_at(frame.t)["end"])
	if two_capos:
		active_player = maxi(0, int(chart.phase_at(frame.t)["loop"])) % 2
	if gate.accepts_level(frame.t, frame.level):
		judge.observe(frame)
	for event in classifier.consume(frame):
		if not gate.accepts(event, judging(event.t)):
			continue
		classified.append(event)
		if bool(_settings.get("recording", false)):
			continue
		if life.dead:
			if event.kind == Event.ONSET:
				var current := chart.phase_at(frame.t)
				var beat := float(current["beat"])
				var relative := (event.t - float(current["t"])) / beat
				if life.rally(event.t, event.level, (relative - roundf(relative)) * beat):
					_restart_loop(frame.t)
					_emit("rally", "FOUR BEATS. THE CHANT IS BACK!")
			continue
		judge.consume(event)
		if event.kind == Event.SHOUT:
			if event.duration >= Fury.LONG_SHOUT_SECONDS:
				activate_fury()
			if event.t != _last_shout:
				_last_shout = event.t
				if fury.triple_shout(event.t, _empty_bar(event.t)):
					activate_power()
		if event.kind in [Event.SHOUT, Event.SING]:
			for note in judge.notes:
				if str(note["kind"]) == "hold" and not (note["candidate"] as Dictionary).is_empty() \
					and frame.t >= float(note["t"]) \
					and frame.t <= float(note["t"]) + float(note["duration"]):
					life.sustain()
	_publish(judge.advance(frame.t))

## The audio clock is the only authority. Render delta never enters the model.
func advance(now: float) -> Array[Dictionary]:
	while _stepped + 0.01 <= now + 0.000001 and not complete:
		_stepped += 0.01
		time = _stepped
		var current := phase()
		var index := chart.phase_index(time)
		var started := chaos.advance(time, 0.0 if str(current["kind"]) == "halftime" else 0.01,
			float(current["beat"]), str(current["kind"]) == "response")
		_resolve_chaos()
		if index != _phase:
			_phase = index
			_emit("phase", str(current["lyric"]))
			if str(current["kind"]) == "response":
				_reveal_tifo()
				if not chaos.active.is_empty():
					_prepare_challenge()
				if not goal_pending.is_empty() and chaos.active.is_empty() \
					and fury.active_power != "drum":
					_author_goal()
			if bool(current.get("goal_start", false)):
				goal_moment = str(current["goal"])
				goal_moment_left = float(current["goal_duration"])
				_goal_key = int(current["goal_key"])
				goal_hits = int(_goal_counts.get(_goal_key, 0))
			fury.half = int(current["half"])
		if two_capos and int(current["loop"]) >= 0:
			active_player = int(current["loop"]) % 2
		fury.advance(0.01)
		tifo.advance(0.01)
		goal_moment_left = maxf(0.0, goal_moment_left - 0.01)
		judge.settings["window_bonus"] = (1.3 if fury.active_power == "megaphone" else 1.0) \
			* (1.2 if chaos.active == "power_cut" else 1.0)
		judge.settings["score_bonus"] = 2.0 if fury.active_left > 0.0 else 1.0
		_publish(judge.advance(time - maxf(0.0, _latency_ms) / 1000.0))
		if life.advance(0.01, judging(time) and not current.has("goal"), judge.rest_protected(time),
			fury.active_left > 0.0):
			_emit("walkout" if life.walkout else "death",
				"THE CURVA WALKS TO THE PIE STAND." if life.walkout else (
				"THE CHANT DIED. Rally with four strong Beats on the drum."))
		crowd.advance(0.01, life.life, judge.combo_tier(), fury.active_left > 0.0)
		if not life.dead and life.life < 25.0 and not _low_life_warning:
			_low_life_warning = true
			_emit("low_life", "LOW SCARF: follow the guide; a Rest is a safe breath.")
		elif life.dead or life.life >= 35.0:
			_low_life_warning = false
		var high := crowd.energy >= 70.0
		if high and not _keeper_high:
			_emit("keeper", "ENERGY 70: the rival keeper is trembling.")
		_keeper_high = high
		if int(current["loop"]) >= 0 and time < chart.duration:
			if int(current["half"]) != _keeper_half:
				_keeper_half = int(current["half"])
				_keeper_held = true
			_keeper_held = _keeper_held and high
		if str(current["kind"]) == "halftime" and _keeper_half == 1 \
			or time >= chart.duration and _keeper_half == 2:
			keeper_full_half = keeper_full_half or _keeper_held
		if not bool(_settings.get("practice", false)) and time < chart.duration \
			and str(current["kind"]) in ["call", "sustain", "response"]:
			for event in sim.advance(0.01, crowd.energy, fury.ref_distraction):
				fury.ref_distraction = false
				var kind := str(event["kind"])
				if kind.begins_with("goal"):
					goal_pending = kind
				_emit(kind, "HOME GOAL! Finish this line; celebration follows." if kind == "goal_home" \
					else ("AWAY GOAL: finish this line, then answer with defiance." if kind == "goal_away" \
					else "THE REFEREE HAS NOTICED THE CURVA."))
		for event in disruptions.advance(time, 0.01, fury.protection_left > 0.0):
			if str(event["kind"]) == "telegraph":
				_poetry_blocked_until = time + float(current["beat"]) * 4.0 + 0.25
			events.append(event)
		if not started.is_empty():
			_emit("chaos_start", Chaos.CAPTIONS[started])
			_prepare_challenge()
		gate.prune(time - _latency_ms / 1000.0)
		moments.capture(visual_checkpoint())
		if life.walkout or time >= chart.duration + 0.5 \
			+ maxf(0.0, _latency_ms) / 1000.0:
			complete = true
			_emit("whistle", commentator.verdict(judge.accuracy(), life.deaths, life.walkout))
	var reached := events
	events = []
	return reached

func activate_fury() -> bool:
	if bool(_settings.get("practice", false)) or life.dead or not fury.activate(judging(time)):
		return false
	life.refill(100.0)
	_emit("fury", "CURVA FURY! Eight seconds. One whole stand.")
	moments.nominate("fury", time, roundi(_recent_level * 100.0))
	return true

func activate_power() -> String:
	if bool(_settings.get("practice", false)) or life.dead \
		or str(phase()["kind"]) not in ["call", "sustain", "response"]:
		return ""
	var activated := fury.activate_power()
	if activated == "drum":
		_drum_solo()
	elif activated == "tornado":
		disruptions.active = ""
	if not activated.is_empty():
		_emit("power", "POWER-UP: " + activated.to_upper())
		if activated == "tornado":
			moments.nominate("tornado", time, judge.combo)
	return activated

func achievement_ids() -> PackedStringArray:
	var awards := PackedStringArray()
	if not complete:
		return awards
	if ground == 0 and not life.walkout:
		awards.append("tifo_beato_first_chant")
	if life.deaths == 0 and not life.walkout:
		awards.append("tifo_beato_never_died")
	if judge.best_combo >= 64:
		awards.append("tifo_beato_meltdown")
	if fury.uses > 0:
		awards.append("tifo_beato_fury")
	if 2 in tifo.revealed:
		awards.append("tifo_beato_first_mosaic")
	if 5 in tifo.revealed:
		awards.append("tifo_beato_unholy_choreo")
	if fury.drum_beats >= 32:
		awards.append("tifo_beato_drum_solo")
	if "seagull" in chaos.successes:
		awards.append("tifo_beato_seagull")
	if "power_cut" in chaos.successes:
		awards.append("tifo_beato_a_cappella")
	if life.rallied and stars() >= 3:
		awards.append("tifo_beato_rally")
	if banner.mishaps.size() >= 3 and not tifo.revealed.is_empty():
		awards.append("tifo_beato_mishap")
	if keeper_full_half:
		awards.append("tifo_beato_keeper_tremble")
	if two_capos and not life.walkout:
		awards.append("tifo_beato_two_capos")
	return awards

func _publish(results: Array[Dictionary]) -> void:
	for result in results:
		var seat := active_player
		if two_capos:
			seat = maxi(0, int(chart.phases[int(result["note"]["phase"])]["loop"])) % 2
		result["seat"] = seat
		player_points[seat] += float(result["points"])
		player_attempts[seat] += 1
		if int(result["grade"]) < 3:
			player_hits[seat] += 1
		life.refill(float(result["refill"]))
		crowd.judge(int(result["grade"]))
		if not bool(_settings.get("practice", false)):
			fury.award(int(result["grade"]), str(result["kind"]), float(result["level"]),
				float(result["duration"]))
		tifo.judge(judge.perfect_streak)
		chaos.judge(result)
		_resolve_chaos()
		if fury.active_power == "drum" and str(result["kind"]) == "beat" \
			and int(result["grade"]) < 3:
			fury.drum_beats += 1
			_add_bonus(float(result["points"]), seat)
		if result["note"].has("goal") and int(result["grade"]) < 3:
			var key := int(result["note"]["goal_key"])
			var hits := int(_goal_counts.get(key, 0)) + 1
			_goal_counts[key] = hits
			if key == _goal_key:
				goal_hits = hits
			_add_bonus(50.0, seat)
			if str(result["note"]["goal"]) == "goal_away" and hits == 8:
				life.refill(35.0)
				life.morale = minf(life.morale_max, life.morale + 1.0)
				_emit("defiance", "EIGHT BEATS OF DEFIANCE. The scarf is back on its feet.")
			elif str(result["note"]["goal"]) == "goal_home" and hits == 8:
				_reveal_tifo()
		var tier := judge.combo_tier()
		if tier > _last_combo_tier:
			_emit("combo", judge.combo_name())
		_last_combo_tier = tier
		if int(result["grade"]) == 0:
			var line := commentator.line("perfect", time, time < _poetry_blocked_until)
			if not line.is_empty():
				events.append({"kind": "commentator", "text": line})
		var milestone := 6 if pool == 4 else 8
		if not bool(_settings.get("practice", false)) \
			and judge.combo >= milestone and judge.combo / milestone > _last_power_combo:
			_last_power_combo = judge.combo / milestone
			fury.offer_power(["megaphone", "drum", "tornado", "ref"][
				(_last_power_combo - 1) % 4])
		events.append({"kind": "grade", "result": result, "seat": seat})
		event_log.append({"t": time, "grade": result["grade"], "kind": result["kind"],
			"seat": seat, "error": result["error"]})
		_recent_level = clampf(float(result["level"]), 0.0, 1.0)
		moments.judged(time, result)
		moments.capture(visual_checkpoint(), true)
		if (str(result["kind"]) == "sing" or str(result["kind"]) == "hold" \
			and str(result["note"].get("hold_kind", "")) == "sing") and int(result["grade"]) < 3 \
			and int(result["band"]) != int(result["note"]["band"]):
			moments.nominate("off_key", time,
				absi(int(result["band"]) - int(result["note"]["band"])) * 50)

func _reveal_tifo() -> void:
	if chaos.active == "seagull":
		return
	var tier := tifo.response()
	if tier > 0:
		_add_bonus(600.0 * tier * banner.bonus_scale() * (1.5 if pool == 3 else 1.0)
			+ banner.mishaps.size() * 30.0)
		_emit("tifo", Tifo.NAMES[tier])
		moments.nominate("tifo", time, tier * 20)

func visual_checkpoint() -> Array:
	var current := phase()
	return [roundi(time * 100.0), roundi(life.life), roundi(life.morale),
		roundi(crowd.energy), roundi(crowd.sync * 100.0), roundi(crowd.phase_scatter * 1000.0),
		roundi(fury.charge), roundi(fury.active_left * 100.0),
		3 if fury.protection_left > 0.0 else maxi(0, Moments.POWERS.find(fury.active_power)),
		roundi((fury.protection_left if fury.protection_left > 0.0 else fury.power_left) * 100.0),
		tifo.tier, roundi(tifo.reveal_left * 100.0), sim.home, sim.away, sim.zone,
		1 if sim.home_possession else 0, roundi(sim.time * 100.0),
		maxi(0, Moments.CHAOS.find(chaos.active)), chaos.progress,
		maxi(0, Moments.DISRUPTIONS.find(disruptions.active)),
		maxi(0, Moments.PHASES.find(str(current["kind"]))),
		roundi(float(current["beat"]) * 1000.0), 1 if life.dead else 0]

func _resolve_chaos() -> void:
	for result in chaos.resolutions:
		var kind := str(result["kind"])
		if bool(result["success"]):
			_add_bonus(500.0)
			for seat in 2:
				_add_bonus(float(result["seat_points"][seat]), seat)
			_emit("chaos", "CHAOS WON: " + kind.to_upper())
			if kind in ["seagull", "power_cut"]:
				fury.offer_power("tornado" if kind == "seagull" else "megaphone")
		else:
			_emit("chaos_lost", "CHAOS ENDS: " + kind.to_upper() + ". Your basic chant is still yours.")
	chaos.resolutions.clear()

## A full call/response pair becomes four optional Beat bars; the match clock never grows.
func _author_goal() -> void:
	var index := _phase + 1
	while index < chart.phases.size() and str(chart.phases[index]["kind"]) == "handoff":
		index += 1
	if index + 1 >= chart.phases.size() or str(chart.phases[index]["kind"]) != "call" \
		or str(chart.phases[index + 1]["kind"]) != "response":
		return
	var first: Dictionary = chart.phases[index]
	var second: Dictionary = chart.phases[index + 1]
	var moment := goal_pending
	var length := float(second["end"]) - float(first["t"])
	for part in [index, index + 1]:
		var phrase: Dictionary = chart.phases[part]
		phrase["kind"] = "celebration" if moment == "goal_home" else "defiance"
		phrase["lyric"] = "FREE CELEBRATION: every on-grid BEAT scores." if moment == "goal_home" \
			else "DEFIANCE: eight on-grid BEATS refill the scarf and morale."
		phrase["goal"] = moment
		phrase["goal_start"] = part == index
		phrase["goal_duration"] = length
		phrase["goal_key"] = index
		phrase["template"] = []
		for note in judge.notes:
			if int(note.get("phase", -1)) == part and not bool(note["done"]):
				note["done"] = true
				note["superseded"] = true
		for pulse in 8:
			var template := {"beat": float(pulse), "kind": "beat", "duration": 0.0,
				"band": 0, "hold_kind": "shout", "optional": true, "goal": moment, "goal_key": index}
			(phrase["template"] as Array).append(template)
			_append_note(template, part)
	goal_pending = ""
	_sync_chart()

## Challenges are authored during the response, leaving a full visible preparation bar.
func _prepare_challenge() -> void:
	var index := _phase + 1
	while index < chart.phases.size() and str(chart.phases[index]["kind"]) not in ["call", "sustain"]:
		index += 1
	if index >= chart.phases.size() or chaos.active not in ["power_cut", "seagull", "rain", "kazoo"]:
		return
	if str(chart.phases[index].get("challenge_kind", "")) == chaos.active:
		return
	var pattern: Array[Dictionary] = []
	match chaos.active:
		"power_cut":
			for rung in 3:
				pattern.append({"beat": rung * 2.0, "kind": "hold", "duration": 1.75,
					"band": rung - 1, "hold_kind": "sing"})
			pattern.append({"beat": 6.0, "kind": "rest", "duration": 1.0, "band": 0,
				"hold_kind": "shout"})
		"seagull":
			for pulse in 8:
				pattern.append({"beat": float(pulse), "kind": "beat", "duration": 0.0,
					"band": 0, "hold_kind": "shout"})
		"rain":
			pattern = [{"beat": 0.0, "kind": "hold", "duration": 4.0, "band": 0,
				"hold_kind": "sing"}, {"beat": 5.0, "kind": "rest", "duration": 2.0,
				"band": 0, "hold_kind": "shout"}]
		"kazoo":
			pattern = [{"beat": 0.0, "kind": "beat", "duration": 0.0, "band": 0,
				"hold_kind": "shout"}, {"beat": 2.0, "kind": "rest", "duration": 1.0,
				"band": 0, "hold_kind": "shout"}, {"beat": 4.0, "kind": "beat",
				"duration": 0.0, "band": 0, "hold_kind": "shout"},
				{"beat": 6.0, "kind": "rest", "duration": 1.0, "band": 0, "hold_kind": "shout"}]
	var phrase: Dictionary = chart.phases[index]
	phrase["challenge_kind"] = chaos.active
	phrase["template"] = pattern.duplicate(true)
	phrase["lyric"] = Chaos.CAPTIONS[chaos.active]
	for note in judge.notes:
		if int(note.get("phase", -1)) == index and not bool(note["done"]):
			note["done"] = true
			note["superseded"] = true
	for note in pattern:
		_append_note(note, index)
	_sync_chart()

func _append_note(template: Dictionary, phase_index: int) -> void:
	var phrase: Dictionary = chart.phases[phase_index]
	var note := template.duplicate(true)
	note["id"] = _new_note_id()
	note["t"] = float(phrase["t"]) + float(note["beat"]) * float(phrase["beat"])
	note["duration"] = float(note["duration"]) * float(phrase["beat"])
	note["phase"] = phase_index
	note.merge({"done": false, "coverage": 0.0, "rest_broken": false, "candidate": {}})
	judge.notes.append(note)

func _sync_chart() -> void:
	judge.notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))
	chart.notes = judge.notes.duplicate(true)
	chart.rebuild_beats()
	disruptions.retime(chart.disruption_slots(), time)
	chart_revision += 1
	events.append({"kind": "chart_changed", "t": time})

func _add_bonus(points: float, seat := -1) -> void:
	bonus += points
	player_points[active_player if seat < 0 else seat] += points

func _new_note_id() -> int:
	var id := _next_note_id
	_next_note_id += 1
	return id

func _emit(kind: String, caption: String) -> void:
	events.append({"kind": kind, "text": caption, "t": time})
	if kind in ["fury", "power", "tifo", "goal_home", "goal_away"]:
		moments.capture(visual_checkpoint(), true)
	var line := commentator.line(kind, time, time < _poetry_blocked_until)
	if not line.is_empty():
		events.append({"kind": "commentator", "text": line})

func _empty_bar(at: float) -> bool:
	for note in judge.notes:
		if not bool(note["done"]) and absf(float(note["t"]) - at) < 0.4:
			return false
	return true

func _drum_solo() -> void:
	var beat := float(phase()["beat"])
	var start := time + beat
	var end := start + beat * 16.0
	_drum_start = start
	_drum_end = end
	var current := phase()
	var old_end := float(current["end"])
	var index := chart.phase_index(time)
	var shift := chart.extend_phase(index, end)
	chaos.retime(old_end, shift)
	if str(current["kind"]) == "response":
		current["kind"] = "call"
		current["lyric"] = "DRUM SOLO. THIRTY-TWO BEATS. YOUR WHOLE DRUM LINE."
	for note in judge.notes:
		if float(note["t"]) >= old_end:
			note["t"] = float(note["t"]) + shift
	fury.power_left = beat * 17.0
	judge.notes = judge.notes.filter(func(note: Dictionary) -> bool:
		return bool(note["done"]) or float(note["t"]) < start or float(note["t"]) >= end)
	for hit in 32:
		judge.notes.append({"id": _new_note_id(), "t": start + hit * beat * 0.5,
			"kind": "beat", "duration": 0.0, "band": 0, "hold_kind": "shout",
			"done": false, "coverage": 0.0, "rest_broken": false, "candidate": {},
			"phase": chart.phase_index(start), "beat": hit * 0.5})
	judge.notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))
	chart.notes = judge.notes.duplicate(true)
	disruptions.retime(chart.disruption_slots(), time)
	events.append({"kind": "chart_changed", "t": time})
	chart_revision += 1

## Re-author the current loop at the next bar; banked points and match RNG are untouched.
func _restart_loop(at: float) -> void:
	var current := phase()
	var beat := float(current["beat"])
	var start := float(current["t"]) + ceilf((at - float(current["t"])) / (beat * 4.0)) \
		* beat * 4.0
	var template: Array = current.get("template", [])
	for source in chart.phases:
		if int(source["loop"]) == int(current["loop"]) and source.has("template"):
			template = source["template"]
			break
	var old_end := float(current["end"])
	var shift := maxf(0.0, start + beat * 8.0 - old_end)
	current["end"] = old_end + shift
	for index in range(_phase + 1, chart.phases.size()):
		chart.phases[index]["t"] = float(chart.phases[index]["t"]) + shift
		chart.phases[index]["end"] = float(chart.phases[index]["end"]) + shift
	chart.duration += shift
	chaos.retime(old_end, shift)
	chart.halftime_start += shift if at < chart.halftime_start else 0.0
	chart.halftime_end += shift if at < chart.halftime_end else 0.0
	for note in judge.notes:
		if float(note["t"]) >= old_end:
			note["t"] = float(note["t"]) + shift
	judge.notes = judge.notes.filter(func(note: Dictionary) -> bool:
		return bool(note["done"]) or int(note.get("phase", -1)) != _phase)
	for source: Dictionary in template:
		var note := source.duplicate(true)
		note["t"] = start + float(source["beat"]) * beat
		note["duration"] = float(source["duration"]) * beat
		note["id"] = _new_note_id()
		note["phase"] = _phase
		note["done"] = false
		note["coverage"] = 0.0
		note["rest_broken"] = false
		note["candidate"] = {}
		judge.notes.append(note)
	chart.rebuild_beats()
	judge.notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))
	chart.notes = judge.notes.duplicate(true)
	disruptions.retime(chart.disruption_slots(), at)
	events.append({"kind": "rally_restart", "t": at})
	chart_revision += 1
