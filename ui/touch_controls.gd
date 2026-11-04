extends Control

## Labelled pads remain available to mouse, keyboard learners and independent fingers.

signal action_changed(action: StringName, pressed: bool, contact: String)
signal screen_touch_changed(pointer: int, pressed: bool)
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Touch = preload("res://games/tifo_beato/sound/touch_source.gd")
const Hud = preload("res://games/tifo_beato/ui/match_hud.gd")
const ACTIONS: Array[StringName] = [
	Options.BEAT_LEFT, Options.BEAT_RIGHT, Options.SHOUT, Options.SING_LOW,
	Options.SING_MID, Options.SING_HIGH, Options.FURY, Options.POWER,
]
const WORDS := ["BEAT L", "BEAT R", "SHOUT", "LOW", "MID", "HIGH", "FURY", "POWER"]
var touch := Touch.new()
var pads: Array[Rect2] = []
var key_labels: Array[String] = ["F", "J", "Space", "A", "S", "D", "Q", "E"]
var layout := 0
var factor := 1.0
var enabled := true
var powers_enabled := true
var _power := ""
var _order: Array[int] = []
var _pad_height := 72.0
var _compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.action_changed.connect(_on_action)
	accessibility_name = "Independent rhythm pads"
	accessibility_description = "Beat left and right, Shout, Sing LOW, MID and HIGH, Fury and power. Hold for sustain; release every pad for Rest."
	resized.connect(_layout)
	_layout()

func fit(width: float, scale_factor: float, portrait: bool) -> void:
	factor = scale_factor
	_compact = not portrait and get_viewport_rect().size.y < 500
	_pad_height = 48.0 if _compact else 72.0
	size = Vector2(width, (160 if portrait else (56 if _compact else 80)) * factor)
	_layout()

func release_all() -> void:
	touch.clear()
	queue_redraw()

func set_power(value: String) -> void:
	if value == _power:
		return
	_power = value
	_describe()
	queue_redraw()

func set_powers_enabled(value: bool) -> void:
	if value == powers_enabled:
		return
	touch.clear()
	powers_enabled = value
	_describe()
	_layout()

func _describe() -> void:
	accessibility_description = "Beat left and right, Shout, Sing LOW, MID and HIGH. " \
		+ "Hold for sustain; release every pad for Rest."
	if not powers_enabled:
		accessibility_description += " Practice has no Fury or power-ups."
	else:
		accessibility_description += " Fury and power pads are available. Inventory: " + (
			"empty" if _power.is_empty() else str(Hud.POWER_NAMES.get(_power, _power))
				+ "; use the labelled power pad.")

func _layout() -> void:
	pads.clear()
	_order = [0, 1, 2, 3, 4, 5, 6, 7]
	if layout == 1:
		_order = [3, 4, 5, 2, 0, 1, 7, 6]
	elif layout == 2:
		_order = [0, 1, 2, 6, 3, 4, 5, 7]
	if not powers_enabled:
		_order = _order.filter(func(index: int) -> bool: return index < 6)
	var columns := (4 if powers_enabled else 3) if size.y > 100 * factor else _order.size()
	var gap := 8.0 * factor
	var width := maxf(1.0, (size.x - gap * (columns - 1)) / columns)
	for index in _order.size():
		pads.append(Rect2(Vector2((index % columns) * (width + gap),
			(index / columns) * 80 * factor), Vector2(width, _pad_height * factor)))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not enabled:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		screen_touch_changed.emit(event.index, event.pressed)
		if event.pressed:
			_pointer(event.index, event.position)
		elif touch.contacts.has(event.index):
			touch.release(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch.contacts.has(event.index):
		_pointer(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer(-1, event.position)
		elif touch.contacts.has(-1):
			touch.release(-1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and touch.contacts.has(-1):
		_pointer(-1, event.position)

func _pointer(pointer: int, global_position: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * global_position
	for index in pads.size():
		if pads[index].has_point(local):
			touch.press(pointer, ACTIONS[_order[index]])
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
	if touch.contacts.has(pointer):
		touch.release(pointer)
		get_viewport().set_input_as_handled()

func _on_action(action: StringName, pressed: bool, contact: String) -> void:
	action_changed.emit(action, pressed, contact)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for index in pads.size():
		var action := _order[index]
		var rect := pads[index]
		var active := ACTIONS[action] in touch.contacts.values()
		draw_style_box(_style(active), rect)
		var word: String = WORDS[action]
		if action == 7:
			word = {"megaphone": "MEGA", "drum": "DRUM",
				"tornado": "SCARF", "ref": "REF"}.get(_power, "POWER")
		var font_size := roundi((14 if _compact else 18) * factor)
		var ink := Options.NAVY if active else Options.CREAM
		var word_width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x
		draw_string(font, Vector2(rect.get_center().x - word_width * 0.5,
			rect.position.y + (19 if _compact else 30) * factor), word, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size, ink)
		var key: String = key_labels[action]
		var key_width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x
		draw_string(font, Vector2(rect.get_center().x - key_width * 0.5,
			rect.position.y + (39 if _compact else 54) * factor), key, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size, ink)

func _style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Options.BUCKET if active else Color("26384d")
	style.border_color = Options.CREAM if active else Color("8c8f94")
	style.set_border_width_all(roundi(2 * factor))
	style.set_corner_radius_all(roundi(12 * factor))
	return style
