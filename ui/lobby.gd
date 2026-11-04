extends MenuScreen

## One scrollable play-flow screen owns the railway, identity and banner workbench.

signal play_requested(request: Dictionary)
signal soundcheck_requested(seat: int)
signal instrument_selected(seat: int, instrument: int)
signal identity_changed
signal fabric_selected(index: int)
signal exit_requested
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Words = preload("res://games/tifo_beato/career/word_list.gd")
const Identity = preload("res://games/tifo_beato/career/identity.gd")
const Banner = preload("res://games/tifo_beato/workshop/banner.gd")
const Career = preload("res://games/tifo_beato/career/career_state.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Map = preload("res://games/tifo_beato/ui/career_map.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
var identity := Identity.new()
var banner := Banner.new()
var career := Career.new()
var records := Records.new()
var player_count := 1
var ground := 0
var tab := 0
var instruments: Array[int] = [1, 1]
var hot_seat_mode := 0
var group_names := PackedStringArray(["The Bucket Brigade"])
var fabric_owned: Array[bool] = [true, false, false, false]
var status := ""
var _panel: PanelContainer
var _layout: VBoxContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _banner_preview: TextureRect
var _budget_label: Label
var _contrast: Label
var _title: Label
var _subtitle: Label
var _tabs: OptionButton

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.07, 0.13, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	add_child(_panel)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 10)
	_panel.add_child(_layout)
	_title = Widgets.label(_layout, "TIFO BEATO", true)
	_subtitle = Widgets.label(_layout, "Ninety minutes. No silence. | " + identity.club_name())
	_tabs = OptionButton.new()
	_tabs.fit_to_longest_item = false
	_tabs.accessibility_name = "Next screen"
	for title in ["Career railway", "Quick play", "Tifo workshop", "My club"]:
		_tabs.add_item(title)
	_tabs.select(tab)
	_tabs.item_selected.connect(_select_tab)
	_layout.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_layout.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	var back := Widgets.button(_layout, "Back to title", exit_requested.emit)
	first_focus = back
	_rebuild()
	super()

func go_back() -> void:
	exit_requested.emit()

func _select_tab(index: int) -> void:
	tab = index
	_scroll.scroll_vertical = 0
	_rebuild()

func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_banner_preview = null
	_budget_label = null
	_contrast = null
	if not status.is_empty():
		Widgets.label(_content, status)
	Widgets.label(_content, "Comfortable voice only. Buttons earn every bonus. Pause whenever you need.")
	Widgets.label(_content, "Section: " + " / ".join(group_names))
	for seat in player_count:
		var row := Widgets.panel(_content)
		Widgets.choice(row, "P%d instrument" % (seat + 1), ["Microphone", "Buttons"],
			instruments[seat], func(value: int) -> void:
				instruments[seat] = value
				instrument_selected.emit(seat, value))
		Widgets.button(row, "P%d soundcheck / timing" % (seat + 1),
			func() -> void: soundcheck_requested.emit(seat))
	if tab == 0 and player_count == 1:
		var map := Map.new()
		map.career = career
		map.stop_selected.connect(_career_stop)
		_content.add_child(map)
	elif tab <= 1:
		_quick_play()
	elif tab == 2:
		_workshop()
	else:
		_identity_editor()
	if is_node_ready():
		refresh_layout()

func _career_stop(ground_index: int, stop: int) -> void:
	play_requested.emit({"mode": "career", "ground": ground_index, "stop": stop})

func _quick_play() -> void:
	var titles: Array[String] = []
	var unlocked: Array[int] = []
	for index in 5:
		if career.ground_unlocked(index):
			titles.append(str(Options.GROUNDS[index]["title"]))
			unlocked.append(index)
	var selected := maxi(0, unlocked.find(ground))
	Widgets.choice(_content, "Unlocked ground", titles, selected,
		func(index: int) -> void: ground = unlocked[index])
	if player_count > 1:
		Widgets.label(_content, "Pass one instrument. Each seat keeps its own timing profile.")
		Widgets.label(_content, "Two Capos and Split use P1's chant pool and identical rules.")
		for mode in ["duel", "two_capos", "split"]:
			var title := "Duel - best of 5" if mode == "duel" else (
				"Two Capos - share one chant" if mode == "two_capos" else "Split the Stands - same seeded match")
			var button := Widgets.button(_content, title,
				func() -> void: play_requested.emit({"mode": mode, "ground": ground}))
			if mode == ["duel", "two_capos", "split"][hot_seat_mode]:
				first_focus = button
	else:
		Widgets.button(_content, "Quick match - stars do not change the career",
			func() -> void: play_requested.emit({"mode": "quick", "ground": ground}))
		Widgets.label(_content, "Chant wars: Big Sandro is your first rehearsal partner.")
		for rival in War.RIVALS.size():
			var entry: Dictionary = War.RIVALS[rival]
			var button := Widgets.button(_content, str(entry["title"]) + " - " + str(entry["style"]),
				func() -> void: play_requested.emit({"mode": "war", "ground": ground, "rival": rival}))
			button.disabled = rival > 0 and str(entry["id"]) not in records.data["rivals"]
			if button.disabled:
				button.text = str(entry["title"]) + " - meet them in the career"
		Widgets.button(_content, "Practise Sneak the Flag",
			func() -> void: play_requested.emit({"mode": "flag", "ground": ground}))
		Widgets.button(_content, "Practise Drum in the Coat",
			func() -> void: play_requested.emit({"mode": "coat", "ground": ground}))

