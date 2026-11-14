extends Control

## Shapes, words and numbers preserve the chant even without sound or colour.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const State = preload("res://games/tifo_beato/match/match_state.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Build = preload("res://games/tifo_beato/workshop/build_race.gd")
const Steward = preload("res://games/tifo_beato/steward/steward_state.gd")
const POWER_NAMES := {"megaphone": "Megaphone", "drum": "Drum",
	"tornado": "Scarf Tornado", "ref": "Distract the Ref chant"}
signal layout_changed
var model: RefCounted
var kind := "match"
var factor := 1.0
var static_lane := false
var player_label := "P1"
var player_color := Color("4da3ff")
var club := "BUCKETWICK ROVERS"
var group := "THE BUCKET BRIGADE"
var caption := "Beats make the brush dance. Rests mean silence."
var last_grade := ""
var lane := Rect2()
var _grade_time := -100.0
var _notes: Array[Dictionary] = []
var _phase: Dictionary = {}
var _clock := 0.0
var _beat := 0.6
var _metrics := PackedStringArray()
var _instruction := ""
var _layout_size := Vector2.ZERO
var show_details := false
var _values := PackedStringArray()
var _symbols := PackedStringArray()
var _scoreline := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	accessibility_name = "Tifo Beato rhythm lane"

func configure(value: RefCounted, mode: String) -> void:
	model = value
	kind = mode
	last_grade = ""
	_grade_time = -100.0
	present()

func grade(result: Dictionary, now: float) -> void:
	last_grade = str(result["name"])
	_grade_time = now
	queue_redraw()

