extends Control

const Chants = preload("res://games/tifo_beato/chart/chants.gd")
const State = preload("res://games/tifo_beato/match/match_state.gd")
const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
const Hud = preload("res://games/tifo_beato/ui/match_hud.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
var _chants := Chants.all()
var _model: State
var _hud: Hud
var _slider: HSlider
var _toolbar: VBoxContainer

func _ready() -> void:
	_toolbar = VBoxContainer.new()
	add_child(_toolbar)
	Widgets.label(_toolbar, "ORIGINAL CHANT GRID - NO INPUT SCORED", true)
	var titles: Array[String] = []
	for chant in _chants:
		titles.append("%s | %.0f BPM" % [chant.title, chant.tempo])
	Widgets.choice(_toolbar, "Chant", titles, 0, _select)
	Widgets.toggle(_toolbar, "Static phrase grid", true, func(enabled: bool) -> void:
		_hud.static_lane = enabled
		_hud.present())
	_slider = HSlider.new()
	_slider.step = 0.01
	_slider.accessibility_name = "Inspect chart time"
	_slider.value_changed.connect(func(value: float) -> void:
		_model.time = value
		_hud.present())
	_toolbar.add_child(_slider)
	_hud = Hud.new()
	_hud.static_lane = true
	_hud.caption = "Scrub through CALL, HOLD, REST and RESPONSE. Original melodies still need owner review."
	add_child(_hud)
	resized.connect(_layout)
	_select(0)
	_layout()

func _select(index: int) -> void:
	var chant := _chants[index]
	var beat := 60.0 / chant.tempo
	_model = State.new(1, 0, chant.pool, {"rivals": 2, "half_seconds": 8.0, "walkin_seconds": 0.0})
	var chart := _model.chart
	chart.phases.clear()
	chart.notes.clear()
	chart.duration = 0.0
	for phrase in chant.phrases:
		var phase_index := chart.phases.size()
		chart.phases.append({"t": chart.duration, "end": chart.duration + phrase.call_beats * beat,
			"kind": "sustain" if phrase.sustain else "call", "lyric": phrase.lyric,
			"loop": 0, "half": 1, "beat": beat})
		for authored: Dictionary in phrase.notes:
			var note := authored.duplicate(true)
			note["t"] = chart.duration + float(note["beat"]) * beat
			note["duration"] = float(note["duration"]) * beat
			note["phase"] = phase_index
			note["id"] = chart.notes.size()
			chart.notes.append(note)
		chart.duration += phrase.call_beats * beat
		if not phrase.sustain:
			chart.phases.append({"t": chart.duration, "end": chart.duration + phrase.response_beats * beat,
				"kind": "response", "lyric": phrase.lyric, "loop": 0, "half": 1, "beat": beat})
			chart.duration += phrase.response_beats * beat
	_model.judge = Judge.new(chart.notes)
	_slider.max_value = chart.duration - 0.001
	_slider.value = 0.0
	_hud.configure(_model, "match")

func _layout() -> void:
	_toolbar.position = Vector2(24, 12)
	_toolbar.size = Vector2(maxf(1.0, size.x - 48), 150)
	_hud.position = Vector2(0, 180)
	_hud.size = Vector2(size.x, maxf(1.0, size.y - 180))