func _workshop() -> void:
	Widgets.label(_content, "A garage. A bedsheet. A wildly optimistic budget.", true)
	_banner_preview = TextureRect.new()
	_banner_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner_preview.custom_minimum_size.y = 180
	_banner_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_content.add_child(_banner_preview)
	_budget_label = Widgets.label(_content, "")
	var fabrics: Array[String] = ["Bedsheet", "Tarpaulin", "Silk", "Glitter fabric"]
	for index in 4:
		if not fabric_owned[index]:
			fabrics[index] += " (store)"
	var fabric_choice := Widgets.choice(_content, "Fabric", fabrics, banner.fabric,
		func(index: int) -> void:
			if fabric_owned[index]:
				banner.fabric = index
				fabric_selected.emit(index)
			_update_banner())
	for index in 4:
		fabric_choice.set_item_disabled(index, not fabric_owned[index])
	Widgets.choice(_content, "Background", Words.PATTERNS, banner.pattern,
		func(index: int) -> void:
			banner.pattern = index
			_update_banner())
	Widgets.choice(_content, "Cartoon crest", Words.CRESTS, banner.crest,
		func(index: int) -> void:
			banner.crest = index
			_update_banner())
	Widgets.choice(_content, "Curated words - no free text", Words.BANNERS, banner.text,
		func(index: int) -> void:
			banner.text = index
			_update_banner())
	for extra in ["fringe", "glitter", "lights", "poles"]:
		Widgets.toggle(_content, extra.capitalize(), bool(banner.get(extra)),
			func(value: bool) -> void:
				banner.set(extra, value)
				_update_banner())
	Widgets.button(_content, "Build it - rhythm race",
		func() -> void: play_requested.emit({"mode": "workshop", "ground": ground}))
	Widgets.label(_content, "The finished quality, mishaps and image appear in your next match.")
	_update_banner()

func _update_banner() -> void:
	banner.primary = Identity.COLORS[identity.primary]
	banner.secondary = Identity.COLORS[identity.secondary]
	if _banner_preview != null:
		_banner_preview.texture = ImageTexture.create_from_image(banner.render_image())
	if _budget_label != null:
		var cost := banner.cost()
		var budget := int(Options.GROUNDS[ground]["budget"])
		_budget_label.text = "MATERIALS: %d / %d | cloth %d, paint %d, extras %d\n%s" % [
			cost["total"], budget, cost["fabric"], cost["paint"], cost["extras"],
			"Over budget: more comic mishaps, never an extra price." if banner.overspend(budget) > 0 else (
				"Within budget. Misses may still invite the club cat.")]

func _identity_editor() -> void:
	Widgets.label(_content, "Your curva. Your colours. Original, curated names.", true)
	var rows := [
		["town", "Town", Words.TOWNS], ["club", "Club", Words.CLUBS],
		["group", "Curva name", Words.GROUPS], ["crest", "Crest", Words.CRESTS],
		["pattern", "Scarf pattern", Words.PATTERNS],
	]
	for row: Array in rows:
		var key := str(row[0])
		Widgets.choice(_content, str(row[1]), row[2], int(identity.get(key)),
			func(index: int) -> void:
				identity.set(key, index)
				_update_identity())
	var swatches: Array[String] = []
	for index in Identity.COLORS.size():
		swatches.append("%02d - #%s" % [index + 1, Identity.COLORS[index].to_html(false)])
	for color_name in ["primary", "secondary"]:
		Widgets.choice(_content, color_name.capitalize() + " colour", swatches,
			int(identity.get(color_name)), func(index: int) -> void:
				identity.set(color_name, index)
				_update_identity())
	_contrast = Widgets.label(_content, "")
	_update_identity()

func _update_identity() -> void:
	if _contrast != null:
		_contrast.text = "%s | %s\n%s" % [identity.club_name(), identity.group_name(),
			"Low luminance contrast: choose a lighter/darker pair for readable tifos."
			if identity.low_contrast() else "Good luminance separation. P1 stays blue and P2 red."]
	_update_banner()
	identity_changed.emit()

func _on_layout_changed(dimensions: Vector2) -> void:
	if _panel == null:
		return
	var factor := Widgets.factor(self)
	var inset := 18.0 * factor
	var width := minf(dimensions.x - inset * 2, 1060 * factor)
	_panel.position = Vector2((dimensions.x - width) * 0.5, inset)
	_panel.size = Vector2(width, maxf(1, dimensions.y - inset * 2))
	Widgets.scale_tree(_layout, factor)
	var compact := dimensions.y < 650 * factor
	_subtitle.visible = not compact
	if compact:
		_title.add_theme_font_size_override("font_size", roundi(22 * factor))
		for button in _layout.find_children("*", "BaseButton", true, false):
			button.custom_minimum_size.y = Widgets.touch_minimum(self)
			button.add_theme_font_size_override("font_size", roundi(18 * factor))
	if _banner_preview != null:
		_banner_preview.custom_minimum_size.y = (120 if compact else 180) * factor