func present() -> void:
	if model == null:
		return
	_notes = []
	_metrics = PackedStringArray()
	_values = PackedStringArray()
	_symbols = PackedStringArray()
	_scoreline = ""
	var compact := get_viewport_rect().size.y < 500
	var maximum := "" if compact else "/100"
	var inventory := ""
	if model is State:
		var state := model as State
		_clock = state.time
		_phase = state.phase()
		_notes = state.judge.notes
		_beat = float(_phase["beat"])
		_metrics.append_array(PackedStringArray([
			"NOISE %d" % state.noise(), "COMBO %d/%d" % [
				state.judge.combo, state.judge.best_combo],
			"SCARF %d%s" % [roundi(state.life.life), maximum],
			"MORALE %d%s" % [roundi(state.life.morale), maximum],
			"FURY %d%s" % [roundi(state.fury.charge), maximum], "ENERGY %d | %d:%d" % [
				roundi(state.crowd.energy), state.sim.home, state.sim.away],
		]))
		_values = PackedStringArray([
			str(state.noise()), str(state.judge.combo), str(roundi(state.life.life)),
			str(roundi(state.life.morale)), str(roundi(state.fury.charge)),
			str(roundi(state.crowd.energy)),
		])
		_symbols = PackedStringArray(["noise", "combo", "scarf", "morale", "fury", "energy"])
		_scoreline = "%d:%d" % [state.sim.home, state.sim.away]
		if bool(state.get("_settings").get("practice", false)):
			_metrics.resize(4)
			_values.resize(4)
			_symbols.resize(4)
		var lyric := str(_phase["lyric"]).replace("{CLUB}", club)
		_instruction = "%s - %s" % [str(_phase["kind"]).to_upper(), lyric]
		if state.life.dead:
			_instruction = "RALLY: four strong BEATS on the guide. The chant is waiting."
		elif str(_phase["kind"]) == "response":
			_instruction = "RESPONSE: breathe. Your actual call is coming back."
		elif str(_phase["kind"]) == "halftime":
			_instruction = "HALF-TIME: rest your voice. The second half waits."
		if not state.fury.power.is_empty():
			inventory = " Inventory: " + POWER_NAMES.get(state.fury.power, state.fury.power) \
				+ "; use the labelled power pad."
	elif model is War:
		var war := model as War
		_clock = war.time
		if war.phase >= 0:
			_phase = war.phases[war.phase]
			_beat = float(_phase["beat"])
		_instruction = war.caption()
		_metrics.append_array(PackedStringArray([
			"P1 NOISE %d" % roundi(war.scores[0]), "P2 / RIVAL NOISE %d" % roundi(war.scores[1]),
			"EXCHANGES %d : %d" % [war.exchange_wins[0], war.exchange_wins[1]],
			"ECHO the shapes. CALL your own rhythm.",
		]))
		_values = PackedStringArray([
			str(roundi(war.scores[0])), str(roundi(war.scores[1])),
			"%d:%d" % [war.exchange_wins[0], war.exchange_wins[1]],
		])
		_symbols = PackedStringArray(["p1", "p2", "combo"])
		if war.judge != null:
			_notes = war.judge.notes
		elif war.cpu != null and war.input_seat() < 0:
			_notes = war.cpu.notes
		if _phase.get("kind", "") == "call" and war.input_seat() >= 0:
			_instruction = "YOUR CALL: make a 2-bar rhythm. Quarter beats and syncopation count."
	elif model is Build:
		var build := model as Build
		_clock = build.time
		_beat = build.beat_seconds
		_phase = {"t": 0.0, "end": build.duration, "kind": "call"}
		_notes = build.judge.notes
		_instruction = "BUILD: BEAT brushes; SHOUT unrolls; Sing MID stitches."
		_metrics.append_array(PackedStringArray([
			"QUALITY %.0f%%" % (build.judge.accuracy() * 100.0),
			"MISHAPS %d" % build.banner.mishaps.size(),
			"BRUSHES %d/%d" % [build.judge.hits, build.judge.attempts],
			"TIME %ds" % ceili(maxf(0.0, build.duration - build.time)),
		]))
		_values = PackedStringArray([
			"%.0f%%" % (build.judge.accuracy() * 100.0), str(build.banner.mishaps.size()),
			"%d/%d" % [build.judge.hits, build.judge.attempts],
			str(ceili(maxf(0.0, build.duration - build.time))),
		])
		_symbols = PackedStringArray(["quality", "miss", "brush", "time"])
	elif model is Steward:
		var steward := model as Steward
		_clock = steward.time
		_phase = {"t": 0.0, "end": steward.duration, "kind": "call"}
		_beat = 0.6
		_instruction = steward.caption()
		_metrics.append_array(PackedStringArray([
			"STEPS %d/20" % steward.progress if steward.kind == "flag" else (
				"HUM %.1f/24s" % steward.hum_seconds),
			"SETBACKS %d" % steward.mistakes,
			"TIME %ds" % ceili(maxf(0.0, steward.duration - steward.time)),
			"BEAT to step; REST to freeze." if steward.kind == "flag" else "Hold Sing MID, comfortably.",
		]))
		_values = PackedStringArray([
			"%d/20" % steward.progress if steward.kind == "flag"
				else "%.1f/24" % steward.hum_seconds,
			str(steward.mistakes), str(ceili(maxf(0.0, steward.duration - steward.time))),
		])
		_symbols = PackedStringArray(["steps", "miss", "time"])
		if steward.kind == "flag":
			for pulse in range(maxi(0, floori(_clock / 0.6) - 1), floori(_clock / 0.6) + 7):
				_notes.append({"t": pulse * 0.6,
					"kind": "rest" if steward.watching(pulse * 0.6) else "beat",
					"duration": 0.6 if steward.watching(pulse * 0.6) else 0.0,
					"done": false})
		else:
			_notes.append({"t": 0.0, "duration": steward.duration,
				"kind": "hold", "hold_kind": "sing", "band": 0, "done": false})
	accessibility_description = "%s. %s. %s. %s. %s. %s" % [
		player_label, club, group, _instruction, caption, ". ".join(_metrics)]
	accessibility_description += inventory
	var measured := layout_heights()
	if not measured.is_equal_approx(_layout_size):
		_layout_size = measured
		layout_changed.emit.call_deferred()
	queue_redraw()

func layout_heights() -> Vector2:
	if not _details_fit():
		var width := maxf(1.0, size.x - 36 * factor)
		return Vector2(_compact_header_height(),
			_compact_grid_height() + (24 if get_window().size.y < 480 else 34) * factor
			+ _paragraph(_compact_instruction(), width, 15).get_size().y)
	return _detailed_heights()

func _details_fit() -> bool:
	if not show_details:
		return false
	var measured := _detailed_heights()
	return measured.x + measured.y <= size.y * 0.65

func _detailed_heights() -> Vector2:
	var compact := get_viewport_rect().size.y < 500
	var portrait := get_viewport_rect().size.y > get_viewport_rect().size.x
	var columns := 2 if portrait else 3
	var width := maxf(1.0, size.x - 36 * factor)
	var header := 12 * factor + _paragraph("%s | %s" % [player_label, club],
		maxf(1, width - 116 * factor), 18 if compact else 22).get_size().y
	if not compact:
		header += _paragraph(group, _header_width(width, header), 17).get_size().y + 4 * factor
	for first in range(0, _metrics.size(), columns):
		var row := 0.0
		var available := _header_width(width, header)
		for index in range(first, mini(first + columns, _metrics.size())):
			row = maxf(row, _paragraph(_metrics[index], available / columns - 8 * factor,
				16 if compact else 18).get_size().y)
		header += row + 5 * factor
	var lane_height := 18 * factor \
		+ _paragraph(_instruction, width, 17 if compact else 20).get_size().y \
		+ _paragraph(caption, width, 14 if compact else 16).get_size().y \
		+ (62 if compact else 84) * factor \
		+ _paragraph("BEAT []  SHOUT O  SING ^/<>/v  HOLD --  REST X", width, 14).get_size().y
	return Vector2(header + 6 * factor, lane_height)

