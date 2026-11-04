extends RefCounted

## Small shared building blocks keep game-owned overlay layouts consistent.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")

static func label(parent: Node, text: String, heading := false) -> Label:
	var node := Label.new()
	node.text = text
	node.accessibility_name = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", 30 if heading else 23)
	node.add_theme_color_override("font_color", Options.BUCKET if heading else Options.CREAM)
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.accessibility_name = text
	node.tooltip_text = text
	node.custom_minimum_size.y = 72
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 23)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

static func choice(parent: Node, title: String, values: Array,
	selected: int, action: Callable) -> OptionButton:
	label(parent, title)
	var node := OptionButton.new()
	node.fit_to_longest_item = false
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.accessibility_name = title
	node.custom_minimum_size.y = 72
	node.add_theme_font_size_override("font_size", 23)
	for value: Variant in values:
		node.add_item(str(value))
	if not values.is_empty():
		node.select(clampi(selected, 0, values.size() - 1))
	node.item_selected.connect(action)
	parent.add_child(node)
	return node

static func toggle(parent: Node, title: String, checked: bool,
	action: Callable) -> CheckButton:
	var node := CheckButton.new()
	node.text = title
	node.accessibility_name = title
	node.button_pressed = checked
	node.custom_minimum_size.y = 72
	node.add_theme_font_size_override("font_size", 23)
	node.toggled.connect(action)
	parent.add_child(node)
	return node

static func number(parent: Node, title: String, minimum: float, maximum: float,
	step: float, value: float, action: Callable) -> SpinBox:
	label(parent, title)
	var node := SpinBox.new()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = value
	node.custom_minimum_size.y = 72
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.accessibility_name = title
	node.get_line_edit().add_theme_font_size_override("font_size", 23)
	node.value_changed.connect(action)
	parent.add_child(node)
	return node

static func panel(parent: Node) -> VBoxContainer:
	var panel_node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172439")
	style.border_color = Color("a88b40")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel_node.add_theme_stylebox_override("panel", style)
	parent.add_child(panel_node)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel_node.add_child(layout)
	return layout

static func scale_tree(root: Node, factor: float) -> void:
	if root is Control:
		var control := root as Control
		if control is Label or control is BaseButton or control is LineEdit or control is TextEdit:
			if not control.has_meta("tifo_base_font"):
				control.set_meta("tifo_base_font", control.get_theme_font_size("font_size"))
			control.add_theme_font_size_override("font_size",
				roundi(float(control.get_meta("tifo_base_font")) * factor))
		if control is BaseButton or control is SpinBox:
			control.custom_minimum_size.y = 72 * factor
		if control is BoxContainer:
			control.add_theme_constant_override("separation", roundi(10 * factor))
	for child in root.get_children():
		scale_tree(child, factor)

static func factor(control: Control) -> float:
	var settings := control.get_tree().root.get_node_or_null("Settings")
	var requested := float(settings.call("get_value", "ui/scale")) if settings != null else 1.0
	# Window content scaling already applies the requested UI scale once.
	return maxf(1.0, control.get_viewport_rect().size.x \
		/ maxf(control.get_window().size.x, 1.0) * requested / 1.5)

static func touch_minimum(control: Control) -> float:
	return maxf(44.0 * factor(control), 44.0 * control.get_viewport_rect().size.x \
		/ maxf(1.0, control.get_window().size.x))
