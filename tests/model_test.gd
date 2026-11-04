extends SceneTree

## Focused rule, progression and deterministic composition regressions.

const Chants = preload("res://games/tifo_beato/chart/chants.gd")
const Chart = preload("res://games/tifo_beato/chart/match_chart.gd")
const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
const Life = preload("res://games/tifo_beato/match/chant_life.gd")
const Fury = preload("res://games/tifo_beato/match/fury.gd")
const Crowd = preload("res://games/tifo_beato/match/crowd_state.gd")
const Sim = preload("res://games/tifo_beato/match/match_sim.gd")
const State = preload("res://games/tifo_beato/match/match_state.gd")
const Chaos = preload("res://games/tifo_beato/match/chaos_events.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Career = preload("res://games/tifo_beato/career/career_state.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const Identity = preload("res://games/tifo_beato/career/identity.gd")
const Words = preload("res://games/tifo_beato/career/word_list.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Build = preload("res://games/tifo_beato/workshop/build_race.gd")
const Steward = preload("res://games/tifo_beato/steward/steward_state.gd")
const Cpu = preload("res://games/tifo_beato/sound/cpu_source.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var chants := Chants.all()
	expect(chants.size() == 24, "All 24 original chants must be available.")
	for chant in chants:
		expect(chant.validate().is_empty(), "Chart validation: " + chant.id)
	var first := Chart.new(23, 0)
	var second := Chart.new(23, 0)
	expect(first.notes == second.notes, "Match charts must be seed stable.")
	var slow := Chart.new(23, 0, 70)
	expect(first.notes.size() == slow.notes.size(), "Speed assist must preserve all notes.")
	for slot in first.disruption_slots():
		var phase: Dictionary = first.phases[int(slot["phase"])]
		var grid := (float(slot["t"]) - float(phase["t"])) / float(slot["beat"]) * 4.0
		expect(absf(grid - roundf(grid)) > 0.1, "Every disruption must be off-grid.")
		for note in first.notes:
			expect(float(slot["t"]) + 0.25 < float(note["t"]) - 0.4368 \
				or float(slot["t"]) > float(note["t"]) + float(note["duration"]) + 0.4368,
				"The whole rival transient must clear every assisted onset, Hold and Rest.")
	for pool in 5:
		expect(not Chart.new(23, pool).disruption_slots().is_empty(),
			"Every group must have real safe disruption opportunities, not an empty scheduling stub.")
	_test_chart_handoffs()
	_test_judge()
	_test_output_clock()
	_test_life_fury()
	_test_football()
	_test_career_banner()
	_test_extra_modes()
	_test_goal_and_chaos()
	_test_goal_latency()
	_test_full_match()
	for failure in failures:
		printerr(failure)
	print("Tifo model tests: %d failures." % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_chart_handoffs() -> void:
	for pool in [0, 2, 4]:
		var original := Chart.new(2026, pool, 100, true, 24.0, 2.0)
		var shared := Chart.new(2026, pool, 100, true, 24.0, 2.0)
		shared.insert_handoff_leads()
		for note in shared.notes:
			var authored := original.notes[int(note["id"])]
			var phase := shared.phases[int(note["phase"])]
			var before := original.phases[int(authored["phase"])]
			expect(phase["loop"] == before["loop"] and phase["kind"] == before["kind"],
				"Inserting many cards must remap each note once, never migrate it to another verse.")
			expect(is_equal_approx(float(note["t"]) - float(phase["t"]),
				float(authored["t"]) - float(before["t"])),
				"Both capos must play the original relative timing inside every shifted verse.")

func _test_judge() -> void:
	for offset in [0.0, 0.045, 0.09, 0.14, 0.141]:
		var notes: Array[Dictionary] = [{"id": 0, "t": 1.0, "kind": "beat", "duration": 0.0}]
		var normal := Judge.new(notes)
		normal.consume(Event.new(1.0 + offset))
		normal.advance(2.0)
		for width in [1, 2]:
			var assisted := Judge.new(notes, {"windows": width})
			assisted.consume(Event.new(1.0 + offset))
			assisted.advance(2.0)
			expect(assisted.score >= normal.score, "Wider windows must not penalize a hit.")
		var quiet := Judge.new(notes, {"quiet": true})
		quiet.consume(Event.new(1.0 + offset))
		quiet.advance(2.0)
		expect(quiet.score >= normal.score, "Quiet Mode must not penalize carry-level input.")
	var notes: Array[Dictionary] = [{"id": 0, "t": 1.0, "kind": "sing",
		"duration": 0.3, "band": 0, "hold_kind": "sing"}]
	var normal := Judge.new(notes)
	normal.consume(Event.new(1.0, Event.SING, 1.0, 1, 0.2, true))
	normal.advance(2.0)
	var assisted := Judge.new(notes, {"any_sound": true})
	assisted.consume(Event.new(1.0, Event.ONSET))
	assisted.advance(2.0)
	expect(assisted.score >= normal.score, "Any sound must remove pitch/type penalties.")
	var rest_notes: Array[Dictionary] = [{"id": 0, "t": 1.0, "kind": "rest", "duration": 0.4}]
	var rest := Judge.new(rest_notes)
	rest.observe(Frame.new(1.2, 1.0))
	var result := rest.advance(1.5)
	expect(result.size() == 1 and int(result[0]["grade"]) == 3, "Sound on a Rest must be a miss.")

func _test_output_clock() -> void:
	for latency: float in [-100.0, 400.0]:
		for player_level: float in [0.4, 1.0]:
			var state := State.new(1, 0, 0, {"latency_ms": latency, "walkin_seconds": 0.0})
			var notes: Array[Dictionary] = [{"id": 0, "t": 1.0,
				"kind": "beat", "duration": 0.0}]
			state.judge = Judge.new(notes)
			var audio_time := 1.0 + latency / 1000.0
			state.register_output(audio_time, 0.25, 0.25)
			state.consume(Frame.new(audio_time, player_level, 1.0))
			state.judge.advance(1.2)
			expect(state.judge.hits == (1 if player_level == 1.0 else 0),
				"Compensated known output must reject speaker bleed, not the stronger player, at %.0f ms."
				% latency)

func _test_life_fury() -> void:
	var life := Life.new()
	life.advance(10.0, false, false, false)
	expect(life.life == 70.0, "Responses are safe breathing turns.")
	life.advance(1.5, true, false, false)
	expect(life.life == 70.0, "The silence grace is exact.")
	life.advance(0.5, true, false, false)
	expect(is_equal_approx(life.life, 60.0), "Only post-grace call silence drains.")
	life.advance(20.0, true, false, false)
	expect(life.dead and life.morale == 70.0, "Death reduces morale once.")
	for beat in 4:
		life.rally(beat * 0.6, 1.0, 0.0)
	expect(not life.dead and life.life == 50.0 and life.rallied, "Four grid Beats must rally.")
	for death in 3:
		life.advance(20.0, true, false, false)
		for beat in 4:
			life.rally(10.0 + death * 10.0 + beat * 0.6, 1.0, 0.0)
	expect(life.walkout, "Four dead chants exhaust morale.")
	var safe := Life.new()
	safe.never_dies = true
	safe.morale = 20.0
	safe.advance(20.0, true, false, false)
	expect(safe.dead and not safe.walkout and safe.morale == 0.0, "Assist preserves honest morale.")
	var clap := Fury.new()
	var shout := Fury.new()
	for hit in 32:
		clap.award(0, "beat", 1.0, 0.04)
		shout.award(0, "shout", 20.0, 4.0)
	expect(clap.charge == 100.0 and shout.charge == clap.charge,
		"Ideal clap/shout Fury must be equal; excess volume earns nothing.")
	expect(clap.activate(true) and not clap.activate(true), "One Fury per half.")
	clap.advance(9.0)
	clap.half = 2
	for hit in 32:
		clap.award(0, "beat", 1.0, 0.04)
	expect(clap.activate(true), "The second half may have its own Fury.")
	var crowd := Crowd.new()
	var before := crowd.phase_scatter
	crowd.judge(0)
	expect(crowd.phase_scatter < before, "Perfect pulls the crowd into phase.")
	crowd.judge(3)
	expect(crowd.phase_scatter > before, "Miss scatters the response.")

func _test_football() -> void:
	var a := Sim.new(8)
	var b := Sim.new(8)
	for step in 1000:
		a.advance(0.1, 80.0)
		b.advance(0.1, 80.0)
	expect(a.home == b.home and a.away == b.away and a.zone == b.zone,
		"Seed and energy must fully determine football.")
	var strong_wins := 0
	var weak_wins := 0
	for seed_value in 64:
		var strong := Sim.new(seed_value)
		var weak := Sim.new(seed_value)
		strong.advance(240.0, 100.0)
		weak.advance(240.0, 10.0)
		strong_wins += 1 if strong.home > strong.away else 0
		weak_wins += 1 if weak.home > weak.away else 0
	expect(strong_wins > weak_wins, "Energy must bias wins, not just animate the pitch.")
	expect(strong_wins < 64, "Even max energy must not guarantee every match.")

func _test_career_banner() -> void:
	var career := Career.new()
	for ground in 4:
		expect(career.ground_unlocked(ground), "The career must be traversable from fresh progress.")
		for stop in 3:
			career.record(ground, stop, 3, true)
	expect(career.ground_unlocked(4), "Nine stars per ground unlock the Final.")
	var before := career.stars.duplicate()
	career.record(0, 0, 5, false)
	expect(career.stars == before, "Quick play must not change career progress.")
	career.record(0, 0, 1, true)
	expect(career.best_stars(0, 0) == 3, "A worse replay cannot regress stars.")
	var path := "user://tifo_beato_model_test_%d.cfg" % OS.get_process_id()
	var records := Records.new()
	records.data["exhibits"] = ["tifo_3"]
	records.data["rivals"] = ["sandro"]
	records.record("rec", 1000, 4, 32)
	records.data["stars"] = career.stars
	expect(records.save_file(path) == OK, "Progress must save.")
	var stale := Records.new()
	stale.record("rec", 200, 1, 2)
	stale.data["exhibits"] = ["tifo_4"]
	expect(stale.save_file(path) == OK, "A stale writer must merge.")
	var restored := Records.new()
	restored.load_file(path)
	expect(int(restored.data["records"]["rec"]["noise"]) == 1000,
		"A stale save cannot erase a best record.")
	expect("tifo_3" in restored.data["exhibits"] and "tifo_4" in restored.data["exhibits"]
		and "sandro" in restored.data["rivals"], "Gallery discoveries must merge without regressing.")
	expect(not records._valid({"records": {"rec": "broken"}})
		and not records._valid({"stars": {"rec": []}})
		and not records._valid({"banner": {"mishaps": [3]}}),
		"Malformed nested progress must be rejected before a success-shaped load or write.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var identity := Identity.new()
	identity.town = 3
	identity.club = 2
	var copy := Identity.new()
	copy.from_data(identity.to_data())
	expect(identity.club_name() == copy.club_name(), "Curated identity must round-trip.")
	expect(not Words.safe_banner("ARBITRARY TEXT"), "No free text reaches a banner.")
	var banner := Banner.new()
	var clean := banner.render_image().get_data()
	banner.mishaps = ["backwards", "missing_letter", "paw_print", "googly_eyes"]
	expect(banner.render_image().get_data() != clean, "Mishaps must affect the real mosaic source.")
	expect(banner.bonus_scale() == 1.0, "Mishaps themselves do not reduce quality.")

func _test_extra_modes() -> void:
	for kind in Chaos.KINDS:
		var chaos := Chaos.new()
		chaos.begin(kind)
		for hit in 12:
			chaos.judge({"grade": 0, "kind": "hold" if kind == "rain" else (
				"rest" if kind == "kazoo" else "beat")})
		chaos.advance(40.0, 40.0, 0.6, false)
		expect(kind in chaos.successes, "Chaos success criterion: " + kind)
		var failed := Chaos.new()
		failed.begin(kind)
		failed.judge({"grade": 3, "kind": "beat"})
		failed.advance(40.0, 40.0, 0.6, false)
		expect(kind in failed.failures, "Chaos failure criterion: " + kind)
	var banner := Banner.new()
	var build := Build.new(banner)
	var brush := Cpu.new(build.judge.notes)
	for tick in ceili((build.duration + 0.5) * 100.0):
		var now := tick * 0.01
		build.consume(brush.frame_at(now))
		build.advance(now)
	expect(build.complete and banner.quality == 100.0, "A perfect build must finish at full quality.")
	var flag := Steward.new("flag")
	var coat := Steward.new("coat")
	for tick in 3250:
		var now := tick * 0.01
		var onset := tick % 60 == 0 and not flag.watching(now)
		flag.consume(Frame.new(now, 1.0 if onset else 0.0, 1.0 if onset else 0.0))
		coat.consume(Frame.new(now, 1.0, 1.0 if tick == 0 else 0.0, true, 0.0, 1.0))
		flag.advance(now)
		coat.advance(now)
	expect(flag.success and coat.success, "Both steward routes must be winnable by Buttons.")
	for rival in War.RIVALS.size():
		var war := War.new(19, rival)
		var source: Cpu
		var previous := -1
		for tick in ceili((war.duration + 0.5) * 100.0):
			var now := tick * 0.01
			war.advance(now)
			if war.phase != previous:
				previous = war.phase
				if war.input_seat() >= 0:
					var turn: Dictionary = war.phases[war.phase]
					var notes: Array[Dictionary] = []
					if war.judge != null:
						notes = war.judge.notes
					else:
						for hit in 8:
							notes.append({"t": float(turn["call_t"]) + hit * float(turn["beat"]),
								"kind": "beat", "duration": 0.04, "band": 0})
					source = Cpu.new(notes)
			if war.input_seat() >= 0 and source != null:
				war.consume(source.frame_at(now))
		expect(war.complete and war.scores[0] > 0 and not war.calls[0].is_empty(),
			"Every rival must support a complete real call/echo exchange.")
		expect(war.winner() == 0,
			"A perfect ordinary call/echo stream must be able to beat rival %d." % rival)
		expect(war.accepted.all(func(result: Dictionary) -> bool: return result.has("seat")),
			"Every call and echo result must retain its actual seat.")

func _test_full_match() -> void:
	for pool in 5:
		var state := State.new(71, 4, pool, {"half_seconds": 24.0, "walkin_seconds": 0.0,
			"rivals": 2, "quiet": true})
		var source := Cpu.new(state.judge.notes)
		var revision := -1
		for tick in ceili((state.chart.duration + 0.7) * 100.0):
			var now := tick * 0.01
			state.advance(now)
			if revision != state.chart_revision:
				revision = state.chart_revision
				source = Cpu.new(state.judge.notes.filter(func(note: Dictionary) -> bool:
					return not bool(note["done"])))
			state.consume(source.frame_at(now))
		expect(state.complete and state.judge.accuracy() > 0.95 and state.stars() >= 3,
			"Every original pool must be playable through the same acoustic pipeline: %d" % pool)
		expect(state.noise() > 0 and not state.tifo.revealed.is_empty(),
			"A strong match must produce actual Noise and a tifo: %d" % pool)
	var rallied := State.new(12, 1, 0, {"half_seconds": 24.0, "walkin_seconds": 0.0})
	rallied.advance(0.5)
	var banked := rallied.judge.score
	rallied._restart_loop(0.5)
	expect(rallied.chart.notes == rallied.judge.notes and rallied.judge.score == banked,
		"A rally must re-author the real note schedule without erasing banked points.")
	for slot in rallied.disruptions.slots:
		expect(float(slot["t"]) > rallied.time or rallied.disruptions._fired.has(
			rallied.disruptions.slots.find(slot)), "Rallies must not replay past disruptions.")
	rallied.fury.offer_power("drum")
	for shout in 3:
		if rallied.fury.triple_shout(10.0 + shout * 0.3, true):
			rallied.activate_power()
	expect(rallied.fury.active_power == "drum" and rallied.judge.notes.any(
		func(note: Dictionary) -> bool: return int(note["id"]) >= 10000),
		"Triple-shout activation must inject the same real Drum solo as the power key.")

func _test_goal_and_chaos() -> void:
	var state := State.new(3, 0, 0, {"rivals": 2, "half_seconds": 30.0, "walkin_seconds": 0.0})
	var duration := state.chart.duration
	state.goal_pending = "goal_away"
	var response: Dictionary = state.chart.phases.filter(func(phase: Dictionary) -> bool:
		return str(phase["kind"]) == "response")[0]
	state.advance(float(response["t"]) + 0.01)
	var goals: Array[Dictionary] = state.judge.notes.filter(func(note: Dictionary) -> bool:
		return note.has("goal"))
	expect(goals.size() == 16 and state.chart.duration == duration,
		"A goal must open four actual Beat bars without extending the match or moving future notes.")
	var optional := Judge.new(goals)
	optional.advance(duration + 1.0)
	expect(optional.attempts == 0 and optional.combo == 0,
		"Unused free-form goal beats cannot invent misses or damage a combo.")
	var last_phase: Dictionary = state.chart.phases[int(goals[-1]["phase"])]
	state.life.refill(70.0)
	var scarf := state.life.life
	state.advance(float(last_phase["end"]))
	expect(state.life.life == scarf and not state.life.dead,
		"Optional goal celebrations and defiance must be safe breathing windows.")
	var split := Chaos.new()
	split.begin("drum_skin")
	for beat in 8:
		split.judge({"grade": 0, "kind": "beat", "points": 120.0})
	split.advance(40.0, 40.0, 0.6, false)
	expect(split.resolutions.size() == 1 and float(split.resolutions[0]["points"]) == 960.0,
		"Winning the split drum must bank a second copy of the actual scored points.")
	var counted := State.new()
	counted.chaos = split
	var before := counted.bonus
	counted._resolve_chaos()
	counted._resolve_chaos()
	expect(counted.bonus - before == 1460.0, "A timed chaos resolution must pay exactly once.")
	var final := State.new(2026, 4, 0, {"rivals": 2, "quiet": true})
	var source: Cpu
	var revision := -1
	for tick in ceili((final.chart.duration + 0.7) * 100.0):
		var now := tick * 0.01
		final.advance(now)
		if revision != final.chart_revision:
			revision = final.chart_revision
			source = Cpu.new(final.judge.notes.filter(func(note: Dictionary) -> bool:
				return not bool(note["done"])))
		final.consume(source.frame_at(now))
	for kind in Chaos.KINDS:
		expect(kind in final.chaos.successes or kind in final.chaos.failures,
			"A completed Continental Final must actually run every chaos kind: " + kind)
	expect(final.complete and final.stars() >= 3,
		"The complete six-event Final must remain playable through ordinary acoustic frames.")
	expect(final.keeper_full_half and "tifo_beato_keeper_tremble" in final.achievement_ids(),
		"Ordinary ideal support must keep the keeper trembling throughout a complete half.")

func _test_goal_latency() -> void:
	for co_op in [false, true]:
		for latency in [-100.0, 400.0]:
			var state := State.new(3, 0, 2, {"rivals": 2, "half_seconds": 24.0,
				"walkin_seconds": 2.0, "two_capos": co_op, "headphones": true,
				"latency_ms": latency})
			var response: Dictionary = state.chart.phases.filter(func(phase: Dictionary) -> bool:
				return str(phase["kind"]) == "response")[0]
			var revision := -1
			var source: Cpu
			var queued := false
			var key := -1
			var grades: Array[Dictionary] = []
			for tick in ceili((state.chart.duration + 1.1) * 100.0):
				var now := tick * 0.01
				if not queued and now >= float(response["t"]) - 0.01:
					queued = true
					state.goal_pending = "goal_away"
				for event in state.advance(now):
					if str(event["kind"]) == "grade":
						grades.append(event["result"])
				if revision != state.chart_revision:
					revision = state.chart_revision
					source = Cpu.new(state.judge.notes.filter(func(note: Dictionary) -> bool:
						return not bool(note["done"])))
					for note in state.judge.notes:
						if note.has("goal") and key < 0:
							key = int(note["goal_key"])
				var raw := source.frame_at(now - latency / 1000.0)
				raw.t = now
				state.consume(raw)
			expect(key >= 0 and int(state._goal_counts.get(key, 0)) == 16,
				"All optional goal Beats must survive %.0f ms timing and co-op=%s." % [latency, co_op])
			if co_op and key >= 0:
				var goal_seat := maxi(0, int(state.chart.phases[key]["loop"])) % 2
				expect(grades.filter(func(result: Dictionary) -> bool:
					return int(result["note"].get("goal_key", -1)) == key).all(
						func(result: Dictionary) -> bool: return int(result["seat"]) == goal_seat),
					"Every late goal grade and direct bonus belongs to the authored verse's capo.")
				for phase in state.chart.phases:
					if str(phase["kind"]) == "handoff":
						expect(float(phase["end"]) - float(phase["t"]) - state.capture_tail() \
							>= float(phase["beat"]) * 2.0 - 0.000001,
							"The new capo retains two full guide beats after old capture's maximum tail.")