func lane_bounds() -> Rect2:
	return Rect2(global_position + lane.position, lane.size)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var portrait := get_viewport_rect().size.y > get_viewport_rect().size.x
	var compact := get_viewport_rect().size.y < 500
	var measured := layout_heights()
	var expanded_copy := _details_fit()
	var header_height := measured.x
	draw_rect(Rect2(0, 0, size.x, header_height), Color("132237", 0.18))
	var width := size.x - 36 * factor
	var cursor_y := 12 * factor
	if expanded_copy:
		cursor_y += _text("%s | %s" % [player_label, club], Vector2(18 * factor, cursor_y),
			18 if compact else 22, player_color, width - 116 * factor)
		if not compact:
			cursor_y += _text(group, Vector2(18 * factor, cursor_y), 17, Options.CREAM,
				_header_width(width, cursor_y)) + 4 * factor
		var columns := 2 if portrait else 3
		for first in range(0, _metrics.size(), columns):
			var row := 0.0
			var available := _header_width(width, cursor_y)
			for index in range(first, mini(first + columns, _metrics.size())):
				var x := 18 * factor + (index % columns) * available / columns
				row = maxf(row, _text(_metrics[index], Vector2(x, cursor_y), 16 if compact else 18,
					Options.CREAM, available / columns - 8 * factor))
			cursor_y += row + 5 * factor
	else:
		_draw_counters()
	var height := measured.y
	lane = Rect2(12 * factor, size.y - height, size.x - 24 * factor, height - 8 * factor)
	draw_style_box(_lane_style(), lane)
	cursor_y = lane.position.y + 8 * factor
	cursor_y += _text(_instruction if expanded_copy else _compact_instruction(),
		Vector2(26 * factor, cursor_y), (17 if compact else 20) if expanded_copy else 15,
		Options.CREAM, width)
	if expanded_copy:
		cursor_y += _text(caption, Vector2(26 * factor, cursor_y), 14 if compact else 16,
			Color("a9bdcc"), width) + 4 * factor
	var grid_height := (50 if compact else 72) * factor \
		if expanded_copy else _compact_grid_height()
	var grid := Rect2(Vector2(26 * factor, cursor_y), Vector2(width, grid_height))
	var hit_x := grid.position.x + grid.size.x * 0.2
	for rung in 3:
		var y := grid.position.y + grid.size.y * (0.25 + rung * 0.25)
		draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), Color("39516b"), factor)
	var first_pulse := floori((_clock - _beat) / _beat)
	for pulse in range(first_pulse, first_pulse + 8):
		var x := hit_x + (pulse * _beat - _clock) / (_beat * 4.0) * grid.size.x * 0.8
		if x >= grid.position.x and x < grid.end.x:
			draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y),
				Color("51667b"), factor)
	draw_line(Vector2(hit_x, grid.position.y - 4 * factor),
		Vector2(hit_x, grid.end.y + 4 * factor), Options.BUCKET, 3 * factor)
	for note in _notes:
		if bool(note.get("superseded", false)):
			continue
		var start := float(note["t"])
		var duration := float(note.get("duration", 0.0))
		var x := hit_x + (start - _clock) / (_beat * 4.0) * grid.size.x * 0.8
		if static_lane:
			if start < float(_phase.get("t", 0.0)) or start >= float(_phase.get("end", 0.0)):
				continue
			x = grid.position.x + (start - float(_phase.get("t", 0.0))) \
				/ maxf(_beat, float(_phase.get("end", 1.0)) - float(_phase.get("t", 0.0))) \
				* grid.size.x
		if x < grid.position.x - duration / (_beat * 4.0) * grid.size.x \
			or x > grid.end.x:
			continue
		var kind_name := str(note["kind"])
		var y := grid.position.y + grid.size.y * (
			0.5 - int(note.get("band", 0)) * 0.25 if kind_name in ["sing", "hold"] else 0.5)
		var ink := Color("8292a2") if bool(note.get("done", false)) else Options.CREAM
		if kind_name in ["hold", "rest"]:
			var tail := minf(grid.end.x, x + duration / (_beat * 4.0) * grid.size.x * 0.8)
			draw_line(Vector2(maxf(grid.position.x, x), y),
				Vector2(tail, y), ink, 8 * factor)
		if x >= grid.position.x:
			var shape := kind_name
			if kind_name == "hold":
				shape = "sing" if str(note.get("hold_kind", "shout")) == "sing" else "shout"
			_icon(Vector2(x, y), shape, int(note.get("band", 0)), ink)
	if model is State:
		var state := model as State
		if state.disruptions.active == "rival_drums":
			for pulse in range(first_pulse, first_pulse + 9):
				var x := hit_x + (pulse * _beat / 1.06 - _clock) / (_beat * 4.0) * grid.size.x * 0.8
				if x >= grid.position.x and x <= grid.end.x:
					draw_circle(Vector2(x, grid.position.y + 6 * factor), 5 * factor, Color("ff5c6c"))
		if state.disruptions.active == "inflatable" or state.chaos.active == "beach_balls":
			var remaining := 3 if state.disruptions.active == "inflatable" else maxi(0, 8 - state.chaos.progress)
			for index in mini(3, remaining):
				var at := grid.position + Vector2(grid.size.x * (0.45 + index * 0.2), grid.size.y * 0.5)
				draw_circle(at, 19 * factor, Color(0.41, 0.70, 0.82, 0.65))
	if expanded_copy:
		_text("BEAT []  SHOUT O  SING ^/<>/v  HOLD --  REST X",
			Vector2(26 * factor, grid.end.y + 6 * factor), 14, Options.CREAM, width)
	if not last_grade.is_empty() and _clock - _grade_time < 1.2:
		_text(last_grade.to_upper(), Vector2(size.x * 0.42, header_height + 4 * factor),
			30, Options.BUCKET)

