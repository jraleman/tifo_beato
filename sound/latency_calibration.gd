extends RefCounted

## Adapted nearest-click median matching; failed measurements are never saved.

const COUNT_IN_BEATS := 2
const MIN_SAMPLES := 4
const MAX_SPREAD_MS := 45.0
var clicks: Array[float] = []
var onsets: Array[float] = []
var beat_seconds := 0.6

func measure() -> Dictionary:
	var used := {}
	var offsets: Array[float] = []
	for index in range(COUNT_IN_BEATS, clicks.size()):
		var best := -1
		var distance := beat_seconds * 0.5
		for onset in onsets.size():
			var difference := absf(onsets[onset] - clicks[index])
			if not used.has(onset) and difference < distance:
				best = onset
				distance = difference
		if best >= 0:
			used[best] = true
			offsets.append((onsets[best] - clicks[index]) * 1000.0)
	if offsets.size() < MIN_SAMPLES:
		return {"ok": false, "message": "Not enough steady claps. Try again or use Buttons."}
	offsets.sort()
	var middle := offsets.size() / 2
	var median := offsets[middle] if offsets.size() % 2 else (
		offsets[middle - 1] + offsets[middle]) * 0.5
	var spread := 0.0
	for offset in offsets:
		spread += absf(offset - median)
	spread /= offsets.size()
	if spread > MAX_SPREAD_MS or median < -100.0 or median > 400.0:
		return {"ok": false, "message": "Claps were not consistent enough to measure. Retry.",
			"latency_ms": median, "spread_ms": spread}
	return {"ok": true, "latency_ms": median, "spread_ms": spread,
		"message": "Timing: %.0f ms, spread %.0f ms." % [median, spread]}
