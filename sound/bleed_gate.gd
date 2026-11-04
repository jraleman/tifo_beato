extends RefCounted

## Never consume the rival/crowd's turn; known emissions carry measured bleed.

const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const OUTPUT_WINDOW := 0.04
const PLAYER_MARGIN := 1.995262
var headphones := false
var emissions: Array[Dictionary] = []

func register_output(time: float, measured_level: float, duration := 0.0) -> void:
	emissions.append({"t": time, "end": time + maxf(0.0, duration),
		"level": maxf(0.0, measured_level)})

func accepts(event: Event, judging: bool) -> bool:
	if not judging:
		return false
	return accepts_level(event.t, event.level)

func accepts_level(time: float, level: float) -> bool:
	if headphones:
		return true
	for output in emissions:
		if time >= float(output["t"]) - OUTPUT_WINDOW \
			and time <= float(output["end"]) + OUTPUT_WINDOW:
			if level < float(output["level"]) * PLAYER_MARGIN:
				return false
	return true

func prune(time: float) -> void:
	while not emissions.is_empty() and float(emissions[0]["end"]) < time - 2.0:
		emissions.pop_front()