func _icon(at: Vector2, kind_name: String, band: int, ink: Color) -> void:
	var radius := 11.0 * factor
	match kind_name:
		"beat":
			draw_rect(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), ink)
		"shout":
			draw_circle(at, radius, ink)
		"sing", "hold":
			var shape := PackedVector2Array()
			if band == 0:
				shape = PackedVector2Array([at + Vector2(-radius, 0), at + Vector2(0, -radius),
					at + Vector2(radius, 0), at + Vector2(0, radius)])
			else:
				shape = PackedVector2Array([at + Vector2(-radius, band * radius),
					at + Vector2(radius, band * radius), at + Vector2(0, -band * radius)])
			draw_colored_polygon(shape, ink)
		"rest":
			draw_line(at - Vector2.ONE * radius, at + Vector2.ONE * radius, ink, 3 * factor)
			draw_line(at + Vector2(-radius, radius), at + Vector2(radius, -radius), ink, 3 * factor)

func _header_width(width: float, y: float) -> float:
	return maxf(1.0, width - (116 * factor if y < 62 * factor else 0.0))

func _paragraph(text: String, width: float, font_size: int) -> TextParagraph:
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(1.0, width)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
		| TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, ThemeDB.fallback_font, roundi(font_size * factor))
	return paragraph

func _text(text: String, at: Vector2, font_size: int, ink := Options.CREAM,
	width := -1.0) -> float:
	var paragraph := _paragraph(text, width if width > 0 else size.x - at.x - 12 * factor, font_size)
	paragraph.draw(get_canvas_item(), at, ink)
	return paragraph.get_size().y

