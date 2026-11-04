extends GameShell

## One shell round owns a match or hot-seat set; every instrument shares its clock.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const State = preload("res://games/tifo_beato/match/match_state.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Build = preload("res://games/tifo_beato/workshop/build_race.gd")
const Steward = preload("res://games/tifo_beato/steward/steward_state.gd")
const Source = preload("res://games/tifo_beato/sound/input_stream.gd")
const Pad = preload("res://games/tifo_beato/sound/pad_source.gd")
const Profile = preload("res://games/tifo_beato/sound/voice_profile.gd")
const ClubIdentity = preload("res://games/tifo_beato/career/identity.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Career = preload("res://games/tifo_beato/career/career_state.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const Audio = preload("res://games/tifo_beato/audio/tifo_audio.gd")
const View = preload("res://games/tifo_beato/world/curva_view.gd")
const MatchHud = preload("res://games/tifo_beato/ui/match_hud.gd")
const Controls = preload("res://games/tifo_beato/ui/touch_controls.gd")
const Lobby = preload("res://games/tifo_beato/ui/lobby.gd")
const Soundcheck = preload("res://games/tifo_beato/ui/soundcheck.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
const Registration = preload("res://games/tifo_beato/game.gd")
var _state: State
var _war: War
var _build: Build
var _steward: Steward
var _source := Source.new()
var _pad := Pad.new()
var _audio: Audio
var _view: View
var _match_hud: MatchHud
var _controls: Controls
var _ui: Control
var _lobby: Lobby
var _soundcheck: Soundcheck
var _modal: Control
var _modal_panel: PanelContainer
var _ready_button: Button
var _modal_action: Callable
var _card_seat := 0
var _soundcheck_resume: Callable
var _railway_button: Button
var _records := Records.new()
var _career := Career.new()
var _club := ClubIdentity.new()
var _banner := Banner.new()
var _mic_profiles: Array[Profile] = [Profile.new(), Profile.new()]
var _button_profiles: Array[Profile] = [Profile.new(), Profile.new()]
var _instruments: Array[int] = [1, 1]
var _configuration: Dictionary = {}
var _request: Dictionary = {}
var _pending_request: Dictionary = {}
var _mode := "career"
var _stage := "lobby"
var _seat := 0
var _ground := 0
var _pool := 0
var _seed := 1
var _set_complete := false
var _input_started := false
var _input_locked := false
var _prebuild := false
var _halftime_played := false
var _war_is_halftime := false
var _completed_states: Array[State] = []
var _war_results: Array[Dictionary] = []
var _prelude: Dictionary = {}
var _handed_loops: Dictionary = {}
var _handed_turns: Dictionary = {}
var _all_results: Array[Dictionary] = []
var _response_queue: Dictionary = {}
var _snapshot: Dictionary = {}
var _played_seconds := 0.0
var _stage_last_time := 0.0
var _physical_touches: Dictionary = {}
var _blocked_touches: Dictionary = {}
var _blocked_keys: Array[int] = []
var _blocked_pads: Array[Dictionary] = []
var _blocked_mouse := false
var _save_status := ""
var _session_started := 0
var _resume_pending := false
var _finished_round_id := -1
var _capture_inset := 0.0

func game_id() -> String:
	return Options.GAME_ID

func _prepare_session() -> void:
	super()
	_session_started = Time.get_ticks_msec()
	if _records.load_file() != OK:
		_save_status = "Progress could not be read. Playing is allowed; saving is blocked."
	_career.merge(_records.data["stars"])
	Registration.refresh_gallery(manifest(), _records.data)
	_club.from_data(_records.data["identity"])
	_banner.from_data(_records.data["banner"])
	_banner.primary = ClubIdentity.COLORS[_club.primary]
	_banner.secondary = ClubIdentity.COLORS[_club.secondary]
	var selected := GameSession.selected_level()
	for index in 5:
		if str(Options.GROUNDS[index]["id"]) == str(selected.get("id", "")):
			_ground = index
	_pool = int(GameSession.character_for_player(0).get("pool", 0))
	for seat in 2:
		_instruments[seat] = Settings.tunable_choice(Options.INPUT)
		if _mic_profiles[seat].load_file(seat) != OK:
			_instruments[seat] = 1
			_save_status = "P%d soundcheck could not be read. Use Buttons or recalibrate." % (seat + 1)
		if _button_profiles[seat].load_file(seat, Profile.SAVE_PATH, "buttons") != OK:
			_save_status = "P%d button timing could not be read. Recalibrate to replace it." % (seat + 1)
		if not _button_profiles[seat].calibrated:
			_button_profiles[seat].make_virtual()
	_source.capture_failed.connect(_capture_failed)
	Store.equipped_changed.connect(_equipment_changed)

func _load_round_settings() -> void:
	super()
	_configuration = {
		"quiet": Settings.tunable_bool(Options.QUIET),
		"any_sound": Settings.tunable_bool(Options.ANY_SOUND),
		"windows": Settings.tunable_choice(Options.WINDOWS),
		"speed": Settings.tunable_choice(Options.SPEED),
		"never_dies": Settings.tunable_bool(Options.NEVER_DIES),
		"rivals": Settings.tunable_choice(Options.RIVALS),
		"commentator": Settings.tunable_choice(Options.COMMENTATOR) > 0,
		"chattiness": Settings.tunable_choice(Options.CHATTINESS),
	}

func _build_playfield() -> void:
	$HUD/Overlay/Margins.hide()
	_ui = Control.new()
	_ui.name = "TifoPlayFlow"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_ui)
	_view = View.new()
	_view.name = "CurvaView"
	_ui.add_child(_view)
	_match_hud = MatchHud.new()
	_match_hud.name = "AccessibleChantHUD"
	_match_hud.layout_changed.connect(_resize_layout)
	_ui.add_child(_match_hud)
	_controls = Controls.new()
	_controls.name = "IndependentTouchPads"
	_controls.action_changed.connect(_touch_action)
	_controls.screen_touch_changed.connect(_observe_touch)
	_ui.add_child(_controls)
	_pause_button.reparent(_ui)
	_pause_button.text = "Pause"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.show()
	_railway_button = Widgets.button(_ui, "Career railway / workshop", _return_to_lobby)
	_railway_button.hide()
	_audio = Audio.new()
	add_child(_audio)
	_view.reduced_motion = _reduced_motion_enabled
	_view.intense_effects = _intense_effects_enabled
	_customize_view()
	_view.configure(State.new(1, _ground, _pool))
	get_viewport().size_changed.connect(_resize_layout)
	_resize_layout()

func _begin_first_round() -> void:
	_show_lobby()

func _show_lobby(tab := -1) -> void:
	_stop_input()
	_audio.stop()
	_stage = "lobby"
	_input_locked = false
	_match_hud.hide()
	_controls.hide()
	_close_modal()
	if is_instance_valid(_lobby):
		_lobby.queue_free()
	_lobby = Lobby.new()
	_lobby.name = "CareerAndWorkbench"
	_lobby.identity = _club
	_lobby.banner = _banner
	_lobby.career = _career
	_lobby.records = _records
	_lobby.ground = _ground
	_lobby.player_count = GameSession.player_count()
	_lobby.instruments = _instruments.duplicate()
	_lobby.fabric_owned = [true, Store.is_owned(game_id(), "tb_fabric_tarp"),
		Store.is_owned(game_id(), "tb_fabric_silk"), Store.is_owned(game_id(), "tb_fabric_glitter")]
	_lobby.status = _save_status
	if Time.get_ticks_msec() - _session_started >= 900000:
		_lobby.status += "\nA natural voice break: water, a rest, or a few rounds on Buttons."
	if not _pending_request.is_empty():
		_lobby.status += "\nWorkshop first: finish the build, then your selected career match begins."
	_lobby.tab = tab if tab >= 0 else [0, 1, 1, 2][Settings.tunable_choice(Options.MODE)]
	_lobby.hot_seat_mode = Settings.tunable_choice(Options.HOT_SEAT)
	if GameSession.player_count() > 1:
		_lobby.tab = 1
	_lobby.group_names.clear()
	for seat in GameSession.player_count():
		_lobby.group_names.append(str(GameSession.character_for_player(seat).get("title", "")))
	_lobby.play_requested.connect(_choose_play)
	_lobby.soundcheck_requested.connect(_open_soundcheck)
	_lobby.instrument_selected.connect(_choose_instrument)
	_lobby.identity_changed.connect(_identity_edited)
	_lobby.fabric_selected.connect(_fabric_selected)
	_lobby.exit_requested.connect(func() -> void: Router.goto(main_menu_scene))
	_hud.add_child(_lobby)
	_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _return_to_lobby() -> void:
	_round_over.hide()
	_railway_button.hide()
	_show_lobby(2 if _mode == "workshop" else 0)

func _choose_instrument(seat: int, instrument: int) -> void:
	_instruments[seat] = instrument

func _choose_play(request: Dictionary) -> void:
	var requested := request.duplicate(true)
	if str(requested.get("mode", "")) == "workshop" and not _pending_request.is_empty():
		requested = _pending_request.duplicate(true)
		requested["prebuild"] = true
		_pending_request.clear()
	_request = requested
	_ground = int(_request.get("ground", 0))
	_mode = str(_request.get("mode", "quick"))
	for seat in GameSession.player_count():
		if _instruments[seat] == 0 and not _mic_profiles[seat].calibrated:
			_pending_request = _request.duplicate(true)
			_open_soundcheck(seat)
			return
	if _mode == "career" and not bool(_request.get("prepared", false)) \
		and not bool(_request.get("prebuild", false)):
		_show_card("THE LOCK-UP GARAGE", "Your saved banner: %.0f%% quality, %d mishaps.\n" % [
			_banner.quality, _banner.mishaps.size()] + "Build a new one, or take this one to kickoff.",
			0, "Use this banner - kickoff", func() -> void:
				_request["prepared"] = true
				_start_round())
		var body := _ready_button.get_parent()
		Widgets.button(body, "Workshop first", func() -> void:
			_pending_request = _request.duplicate(true)
			_show_lobby(2))
		return
	_start_round()

func _reset_round_state() -> void:
	_close_lobby()
	_close_modal()
	_stop_input()
	_input_locked = false
	_set_complete = false
	_snapshot.clear()
	_completed_states.clear()
	_war_results.clear()
	_all_results.clear()
	_handled_reset()
	_prelude.clear()
	_seat = 0
	_ground = int(_request.get("ground", _ground))
	_mode = str(_request.get("mode", "career" if GameSession.is_single_player() else "duel"))
	_seed = int(_request.get("seed", _rng.randi_range(1, 2000000000)))
	_prebuild = bool(_request.get("prebuild", false))
	_halftime_played = false
	_war_is_halftime = false
	_played_seconds = 0.0
	_stage_last_time = 0.0
	_war = null
	_build = null
	_steward = null
	var configuration := _configuration.duplicate(true)
	configuration["two_capos"] = _mode == "two_capos"
	var with_war := _mode == "career" and int(_request.get("stop", 0)) \
		== int(Options.GROUNDS[_ground]["matches"]) - 1
	_state = State.new(_seed, _ground, _pool, configuration, with_war)
	_state.banner = _banner
	_state.chart.rebuild_beats()
	_customize_view()
	_view.configure(_state)
	_match_hud.show()
	_controls.show()
	_match_hud.static_lane = Settings.tunable_bool(Options.STATIC_LANE)
	_controls.layout = Settings.tunable_choice(Options.TOUCH_LAYOUT)
	_resize_layout()

func _handled_reset() -> void:
	_handed_loops = {0: true}
	_handed_turns.clear()
	_response_queue.clear()

func _activate_round() -> void:
	if _prebuild or _mode == "workshop":
		_begin_build()
	elif _mode in ["war", "duel"]:
		_begin_war(false)
	elif _mode in ["flag", "coat"]:
		_begin_steward(_mode)
	elif _mode == "career" and int(_request.get("stop", 0)) \
		== int(Options.GROUNDS[_ground]["matches"]) - 1:
		_begin_steward("flag" if _ground % 2 == 0 else "coat")
	else:
		_begin_match()

func _begin_match(start := 0.0) -> void:
	_stage = "match"
	_customize_view()
	_view.configure(_state)
	_view.configure_activity(_state, "match")
	_stage_last_time = start
	_audio.play_track(_state.chart.beats, _state.chart.duration + 1.0, start)
	_match_hud.configure(_state, "match")
	_start_input()
	_caption("Walk-in: get comfortable. The guide drum sets your tempo." if start == 0.0 else (
		"SECOND HALF. Your scarf has unfinished business."))

func _begin_build() -> void:
	_stage = "workshop"
	_build = Build.new(_banner, int(Options.GROUNDS[_ground]["budget"]), _seed, _configuration)
	var beats: Array[float] = []
	for pulse in 82:
		beats.append(pulse * _build.beat_seconds)
	_audio.play_track(beats, _build.duration + 1.0)
	_stage_last_time = 0.0
	_match_hud.configure(_build, "workshop")
	_view.configure_activity(_build, "workshop")
	_start_input()

func _begin_steward(kind: String) -> void:
	_stage = "steward"
	_steward = Steward.new(kind)
	var beats: Array[float] = []
	for pulse in 55:
		beats.append(pulse * 0.6)
	_audio.play_track(beats, _steward.duration + 1.0)
	_stage_last_time = 0.0
	_match_hud.configure(_steward, "steward")
	_view.configure_activity(_steward, "steward")
	_start_input()
	_caption(_steward.caption())

func _begin_war(halftime: bool) -> void:
	_stop_input()
	_stage = "war"
	_war_is_halftime = halftime
	_war = War.new(_seed, _ground if halftime else int(_request.get("rival", 0)),
		_mode == "duel", _configuration)
	_handed_turns.clear()
	_audio.play_track(_war.beats, _war.duration + 1.0)
	_stage_last_time = 0.0
	_match_hud.configure(_war, "war")
	_view.configure_activity(_war, "war")
	_caption(_war.caption())
	_input_locked = false

func _start_input() -> void:
	_stop_input()
	if _input_locked or _soundcheck != null:
		return
	var profile := _mic_profiles[_seat] if _instruments[_seat] == 0 else _button_profiles[_seat]
	var quiet := bool(_configuration["quiet"]) or _stage == "workshop" \
		or _stage == "steward" and _steward.kind == "coat"
	_source.begin(self, _instruments[_seat], profile, _audio.now(), quiet)
	if _input_locked or _instruments[_seat] == 0 and _source.capture == null:
		return
	_input_started = true
	_pad.prime(GameSession.controller_device_for_player(_seat))
	var latency := clampf(profile.latency_ms + Settings.tunable(Options.LATENCY), -100.0, 400.0)
	if _stage == "match":
		_state._latency_ms = latency
		_state.classifier.reset()
		_state.classifier.noise_floor = _source.noise_floor()
		_state.classifier.band_width = profile.band_width_cents
		_state.gate.headphones = _instruments[_seat] == 1 \
			or Settings.tunable_bool(Options.HEADPHONES)
		_state.gate.emissions.clear()
	elif _stage == "war":
		_war.configuration["latency_ms"] = latency
		_war.classifier.noise_floor = _source.noise_floor()
		_war.classifier.band_width = profile.band_width_cents
	elif _stage == "workshop":
		_build.latency_ms = latency
		_build.classifier.noise_floor = _source.noise_floor()
		_build.classifier.band_width = profile.band_width_cents
	elif _stage == "steward":
		_steward.latency_ms = latency
		_steward.classifier.noise_floor = _source.noise_floor()
		_steward.classifier.band_width = profile.band_width_cents
	_controls.enabled = true
	_match_hud.player_label = "P%d - %s" % [_seat + 1,
		"MIC" if _instruments[_seat] == 0 else "BUTTONS"]
	_match_hud.player_color = _player_color(_seat)
	_view.player_color = _player_color(_seat)
	_view.active_seat = _seat
	_view.capo.player_color = _player_color(0) if _stage == "war" else _player_color(_seat)
	_view.capo.primary = _view.primary
	_view.capo.outfit = _view.outfit
	_view.capo.crest = _club.crest
	_view.capo.rebuild()

func _stop_input() -> void:
	_input_started = false
	_source.close()
	_pad.reset()
	if _audio != null:
		_audio.stop_voices()
	if _controls != null:
		_controls.release_all()
		_controls.enabled = false

func _process(delta: float) -> void:
	super(delta)
	_round_elapsed = _played_seconds
	if _ready_button != null:
		_ready_button.disabled = not _contacts_released()
	if _railway_button != null:
		_railway_button.visible = _round_over.visible and _round_panel.visible \
			and _modal == null and _lobby == null and _soundcheck == null

func _update_round(_delta: float, _time_left: float) -> void:
	if _input_locked or _soundcheck != null:
		if _ready_button != null:
			_ready_button.disabled = not _contacts_released()
		return
	var now := _audio.now()
	var target := now
	var reached: Array[Dictionary] = []
	var handoff := _next_handoff(now)
	if not handoff.is_empty():
		target = float(handoff["t"])
	if _input_started:
		var pad := _pad.poll(GameSession.controller_device_for_player(_seat), target, _source.keys)
		if bool(pad["fury"]):
			_fury_pressed()
		if bool(pad["power"]):
			_power_pressed()
		for frame in _source.frames_until(target):
			if _instruments[_seat] == 1:
				_audio.instrument_frame(frame)
			match _stage:
				"match":
					reached.append_array(_state.advance(frame.t))
					_state.consume(frame)
				"war":
					reached.append_array(_war.advance(frame.t))
					_war.consume(frame)
				"workshop":
					reached.append_array(_build.advance(frame.t))
					_build.consume(frame)
				"steward":
					_steward.advance(frame.t)
					_steward.consume(frame)
	_played_seconds += maxf(0.0, target - _stage_last_time)
	_stage_last_time = target
	_round_elapsed = _played_seconds
	match _stage:
		"match": _update_match(target, reached)
		"war": _update_war(target, reached)
		"workshop": _update_build(target, reached)
		"steward": _update_steward(target)
	if not handoff.is_empty() and not _input_locked and _round_active:
		_audio.seek(target)
		if handoff.has("loop"):
			_handed_loops[int(handoff["loop"])] = true
		else:
			_handed_turns[int(handoff["turn"])] = true
		var next := int(handoff["seat"])
		_seat = next
		_show_card("PASS THE MEGAPHONE", "P%d - %s.\nRelease the old controls. " % [
			next + 1, _player_name(next)] + "One private microphone, never two voices at once.\n"
			+ "A guide count-in follows your confirmation.", next, "Ready - my turn",
			func() -> void:
				_seat = next
				_audio.set_paused(false)
				_start_input())
	_controls.set_power(_state.fury.power if _stage == "match" else "")
	_match_hud.present()
	_view.present()

func _next_handoff(now: float) -> Dictionary:
	if _stage == "match" and _state.two_capos:
		var latency := _state.capture_tail()
		for phase in _state.chart.phases:
			var loop := int(phase["loop"])
			if str(phase["kind"]) == "handoff" and not _handed_loops.has(loop) \
				and now >= float(phase["t"]) + latency:
				return {"t": float(phase["t"]) + latency, "loop": loop, "seat": loop % 2}
	elif _stage == "war":
		for turn in range(1, _war.phases.size()):
			var phase := _war.phases[turn]
			var human := not _war.cpu_rival or int(phase["seat"]) == 0
			if human and not _handed_turns.has(turn) and now >= float(phase["t"]) \
				and (turn == 1 or int(_war.phases[turn - 1]["seat"]) != int(phase["seat"])):
				return {"t": float(phase["t"]) + 0.001, "turn": turn, "seat": int(phase["seat"])}
	return {}

func _update_match(now: float, reached: Array[Dictionary] = []) -> void:
	reached.append_array(_state.advance(now))
	for event in reached:
		var kind := str(event["kind"])
		if kind == "grade":
			var result: Dictionary = event["result"]
			_all_results.append(result)
			_match_hud.grade(result, now)
		elif kind == "phase":
			_phase_audio(float(event.get("t", now)))
			_caption(str(event["text"]))
		elif kind in ["rally_restart", "chart_changed"]:
			_audio.play_track(_state.chart.beats, _state.chart.duration + 1.0, now)
		else:
			if event.has("text"):
				_caption(str(event["text"]))
			if kind in ["air_horn", "trumpet", "rival_drums", "inflatable"]:
				var length := _rival_audio_length(now, kind, float(event["beat"]))
				if length > 0.0:
					_state.register_output(now, _source.measured_bleed(), length)
					_audio.disruption(kind, float(event["beat"]), length, float(event.get("level", 1.0)))
				_caption(State.Disruptions.CAPTIONS[kind])
			elif kind in ["fury", "power", "tifo", "goal_home", "goal_away", "whistle"] \
				and not _state.judging(now):
				_state.register_output(now, _source.measured_bleed(), 0.25)
				_audio.cue(kind)
	if not _response_queue.is_empty() and now >= float(_response_queue["t"]):
		var phase: Dictionary = _response_queue["phase"]
		var call: Array[Dictionary] = []
		for result in _all_results:
			if int(result["note"].get("phase", -1)) == int(phase["call_phase"]):
				call.append(result)
		var length := maxf(0.0, float(phase["end"]) - now - 0.2)
		if length > 0.0 and not _state.judging(now):
			var original: Dictionary = _state.chart.phases[int(phase["call_phase"])]
			_audio.response(call, float(original["t"]), length, _state.crowd.phase_scatter,
				_state.fury.active_power == "megaphone")
			_state.register_output(now, _source.measured_bleed(), length)
		_response_queue.clear()
	_audio.guide_enabled(_state.chaos.active not in ["power_cut", "drum_skin"])
	_scores[_seat] = _state.noise()
	if _state.two_capos:
		for seat in 2:
			_scores[seat] = roundi(_state.player_points[seat] * float(Options.GROUNDS[_ground]["size_scale"]))
	_best_streaks[_seat] = _state.judge.best_combo
	if not _halftime_played and str(_state.phase()["kind"]) == "halftime" \
		and now >= _state.chart.halftime_start + _state.capture_tail() \
		and _mode == "career" and int(_request.get("stop", 0)) \
		== int(Options.GROUNDS[_ground]["matches"]) - 1:
		_halftime_played = true
		_begin_war(true)
		return
	if _state.complete:
		_completed_states.append(_state)
		if _mode == "split" and _seat == 0:
			_stop_input()
			_audio.set_paused(true)
			_show_card("SPLIT THE STANDS", "P1 banked %d Noise.\n" % _state.noise()
				+ "P2 gets the identical seed, chart and rules. Results and Tokens wait for P2.",
				1, "Ready - P2's full match", _start_split_second)
		else:
			_set_complete = true
			_end_round()
			if _mode == "career" and _ground == 4 and _state.stars() >= 3:
				_show_card("THE WHOLE CITY", "Attendance: the whole city.\n"
					+ "Kevin still has the kazoo. You still have the bucket.\n"
					+ "The fence found its voice. FORZA!", 0, "See the match results",
					func() -> void: pass)

## A late render batch may keep a visual event, but cannot force unsafe audio.
func _rival_audio_length(now: float, kind: String, beat: float) -> float:
	var chart := _state.chart
	var phase := chart.phase_at(now)
	var length := State.Chart.DISRUPTION_TRANSIENT
	if str(phase["kind"]) == "response" and not _state.judging(now):
		length = minf(float(phase["end"]) - now - State.Chart.DISRUPTION_BEFORE,
			beat * (16.0 if kind == "rival_drums" else 8.0))
	var corrected := now - _state._latency_ms / 1000.0
	for note in _state.judge.notes:
		if bool(note.get("superseded", false)):
			continue
		var start := float(note["t"]) - State.Chart.DISRUPTION_BEFORE
		var end := float(note["t"]) + float(note["duration"]) + State.Chart.DISRUPTION_AFTER
		if corrected >= start and corrected <= end:
			return 0.0
		if corrected < start:
			length = minf(length, start - corrected)
	return length if length >= State.Chart.DISRUPTION_TRANSIENT else 0.0

func _phase_audio(now: float) -> void:
	var phase := _state.chart.phase_at(now)
	if _state.chart.is_judging(now):
		_audio.stop_voices()
	if str(phase["kind"]) == "response":
		_response_queue = {"t": float(phase["t"]) + _state.capture_tail() + 0.04, "phase": phase}
	else:
		_response_queue.clear()
	_match_hud.caption = str(phase["lyric"]).replace("{CLUB}", _club.lyric_slot())

func _update_war(now: float, reached: Array[Dictionary] = []) -> void:
	reached.append_array(_war.advance(now))
	for event in reached:
		var kind := str(event["kind"])
		if kind == "turn":
			_audio.stop_voices()
			_caption(str(event["text"]))
			if _war.input_seat() < 0:
				_stop_input()
				_match_hud.player_label = "RIVAL - " + str(War.RIVALS[_war.rival]["title"])
			elif not _input_started and not _input_locked:
				_seat = _war.input_seat()
		elif kind == "grade":
			_match_hud.grade(event["result"], now)
		elif kind == "rival_note":
			_audio.capo(int(event["band"]))
		elif kind == "empty_call":
			_caption(str(event["text"]))
	if not _war_is_halftime:
		_scores[0] = roundi(_war.scores[0])
		_scores[1] = roundi(_war.scores[1]) if _mode == "duel" else 0
	if _war.complete:
		var result := {"winner": _war.winner(), "rival": _war.rival,
			"scores": _war.scores.duplicate(), "exchanges": _war.exchange_wins.duplicate()}
		_war_results.append(result)
		_stop_input()
		_audio.stop()
		if _war_is_halftime:
			var won := _war.winner() == 0
			if won:
				_state._add_bonus(1000.0)
				_state.fury.charge = minf(100.0, _state.fury.charge + 50.0)
			else:
				_state.life.morale = maxf(0.0, _state.life.morale - 15.0)
			_show_card("THE POETIC SALUTE", "You won the sing-off. +1,000 Noise and Fury charge."
				if won else "The rival takes the sing-off. Morale -15; your second half is still yours.",
				0, "Ready - second half", func() -> void:
					_seat = 0
					_state.advance(_state.chart.halftime_end)
					_begin_match(_state.chart.halftime_end))
		else:
			_set_complete = true
			_end_round()

func _update_build(now: float, reached: Array[Dictionary] = []) -> void:
	reached.append_array(_build.advance(now))
	for result in reached:
		_match_hud.grade(result, now)
	_scores[0] = roundi(_build.judge.score)
	_best_streaks[0] = _build.judge.best_combo
	if _build.complete:
		_save_progress()
		if _prebuild:
			_prebuild = false
			_request["prebuild"] = false
			_show_card("THE BANNER IS READY", "%.0f%% quality. %d comic mishaps.\n" % [
				_banner.quality, _banner.mishaps.size()] + "The crowd loves it anyway.",
				0, "Continue to kickoff", func() -> void:
					_scores.fill(0)
					if int(_request.get("stop", 0)) == int(Options.GROUNDS[_ground]["matches"]) - 1:
						_begin_steward("flag" if _ground % 2 == 0 else "coat")
					else:
						_view.configure(_state)
						_begin_match())
		else:
			_set_complete = true
			_end_round()

func _update_steward(now: float) -> void:
	var watching := _steward.watching(_steward.time)
	_steward.advance(now)
	if _steward.kind == "flag" and watching != _steward.watching(now):
		_caption(_steward.caption())
	if not _steward.complete:
		return
	_prelude = {"kind": _steward.kind, "success": _steward.success,
		"mistakes": _steward.mistakes}
	if _mode in ["flag", "coat"]:
		_set_complete = true
		_scores[0] = _steward.progress if _mode == "flag" else roundi(_steward.hum_seconds * 10.0)
		_end_round()
		return
	if _steward.success:
		if _steward.kind == "flag":
			_state.tifo.max_tier = mini(5, _state.tifo.max_tier + 1)
			_state.tifo.pending = true
		else:
			_state.fury.offer_power("drum")
	_show_card("VERY THOROUGH STEWARDS", "Your item made it through. A bonus joins the match."
		if _steward.success else "The item is politely confiscated, then returned after the match.\n"
			+ "No penalty to your basic timing rules.", 0, "Ready - kickoff", _begin_match)

func _start_split_second() -> void:
	_seat = 1
	_state = State.new(_seed, _ground, _pool, _configuration)
	_state.banner = _banner
	_state.chart.rebuild_beats()
	_all_results.clear()
	_view.configure(_state)
	_begin_match()

func _show_card(title: String, text: String, seat: int, action_text: String,
	action: Callable) -> void:
	_stop_input()
	_audio.set_paused(true)
	_input_locked = true
	_card_seat = seat
	_blocked_touches = _physical_touches.duplicate()
	_blocked_keys.clear()
	_blocked_pads.clear()
	_blocked_mouse = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	for binding in Options.CONTROL_BINDINGS:
		var code := Settings.binding_keycode(str(binding["key"]))
		if Input.is_physical_key_pressed(code):
			_blocked_keys.append(code)
	for device in Input.get_connected_joypads():
		for button in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER,
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y, JOY_BUTTON_B]:
			if Input.is_joy_button_pressed(device, button):
				_blocked_pads.append({"device": device, "button": button})
		for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			if Input.get_joy_axis(device, axis) > 0.35:
				_blocked_pads.append({"device": device, "axis": axis})
	_close_modal()
	_modal = Control.new()
	_modal.name = "DeliberateHandoff"
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	_modal_panel = PanelContainer.new()
	_modal.add_child(_modal_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_modal_panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	Widgets.label(body, title, true)
	var name_label := Widgets.label(body, "P%d - %s" % [seat + 1, _player_name(seat)])
	name_label.add_theme_color_override("font_color", _player_color(seat))
	Widgets.label(body, text)
	_ready_button = Widgets.button(body, action_text, _confirm_card)
	_modal_action = action
	_hud.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Widgets.scale_tree(body, Widgets.factor(_ui))
	_fit_modal()
	_ready_button.disabled = not _contacts_released()
	_ready_button.grab_focus.call_deferred()

func _confirm_card() -> void:
	if not _contacts_released():
		return
	var action := _modal_action
	_close_modal()
	_input_locked = false
	action.call()

func _contacts_released() -> bool:
	_blocked_keys = _blocked_keys.filter(func(code: int) -> bool:
		return Input.is_physical_key_pressed(code))
	_blocked_pads = _blocked_pads.filter(func(held: Dictionary) -> bool:
		return Input.is_joy_button_pressed(int(held["device"]), int(held["button"])) \
			if held.has("button") else Input.get_joy_axis(
				int(held["device"]), int(held["axis"])) > 0.35)
	_blocked_mouse = _blocked_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return _blocked_touches.is_empty() and _blocked_keys.is_empty() \
		and _blocked_pads.is_empty() and not _blocked_mouse

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_observe_touch(event.index, event.pressed)

func _observe_touch(pointer: int, pressed: bool) -> void:
	if pressed:
		_physical_touches[pointer] = true
	else:
		_physical_touches.erase(pointer)
		_blocked_touches.erase(pointer)

func _handle_gameplay_input(event: InputEvent) -> void:
	if _input_locked or not _input_started or event is InputEventKey and event.echo:
		return
	for action in Options.SOUND_ACTIONS:
		if event.is_action_pressed(action) or event.is_action_released(action):
			_source.set_action(action, event.is_action_pressed(action), _audio.now(), "key_" + str(action))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(Options.FURY):
		_fury_pressed()
	elif event.is_action_pressed(Options.POWER):
		_power_pressed()

func _touch_action(action: StringName, pressed: bool, contact: String) -> void:
	if not _round_active or _input_locked or not _input_started:
		return
	if action in Options.SOUND_ACTIONS:
		_source.set_action(action, pressed, _audio.now(), contact)
	elif pressed and action == Options.FURY:
		_fury_pressed()
	elif pressed and action == Options.POWER:
		_power_pressed()

func _fury_pressed() -> void:
	if _stage == "match":
		_state.activate_fury()

func _power_pressed() -> void:
	if _stage == "match":
		_state.activate_power()

func _caption(text: String) -> void:
	_match_hud.caption = text.replace("{CLUB}", _club.lyric_slot())
	AudioManager.request_caption(_match_hud.caption)

func _open_soundcheck(seat: int) -> void:
	_stop_input()
	_audio.set_paused(true)
	_soundcheck_resume = _modal_action if _modal != null else Callable()
	_close_modal()
	_input_locked = true
	_soundcheck = Soundcheck.new()
	_soundcheck.seat = seat
	_soundcheck.instrument = _instruments[seat]
	var profile := _mic_profiles[seat] if _instruments[seat] == 0 else _button_profiles[seat]
	_soundcheck.profile.from_data(profile.to_data())
	_soundcheck.profile.headphones = Settings.tunable_bool(Options.HEADPHONES)
	_soundcheck.bindings = [Settings.binding_keycode("controls/tifo_beato_beat_left"),
		Settings.binding_keycode("controls/tifo_beato_beat_right")]
	_soundcheck.completed.connect(_soundcheck_done)
	_soundcheck.cancelled.connect(_soundcheck_cancelled.bind(seat))
	_hud.add_child(_soundcheck)
	_soundcheck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _soundcheck_done(value: RefCounted, seat: int, instrument: int, any_sound: bool) -> void:
	if instrument == 0:
		_mic_profiles[seat] = value as Profile
	else:
		_button_profiles[seat] = value as Profile
	if any_sound:
		Settings.set_value(Options.ANY_SOUND, true)
	Settings.set_value(Options.HEADPHONES, (value as Profile).headphones)
	_close_soundcheck()
	if _soundcheck_resume.is_valid():
		var action := _soundcheck_resume
		_soundcheck_resume = Callable()
		_show_card("SOUNDCHECK SAVED", "Your measured profile stays with P%d." % (seat + 1),
			seat, "Ready - continue", action)
	elif not _pending_request.is_empty():
		var request := _pending_request.duplicate(true)
		_pending_request.clear()
		_choose_play(request)
	elif _round_active:
		_show_card("SOUNDCHECK SAVED", "Your measured profile stays with P%d." % (seat + 1),
			seat, "Ready - resume", func() -> void:
				_audio.set_paused(false)
				_start_input())
	else:
		_show_lobby()

func _soundcheck_cancelled(use_buttons: bool, seat: int) -> void:
	if use_buttons:
		_instruments[seat] = 1
	_close_soundcheck()
	if _soundcheck_resume.is_valid():
		var action := _soundcheck_resume
		_soundcheck_resume = Callable()
		_show_card("READY WHEN YOU ARE", "Capture is stopped. Release the previous inputs.",
			seat, "Ready - continue", action)
	elif _round_active:
		_show_card("READY WHEN YOU ARE", "Capture is stopped. Release the previous inputs.",
			seat, "Resume on " + ("Buttons" if _instruments[seat] == 1 else "Microphone"),
			func() -> void:
				_audio.set_paused(false)
				_start_input())
	else:
		_pending_request.clear()
		_show_lobby()

func _close_soundcheck() -> void:
	if is_instance_valid(_soundcheck):
		_soundcheck.stop_capture()
		_soundcheck.queue_free()
	_soundcheck = null
	_input_locked = false

func _capture_failed(reason: String) -> void:
	_instruments[_seat] = 1
	_show_card("MICROPHONE UNAVAILABLE", reason + "\nButtons play every note and earn every bonus.",
		_seat, "Continue on Buttons", func() -> void:
			_audio.set_paused(false)
			_start_input())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _audio != null:
		_audio.set_paused(true)
		_stop_input()
		_physical_touches.clear()
		_blocked_touches.clear()
		_resume_pending = true

func _on_pause_closed() -> void:
	super()
	if not _resume_pending:
		return
	_resume_pending = false
	if Settings.tunable_bool(Options.SOUNDCHECK):
		Settings.set_value(Options.SOUNDCHECK, false)
		_open_soundcheck(_card_seat if _modal != null else _seat)
	elif _round_active and not _input_locked:
		_audio.set_paused(false)
		if _stage != "war" or _war.input_seat() >= 0:
			_start_input()

func _finish_round() -> void:
	_stop_input()
	if _audio != null:
		_audio.stop()
	_close_modal()
	_close_lobby()
	if _match_hud != null:
		_match_hud.hide()
		_controls.hide()
	if not _set_complete or _finished_round_id == _round_id:
		return
	_finished_round_id = _round_id
	if not _completed_states.is_empty():
		for completed in _completed_states:
			_records.record(_record_key(), completed.noise(), completed.stars(),
				completed.judge.best_combo)
			for tier in completed.tifo.revealed:
				var exhibit := "tifo_%d" % tier
				if exhibit not in _records.data["exhibits"]:
					_records.data["exhibits"].append(exhibit)
		_career.record(_ground, int(_request.get("stop", 0)), _state.stars(), _mode == "career")
	for result in _war_results:
		if int(result["winner"]) == 0 and _mode != "duel":
			var id := str(War.RIVALS[int(result["rival"])]["id"])
			if id not in _records.data["rivals"]:
				_records.data["rivals"].append(id)
	_save_progress()
	_snapshot = {"tb_banner_snapshot": _banner.to_data(), "tb_identity_snapshot": _club.to_data(),
		"tb_outfit_snapshot": _outfit(), "tb_ground_snapshot": _ground,
		"tb_mode_snapshot": _mode, "tb_seed": _seed,
		"tb_football": "%d : %d" % [_state.sim.home, _state.sim.away],
		"tb_stars": _state.stars(), "tb_assisted": _assisted(),
		"tb_score_snapshot": _scores.duplicate(), "tb_combo_snapshot": _best_streaks.duplicate(),
		"tb_seconds_snapshot": _played_seconds, "tb_group_snapshot": _club.group_name(),
		"tb_club_snapshot": _club.club_name(), "tb_tifos_snapshot": _state.tifo.revealed.duplicate()}

func _end_round() -> void:
	if _set_complete and _finished_round_id == _round_id and not _round_active:
		return
	super()

func _record_key() -> String:
	return _career.stop_key(_ground, int(_request.get("stop", 0))) if _mode == "career" else (
		"quick_%s_pool%d" % [Options.GROUNDS[_ground]["id"], _pool])

func _save_progress() -> void:
	_records.data["identity"] = _club.to_data()
	_records.data["banner"] = _banner.to_data()
	_records.data["stars"] = _career.stars.duplicate()
	if _records.save_file() != OK:
		_save_status = "PROGRESS NOT SAVED. The previous file was preserved."
	Registration.refresh_gallery(manifest(), _records.data)

func _round_points_earned(player_one_total: int, player_two_total: int) -> int:
	if not _set_complete or _mode in ["workshop", "flag", "coat"] \
		or maxi(player_one_total, player_two_total) <= 0:
		return 0
	var points := super(player_one_total, player_two_total)
	for result in _war_results:
		if int(result["winner"]) == 0 and _mode != "duel":
			points += 10
	return mini(points, 120)

func _award_round_achievements(_one: int, _two: int) -> void:
	if not _set_complete:
		return
	for state in _completed_states:
		for id in state.achievement_ids():
			_unlock_round_achievement(id)
	if _mode == "career":
		for index in 4:
			if _career.ground_stars(index) >= Career.PROMOTION_STARS:
				_unlock_round_achievement(Career.PROMOTIONS[index])
		if _ground == 4 and _state.stars() >= 3:
			_unlock_round_achievement("tifo_beato_final")
		if bool(_prelude.get("success", false)) and str(_prelude.get("kind", "")) == "flag" \
			and int(_prelude.get("mistakes", 1)) == 0:
			_unlock_round_achievement("tifo_beato_smuggler")
	for result in _war_results:
		if int(result["winner"]) >= 0 and (_mode == "duel" or int(result["winner"]) == 0):
			_unlock_round_achievement("tifo_beato_chant_war")
	if War.RIVALS.all(func(rival: Dictionary) -> bool:
		return str(rival["id"]) in _records.data["rivals"]):
		_unlock_round_achievement("tifo_beato_all_rivals")
	if _mode == "duel" or _mode in ["two_capos", "split"] \
		and _completed_states.all(func(completed: State) -> bool:
			return not completed.life.walkout):
		_unlock_round_achievement("tifo_beato_two_capos")

func _round_totals() -> Dictionary:
	var hits := 0
	var attempts := 0
	for seat in GameSession.player_count():
		var stats := _player_stats(seat)
		hits += int(stats["hits"])
		attempts += int(stats["hits"]) + int(stats["misses"])
	return {"hits": hits, "attempts": attempts}

func _player_stats(seat: int) -> Dictionary:
	var hits := 0
	var attempts := 0
	var details: Array[Dictionary] = []
	if _stage == "workshop" and _build != null:
		hits = _build.judge.hits
		attempts = _build.judge.attempts
		details = [{"label": "Banner quality", "value": "%.0f%%" % _banner.quality},
			{"label": "Mishaps", "value": str(_banner.mishaps.size())}]
	elif _stage == "war" and _war != null:
		for event in _war.accepted:
			if int(event.get("seat", 0)) == seat:
				attempts += 1
				hits += 1 if int(event.get("grade", 0)) < 3 else 0
		details = [{"label": "Exchanges", "value": str(_war.exchange_wins[seat])}]
	elif _state != null:
		var state := _completed_states[seat] if _mode == "split" \
			and seat < _completed_states.size() else _state
		hits = state.player_hits[seat] if _mode == "two_capos" else state.judge.hits
		attempts = state.player_attempts[seat] if _mode == "two_capos" else state.judge.attempts
		details = [{"label": "Football", "value": "%d : %d" % [state.sim.home, state.sim.away]},
			{"label": "Stars", "value": "%d / 5" % state.stars()},
			{"label": "Chant deaths", "value": str(state.life.deaths)},
			{"label": "Tifos", "value": str(state.tifo.revealed.size())},
			{"label": "Assists", "value": "ON" if _assisted() else "OFF"}]
	return {"score": _scores[seat], "hits": hits, "misses": maxi(0, attempts - hits),
		"accuracy": roundi(float(hits) / attempts * 100.0) if attempts > 0 else 0,
		"streak": _best_streaks[seat], "details": details}

func _describe_round_outcome(one: int, two: int) -> Dictionary:
	var result := "THE WHISTLE"
	var subtitle := "Round stopped early. No invented finish, promotion or Tokens."
	if _set_complete:
		if _mode == "workshop":
			result = "THE BANNER IS READY"
			subtitle = "%.0f%% quality. %d mishaps. Ready for the next match." % [
				_banner.quality, _banner.mishaps.size()]
		elif _mode in ["flag", "coat"]:
			result = "SMUGGLED" if _steward.success else "POLITELY CONFISCATED"
			subtitle = "Practice only. The item is always returned with a very thorough note."
		elif _mode in ["war", "duel"]:
			result = "DRAW" if _war.winner() < 0 else (
				(str(War.RIVALS[_war.rival]["title"]).to_upper() if _mode == "war"
					and _war.winner() == 1 else "P%d" % (_war.winner() + 1)) + " TAKES THE SING-OFF")
			subtitle = "Five real call/echo exchanges. %d : %d exchange wins." % [
				_war.exchange_wins[0], _war.exchange_wins[1]]
		else:
			result = "ONE WHOLE CURVA" if _mode == "two_capos" else ("%d STARS" % _state.stars())
			if _mode == "split":
				result = "DRAW" if one == two else ("P1 LEADS THE STAND" if one > two else "P2 LEADS THE STAND")
			subtitle = "%s | Football %d : %d. Stars follow your chant, not the pitch." % [
				Options.GROUNDS[_ground]["title"], _state.sim.home, _state.sim.away]
	if not _save_status.is_empty():
		subtitle += "\n" + _save_status
	return {"result": result, "subtitle": subtitle, "color": Options.BUCKET}

func _round_highlight_summary() -> String:
	var summary := "Every instrument counts. " + super()
	if _state != null and _set_complete and _mode not in ["war", "duel", "workshop", "flag", "coat"]:
		summary = _state.judge.combo_name() + " | " + summary
	return summary

func _share_payload() -> Dictionary:
	var payload := super()
	payload.merge(_snapshot.duplicate(true), true)
	payload["score_caption"] = "CURVA NOISE"
	payload["footer"] = "Tifo Beato - Ninety minutes. No silence."
	return payload

func _assisted() -> bool:
	return bool(_configuration.get("quiet", false)) or bool(_configuration.get("any_sound", false)) \
		or int(_configuration.get("windows", 0)) > 0 or int(_configuration.get("speed", 100)) < 100 \
		or bool(_configuration.get("never_dies", false)) or int(_configuration.get("rivals", 0)) > 0

func _configure_mode_ui() -> void:
	super()
	_callout.text = "Tifo Beato - your chant owns the match."
	_hint.text = "Square Beat, circle Shout, pitch diamonds/triangles, Hold and X Rest."
	if _controls != null:
		_controls.key_labels.clear()
		for binding in Options.CONTROL_BINDINGS:
			_controls.key_labels.append(Settings.binding_key_label(str(binding["key"])))
		_controls.queue_redraw()

func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Options.STATIC_LANE and _match_hud != null:
		_match_hud.static_lane = Settings.tunable_bool(key)
	elif key == Options.TOUCH_LAYOUT and _controls != null:
		_controls.layout = Settings.tunable_choice(key)
		_resize_layout()
	elif key == "ui/scale":
		_resize_layout()

func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_reduced_motion(value)

func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_intense_effects(value)

func _identity_edited() -> void:
	_save_progress()
	_customize_view()
	_view.build()

func _outfit() -> Dictionary:
	var outfit: Dictionary = {}
	for slot in Options.STORE_SLOTS:
		outfit[str(slot["kind"])] = Store.equipped_id(game_id(), str(slot["id"]))
	return outfit

func _customize_view() -> void:
	_view.primary = ClubIdentity.COLORS[_club.primary]
	_view.secondary = ClubIdentity.COLORS[_club.secondary]
	_view.outfit = _outfit()
	_view.crest = _club.crest
	_view.scarf_pattern = _club.pattern
	_view.first_player_color = _player_color(0)
	_view.second_player_color = _player_color(1)
	_match_hud.club = _club.lyric_slot()
	_match_hud.group = _club.group_name()

func _equipment_changed(id: String, _slot: String, _item: String) -> void:
	if id == game_id() and _view != null:
		if _slot == "tb_fabric":
			var fabric := ["tb_fabric_sheet", "tb_fabric_tarp", "tb_fabric_silk",
				"tb_fabric_glitter"].find(_item)
			if fabric >= 0:
				_banner.fabric = fabric
				_save_progress()
			else:
				_save_status = "The selected fabric is unavailable; the current banner was kept."
				push_warning(_save_status)
		_customize_view()
		_view.build()

func _fabric_selected(index: int) -> void:
	var id: String = ["tb_fabric_sheet", "tb_fabric_tarp", "tb_fabric_silk",
		"tb_fabric_glitter"][index]
	if not Store.equip(game_id(), id, "tb_fabric"):
		_save_status = "Fabric could not be equipped. The previous store selection was preserved."
		push_warning(_save_status)

func _resize_layout() -> void:
	if _ui == null:
		return
	var dimensions := get_viewport_rect().size
	dimensions.y = maxf(1.0, dimensions.y - _capture_inset)
	var factor := Widgets.factor(_ui)
	var portrait := dimensions.y > dimensions.x
	_ui.size = dimensions
	_controls.fit(dimensions.x - 24 * factor, factor, portrait)
	_controls.position = Vector2(12 * factor, dimensions.y - _controls.size.y - 8 * factor)
	_match_hud.factor = factor
	_match_hud.size = Vector2(dimensions.x, _controls.position.y - 6 * factor)
	var hud_heights := _match_hud.layout_heights()
	var header := hud_heights.x
	_view.position = Vector2(0, header)
	_view.size = Vector2(dimensions.x, maxf(1.0, _match_hud.size.y - header - hud_heights.y))
	_pause_button.size = Vector2(104, 54) * factor
	_pause_button.position = Vector2(dimensions.x - _pause_button.size.x - 14 * factor, 8 * factor)
	_pause_button.add_theme_font_size_override("font_size", roundi(20 * factor))
	_match_hud.queue_redraw()
	if _railway_button != null:
		_railway_button.custom_minimum_size.y = 54 * factor
		_railway_button.size = Vector2(minf(360 * factor, dimensions.x - 140 * factor), 54 * factor)
		_railway_button.position = Vector2(14, 8) * factor
		_railway_button.add_theme_font_size_override("font_size", roundi(20 * factor))
	_fit_modal()

func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(0.0, bottom)
	_resize_layout()

func _fit_modal() -> void:
	if _modal_panel == null:
		return
	var dimensions := get_viewport_rect().size
	var factor := Widgets.factor(_ui)
	var width := minf(880 * factor, dimensions.x - 32 * factor)
	_modal_panel.position = Vector2((dimensions.x - width) * 0.5, 18 * factor)
	_modal_panel.size = Vector2(width, maxf(1.0, dimensions.y - 36 * factor))

func _close_lobby() -> void:
	if is_instance_valid(_lobby):
		_lobby.queue_free()
	_lobby = null

func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_modal_panel = null
	_ready_button = null
	_modal_action = Callable()

func _exit_tree() -> void:
	_stop_input()
	if _audio != null:
		_audio.stop()
