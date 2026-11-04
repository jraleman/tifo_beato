extends RefCounted

## Adapted game-owned MPM/NSDF; continuous voice pitch, without guitar onset logic.

const WINDOW_SIZE := 512
const DECIMATION := 4
const MIN_FREQUENCY := 75.0
const MAX_FREQUENCY := 900.0
const MIN_CLARITY := 0.8
const PEAK_THRESHOLD := 0.9

## Samples are decimated before NSDF; DC removal protects biased capture devices.
static func analyse(samples: PackedFloat32Array, sample_rate: float,
	noise_floor := 0.001) -> Dictionary:
	var result := {"voiced": false, "hz": 0.0, "clarity": 0.0, "rms": 0.0}
	if samples.size() < WINDOW_SIZE * DECIMATION:
		return result
	var work := PackedFloat32Array()
	work.resize(WINDOW_SIZE)
	var start := samples.size() - WINDOW_SIZE * DECIMATION
	var mean := 0.0
	for i in WINDOW_SIZE:
		var value := 0.0
		for k in DECIMATION:
			value += samples[start + i * DECIMATION + k]
		work[i] = value / DECIMATION
		mean += work[i]
	mean /= WINDOW_SIZE
	var energy := 0.0
	for i in WINDOW_SIZE:
		work[i] -= mean
		energy += work[i] * work[i]
	result["rms"] = sqrt(energy / WINDOW_SIZE)
	if float(result["rms"]) < noise_floor:
		return result
	var rate := sample_rate / DECIMATION
	var min_lag := maxi(2, floori(rate / MAX_FREQUENCY) - 1)
	var max_lag := mini(WINDOW_SIZE - 3, ceili(rate / MIN_FREQUENCY) + 1)
	var nsdf := PackedFloat32Array()
	nsdf.resize(max_lag + 3)
	for lag in nsdf.size():
		var correlation := 0.0
		var magnitude := 0.0
		for j in WINDOW_SIZE - lag:
			var a := work[j]
			var b := work[j + lag]
			correlation += a * b
			magnitude += a * a + b * b
		nsdf[lag] = 0.0 if magnitude <= 0.0 else 2.0 * correlation / magnitude
	var peaks: Array[Vector2] = []
	var strongest := 0.0
	for lag in range(min_lag, max_lag + 1):
		if nsdf[lag] > nsdf[lag - 1] and nsdf[lag] >= nsdf[lag + 1]:
			var peak := _interpolate(nsdf, lag)
			peaks.append(peak)
			strongest = maxf(strongest, peak.y)
	if strongest < MIN_CLARITY:
		return result
	for peak in peaks:
		if peak.y < strongest * PEAK_THRESHOLD:
			continue
		var frequency := rate / peak.x
		if frequency < MIN_FREQUENCY or frequency > MAX_FREQUENCY:
			continue
		result["voiced"] = true
		result["hz"] = frequency
		result["clarity"] = clampf(peak.y, 0.0, 1.0)
		return result
	return result

static func cents_from(hz: float, centre: float) -> float:
	return 1200.0 * log(maxf(hz, 0.001) / maxf(centre, 0.001)) / log(2.0)

static func _interpolate(values: PackedFloat32Array, lag: int) -> Vector2:
	var before := values[lag - 1]
	var here := values[lag]
	var after := values[lag + 1]
	var curvature := before - 2.0 * here + after
	if absf(curvature) < 0.000001:
		return Vector2(lag, here)
	var shift := clampf(0.5 * (before - after) / curvature, -1.0, 1.0)
	return Vector2(lag + shift, here - 0.25 * (before - after) * shift)