func _lane_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172439", 0.24)
	style.border_color = Color("a88b40", 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(roundi(12 * factor))
	return style


func _compact_instruction() -> String:
	if model is State:
		if model.life.dead:
			return "RALLY"
		if _phase.get("kind", "") in ["response", "halftime"]:
			return "REST"
		return str(_phase.get("lyric", "")).replace("{CLUB}", club)
	if model is Build:
		return "BEAT / SHOUT / MID"
	if model is War:
		if model.input_seat() < 0:
			return "LISTEN"
		return "CALL" if _phase.get("kind", "") == "call" else "ECHO"
	if model is Steward:
		return "BEAT / REST" if model.kind == "flag" else "HOLD MID"
	return _instruction


func _compact_grid_height() -> float:
	return (32 if get_window().size.y < 480 else 50) * factor


func _counter_columns() -> int:
	return maxi(1, mini(_values.size(), floori(_counter_width() / (60 * factor))))


func _counter_width() -> float:
	return maxf(1, size.x - (24 if _counters_below_actions() else 174) * factor)


func _counters_below_actions() -> bool:
	return size.x < 480 * factor


func _counter_row_height(first: int, columns: int, width: float) -> float:
	var height := 28 * factor
	for index in range(first, mini(first + columns, _values.size())):
		height = maxf(height, _paragraph(_values[index], width - 28 * factor, 16).get_size().y
			+ 8 * factor)
	return height


func _compact_header_height() -> float:
	var columns := _counter_columns()
	var width := _counter_width() / columns
	var height := (60 if _counters_below_actions() else 16) * factor
	for first in range(0, _values.size(), columns):
		height += _counter_row_height(first, columns, width)
	return maxf(height, 60 * factor)


func _draw_counters() -> void:
	var identity := player_label.get_slice(" ", 0)
	var microphone := player_label.ends_with("MIC")
	if microphone:
		identity += " MIC"
	_text(identity, Vector2(12, 12) * factor, 11 if microphone else 13,
		player_color, 40 * factor)
	_text(_scoreline, Vector2(12, 32) * factor, 13, Options.CREAM, 40 * factor)
	var columns := _counter_columns()
	var width := _counter_width() / columns
	var y := (54 if _counters_below_actions() else 10) * factor
	var left := (12 if _counters_below_actions() else 58) * factor
	for first in range(0, _values.size(), columns):
		for index in range(first, mini(first + columns, _values.size())):
			var at := Vector2(left + (index % columns) * width, y)
			_counter_icon(at + Vector2(8, 12) * factor, _symbols[index])
			_text(_values[index], at + Vector2(24, 0) * factor, 16,
				Options.CREAM, width - 28 * factor)
		y += _counter_row_height(first, columns, width)


func _counter_icon(at: Vector2, symbol: String) -> void:
	var ink := Color("dce5eb")
	var r := 7 * factor
	var stroke := 1.6 * factor
	match symbol:
		"noise":
			for bar in 3:
				var half := (4 + bar * 2) * factor
				var x := at.x + (bar - 1) * 5 * factor
				draw_line(Vector2(x, at.y - half), Vector2(x, at.y + half), ink, stroke)
		"combo":
			draw_arc(at - Vector2(r * 0.5, 0), r * 0.7, 0, TAU, 16, ink, stroke)
			draw_arc(at + Vector2(r * 0.5, 0), r * 0.7, 0, TAU, 16, ink, stroke)
		"scarf":
			draw_rect(Rect2(at - Vector2(r, r), Vector2(r * 2, r * 0.7)), ink, false, stroke)
			draw_line(at + Vector2(-r, -r * 0.3), at + Vector2(-r, r), ink, stroke)
			draw_line(at + Vector2(r, -r * 0.3), at + Vector2(r, r), ink, stroke)
		"morale":
			draw_arc(at, r, 0, TAU, 20, ink, stroke)
			draw_circle(at + Vector2(-r * 0.35, -r * 0.2), factor, ink)
			draw_circle(at + Vector2(r * 0.35, -r * 0.2), factor, ink)
			draw_arc(at, r * 0.55, 0.2, PI - 0.2, 10, ink, stroke)
		"fury":
			draw_polyline(PackedVector2Array([
				at + Vector2(r * 0.6, -r), at + Vector2(-r * 0.5, 0),
				at + Vector2(r * 0.5, 0), at + Vector2(-r * 0.6, r),
			]), ink, stroke)
		"energy":
			draw_rect(Rect2(at - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)),
				ink, false, stroke)
			draw_line(at + Vector2(r * 1.3, -r * 0.3),
				at + Vector2(r * 1.3, r * 0.3), ink, stroke)
		"time":
			draw_arc(at, r, 0, TAU, 20, ink, stroke)
			draw_polyline(PackedVector2Array([
				at + Vector2(0, -r * 0.6), at, at + Vector2(r * 0.5, 0),
			]), ink, stroke)
		"p1", "p2":
			_text(symbol.to_upper(), at - Vector2(8, 10) * factor, 11, ink, 24 * factor)
		"miss":
			_icon(at, "rest", 0, ink)
		"brush":
			draw_line(at + Vector2(-r, r), at, ink, stroke)
			draw_rect(Rect2(at - Vector2(0, r), Vector2(r, r)), ink)
		"quality":
			draw_arc(at, r, 0, TAU, 20, ink, stroke)
			draw_polyline(PackedVector2Array([
				at + Vector2(-r * 0.5, 0), at + Vector2(0, r * 0.4),
				at + Vector2(r * 0.5, -r * 0.4),
			]), ink, stroke)
		"steps":
			draw_line(at + Vector2(-r * 0.4, -r), at + Vector2(-r * 0.4, 0), ink, stroke * 2)
			draw_line(at + Vector2(r * 0.4, 0), at + Vector2(r * 0.4, r), ink, stroke * 2)
