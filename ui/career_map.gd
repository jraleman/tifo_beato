extends VBoxContainer

## The train line exposes real stop gates and best stars, not football wins.

signal stop_selected(ground: int, stop: int)
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Career = preload("res://games/tifo_beato/career/career_state.gd")
const Widgets = preload("res://games/tifo_beato/ui/widgets.gd")
var career := Career.new()

func _ready() -> void:
	add_theme_constant_override("separation", 18)
	for ground in 5:
		var section := Widgets.panel(self)
		var unlocked := career.ground_unlocked(ground)
		Widgets.label(section, "%d -- %s" % [ground + 1, Options.GROUNDS[ground]["title"]], true)
		Widgets.label(section, "%d / 9 promotion stars. %s" % [career.ground_stars(ground),
			"Stars open the next station." if unlocked else "Earn 9 stars at the previous ground."])
		var stops := HBoxContainer.new()
		section.add_child(stops)
		for stop in int(Options.GROUNDS[ground]["matches"]):
			var button := Widgets.button(stops, "%d\n%d/5 stars" % [
				stop + 1, career.best_stars(ground, stop)],
				func() -> void: stop_selected.emit(ground, stop))
			button.disabled = not career.stop_unlocked(ground, stop)
			button.tooltip_text = "Play stop %d at %s" % [stop + 1, Options.GROUNDS[ground]["title"]]
