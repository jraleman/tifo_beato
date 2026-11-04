extends MenuScreen

## Five original stills tell the small-bucket story; every card is skippable.

const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"
const CARDS := [
	"Bucketwick Rec. Attendance: eleven.\nThree of them are the groundsman's family.",
	"You find a bucket. You find two spoons.\nYou find your purpose.",
	"One day you'll lead the Curva Nord at the Continental Final,\nwith the whole city singing.",
	"Today, you lead Kevin.\nKevin brought a kazoo.",
	"Get on the fence. Don't let the chant die.\nFORZA!",
]
var _card := 0
var _layout: VBoxContainer
var _image: TextureRect
var _copy: Label
var _next: Button

func _ready() -> void:
	_layout = VBoxContainer.new()
	add_child(_layout)
	_layout.minimum_size_changed.connect(_fit_layout)
	Widgets.label(_layout, "TIFO BEATO", true)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(_image)
	_copy = Widgets.label(_layout, "", true)
	var actions := HBoxContainer.new()
	_layout.add_child(actions)
	_next = Widgets.button(actions, "Next", _advance)
	Widgets.button(actions, "Skip story", _on_skip_pressed)
	first_focus = _next
	_show_card()
	super()

func _show_card() -> void:
	_copy.text = CARDS[_card]
	_image.texture = load("res://games/tifo_beato/assets/intro/card%d.png" % (_card + 1)) as Texture2D
	_next.text = "FORZA!" if _card == 4 else "Next - %d/5" % (_card + 1)

func _advance() -> void:
	if _card == 4:
		go_back()
	else:
		_card += 1
		_show_card()

func go_back() -> void:
	Router.goto(next_scene)

func _on_skip_pressed() -> void:
	go_back()

func _on_layout_changed(dimensions: Vector2) -> void:
	if _layout == null:
		return
	var factor := Widgets.factor(self)
	_copy.set_meta("tifo_base_font", 23 if dimensions.y < 700.0 * factor else 30)
	Widgets.scale_tree(_layout, factor)
	_fit_layout()

func _fit_layout() -> void:
	# Wrapping can lower the VBox minimum after its first sort.
	var factor := Widgets.factor(self)
	var inset := 24 * factor
	_layout.position = Vector2.ONE * inset
	_layout.size = get_viewport_rect().size - Vector2.ONE * inset * 2
