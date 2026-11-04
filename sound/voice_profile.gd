extends RefCounted

## Calibration is separate from progress and contains measurements, never audio.

const SAVE_PATH := "user://tifo_beato_voice.cfg"
var latency_ms := 0.0
var noise_floor := 0.002
var speak_level := 0.08
var carry_level := 0.16
var centre_hz := 220.0
var band_width_cents := 250.0
var bleed_level := 0.08
var headphones := false
var calibrated := false

## A button is an instrument with a known, identical carry/speaking level.
func make_virtual() -> void:
	noise_floor = 0.01
	speak_level = 1.0
	carry_level = 1.0
	calibrated = true

func normalized_level(raw: float, quiet: bool) -> float:
	return raw / maxf(speak_level if quiet else carry_level, 0.0001)

func to_data() -> Dictionary:
	return {"latency_ms": latency_ms, "noise_floor": noise_floor,
		"speak_level": speak_level, "carry_level": carry_level, "centre_hz": centre_hz,
		"band_width_cents": band_width_cents, "bleed_level": bleed_level,
		"headphones": headphones, "calibrated": calibrated}

func from_data(data: Dictionary) -> void:
	latency_ms = clampf(float(data.get("latency_ms", 0.0)), -100.0, 400.0)
	noise_floor = clampf(float(data.get("noise_floor", 0.002)), 0.00001, 0.2)
	speak_level = clampf(float(data.get("speak_level", 0.08)), 0.0001, 1.0)
	carry_level = clampf(float(data.get("carry_level", 0.16)), speak_level, 1.0)
	centre_hz = clampf(float(data.get("centre_hz", 220.0)), 75.0, 900.0)
	band_width_cents = clampf(float(data.get("band_width_cents", 250.0)), 80.0, 500.0)
	bleed_level = clampf(float(data.get("bleed_level", 0.08)), 0.0, 1.0)
	headphones = bool(data.get("headphones", false))
	calibrated = bool(data.get("calibrated", false))

func load_file(seat: int, path := SAVE_PATH, instrument := "mic") -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		push_error("Tifo Beato: could not read soundcheck (%s)." % error_string(error))
		return error
	var key := "P%d" % (seat + 1) + ("_buttons" if instrument == "buttons" else "")
	var data: Variant = config.get_value("profiles", key, {})
	if not data is Dictionary:
		push_error("Tifo Beato: invalid soundcheck profile.")
		return ERR_INVALID_DATA
	from_data(data)
	return OK

func save_file(seat: int, path := SAVE_PATH, instrument := "mic") -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Tifo Beato: refusing to replace unreadable soundcheck.")
		return error
	var key := "P%d" % (seat + 1) + ("_buttons" if instrument == "buttons" else "")
	config.set_value("profiles", key, to_data())
	error = config.save(path)
	if error != OK:
		push_error("Tifo Beato: soundcheck save failed (%s)." % error_string(error))
	return error
