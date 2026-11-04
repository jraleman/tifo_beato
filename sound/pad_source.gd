extends RefCounted

## Fixed gamepad extras feed the same contact model as rebound keyboard keys.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const KeySource = preload("res://games/tifo_beato/sound/key_source.gd")
var previous: Dictionary = {}

func reset() -> void:
	previous.clear()

## Resume never turns a button already held under a modal into a new chant attack.
func prime(device: int) -> void:
	previous = _held(device)

func poll(device: int, time: float, source: KeySource) -> Dictionary:
	var held := _held(device)
	var result := {"fury": false, "power": false}
	for action: StringName in held:
		var pressed := bool(held[action])
		if pressed == bool(previous.get(action, false)):
			continue
		if action in Options.SOUND_ACTIONS:
			source.set_action(action, pressed, time, "pad_" + str(action))
		elif pressed:
			result["fury" if action == Options.FURY else "power"] = true
	previous = held
	return result

func _held(device: int) -> Dictionary:
	if device < 0:
		return {}
	var sing := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.35
	var stick := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	return {
		Options.BEAT_LEFT: Input.is_joy_button_pressed(device, JOY_BUTTON_A) \
			or Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER),
		Options.BEAT_RIGHT: Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
			or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER),
		Options.SHOUT: Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.35,
		Options.SING_LOW: sing and stick > 0.4,
		Options.SING_MID: sing and absf(stick) <= 0.4,
		Options.SING_HIGH: sing and stick < -0.4,
		Options.FURY: Input.is_joy_button_pressed(device, JOY_BUTTON_Y),
		Options.POWER: Input.is_joy_button_pressed(device, JOY_BUTTON_B),
	}
