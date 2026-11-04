extends VBoxContainer

## The workbench edits musical values; only an explicit Record action opens input.

signal play_requested(request: Dictionary)
signal save_requested(slot: int, data: Dictionary)
const Creator = preload("res://games/tifo_beato/chart/chant_creator.gd")
const Words = preload("res://games/tifo_beato/career/word_list.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
var creator := Creator.new()
var saved: Dictionary = {}
var player_count := 1
var slot := 0
var selected_note := 0
var _status: Label
var _code: TextEdit
var _note_list: OptionButton
var _note_editor: VBoxContainer
var _kind := 0
var _grid := 0
var _duration := 0
var _band := 0
var _voiced := 0

func _ready() -> void:
	Widgets.label(self, "CHANT CREATOR", true)
	_status = Widgets.label(self,
		"Record or edit a 1-8 bar chant. No PCM is saved. Custom play is unranked and pays no Tokens.")
	Widgets.number(self, "Tempo (BPM)", 60, 180, 1, creator.tempo,
		func(value: float) -> void: creator.tempo = roundi(value))
	Widgets.number(self, "Bars (4 beats each)", 1, 8, 1, creator.bars,
		func(value: float) -> void: creator.bars = roundi(value))
	Widgets.choice(self, "Curated lyric slot", Words.BANNERS, creator.lyric,
		func(index: int) -> void: creator.lyric = index)
	Widgets.choice(self, "Crowd response", Creator.RESPONSES, creator.response,
		func(index: int) -> void: creator.response = index)
	Widgets.button(self, "Record a new chant - replaces this unsaved draft",
		func() -> void: play_requested.emit({"mode": "creator_record"}))
	_note_list = Widgets.choice(self, "Note to edit", [], 0, _select_note)
	_note_editor = VBoxContainer.new()
	add_child(_note_editor)
	_rebuild_notes()
	Widgets.button(self, "Add a Beat at the next free sixteenth", _add_note)
	Widgets.button(self, "Clear the unsaved draft", func() -> void:
		creator.notes.clear()
		_rebuild_notes())
	Widgets.button(self, "Practise this chant", func() -> void: _play("creator_practice"))
	var challenge := Widgets.button(self, "Challenge a friend - same chart, successive turns",
		func() -> void: _play("creator_challenge"))
	challenge.disabled = player_count != 2
	challenge.tooltip_text = "Choose two-human hot seat in setup first." if challenge.disabled else (
		"Both humans play the same chart with independent timing profiles.")
	var slots: Array[String] = []
	for index in Creator.SLOTS:
		slots.append("Slot %d%s" % [index + 1, " - saved" if saved.has(str(index)) else " - empty"])
	Widgets.choice(self, "Local chant slot", slots, slot,
		func(index: int) -> void: slot = index)
	Widgets.button(self, "Save this draft to the selected slot", _save)
	Widgets.button(self, "Load the selected saved chant", _load_slot)
	Widgets.label(self, "Offline chant code - musical data and curated lyric ids only")
	_code = TextEdit.new()
	_code.name = "OfflineChantCode"
	_code.custom_minimum_size.y = 150
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.accessibility_name = "Offline chant code"
	_code.add_theme_font_size_override("font_size", 23)
	add_child(_code)
	Widgets.button(self, "Show code / copy to clipboard", _export)
	Widgets.button(self, "Paste clipboard code into this box", func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			_code.text = DisplayServer.clipboard_get()
			show_status("Code pasted. Import validates it before changing your draft.")
		else:
			show_status("Clipboard is unavailable. Paste a code into the box manually."))
	Widgets.button(self, "Import code from the box", _import)

func show_status(text: String) -> void:
	_status.text = text

func _select_note(index: int) -> void:
	selected_note = index
	_rebuild_notes()

func _rebuild_notes() -> void:
	_note_list.clear()
	for index in creator.notes.size():
		var note := creator.notes[index]
		_note_list.add_item("%d: %s at beat %.2f" % [
			index + 1, Creator.KINDS[int(note[0])].to_upper(), int(note[1]) / 4.0])
	for child in _note_editor.get_children():
		_note_editor.remove_child(child)
		child.queue_free()
	if creator.notes.is_empty():
		Widgets.label(_note_editor, "No notes yet. Record with your instrument or add a Beat.")
		return
	selected_note = clampi(selected_note, 0, creator.notes.size() - 1)
	_note_list.select(selected_note)
	var note := creator.notes[selected_note]
	_kind = int(note[0])
	_grid = int(note[1])
	_duration = int(note[2])
	_band = int(note[3])
	_voiced = int(note[4])
	Widgets.choice(_note_editor, "Shape", ["Beat", "Shout", "Sing", "Hold", "Rest"], _kind,
		func(index: int) -> void: _kind = index)
	Widgets.number(_note_editor, "Beat position (sixteenths)", 0, 31.75, 0.25, _grid / 4.0,
		func(value: float) -> void: _grid = roundi(value * 4.0))
	Widgets.number(_note_editor, "Length in beats (Beat = zero)", 0, 32, 0.25, _duration / 4.0,
		func(value: float) -> void: _duration = roundi(value * 4.0))
	Widgets.choice(_note_editor, "Relative pitch", ["LOW", "MID", "HIGH"], _band + 1,
		func(index: int) -> void: _band = index - 1)
	Widgets.choice(_note_editor, "Hold instrument", ["Shout", "Sing"], _voiced,
		func(index: int) -> void: _voiced = index)
	Widgets.button(_note_editor, "Apply this note edit", func() -> void:
		var error := creator.put_note([_kind, _grid, _duration, _band, _voiced], selected_note)
		show_status("Note updated." if error.is_empty() else error)
		if error.is_empty():
			_rebuild_notes())
	Widgets.button(_note_editor, "Remove this note", func() -> void:
		creator.notes.remove_at(selected_note)
		_rebuild_notes())
	if is_inside_tree():
		Widgets.scale_tree(_note_editor, Widgets.factor(self))

func _add_note() -> void:
	for grid in creator.bars * 16:
		var error := creator.put_note([0, grid, 0, 0, 0])
		if error.is_empty():
			selected_note = creator.notes.size() - 1
			_rebuild_notes()
			show_status("Beat added. Select it to change its shape or timing.")
			return
	show_status("No non-conflicting slot remains, or the draft needs an invalid note removed first.")

func _save() -> void:
	var error := Creator.validate(creator.payload())
	if error.is_empty():
		save_requested.emit(slot, creator.payload())
	else:
		show_status(error)

func _load_slot() -> void:
	if not saved.has(str(slot)):
		show_status("That local slot is empty.")
		return
	var error := creator.restore(saved[str(slot)])
	if error.is_empty():
		play_requested.emit({"mode": "creator_reload"})
	else:
		show_status(error)

func _play(mode: String) -> void:
	var error := Creator.validate(creator.payload())
	if not error.is_empty():
		show_status(error)
		return
	play_requested.emit({"mode": mode, "chant": creator.payload()})

func _export() -> void:
	var error := Creator.validate(creator.payload())
	if not error.is_empty():
		show_status(error)
		return
	_code.text = creator.code()
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(_code.text)
		show_status("Chant code copied. No recording, player name or file path is included.")
	else:
		show_status("Code is ready for manual copying; clipboard access is unavailable.")

func _import() -> void:
	var decoded := Creator.decode(_code.text)
	if not str(decoded["error"]).is_empty():
		show_status(str(decoded["error"]))
		return
	var error := creator.restore(decoded["data"])
	if not error.is_empty():
		show_status(error)
		return
	play_requested.emit({"mode": "creator_reload"})
