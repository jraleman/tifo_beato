extends RefCounted

## Sections carry the audible/visible scatter; presentation never feeds it back.

var sections: Array[Dictionary] = []
var energy := 50.0
var sync := 0.5
var phase_scatter := 0.3
var joining := 0.0
var history: Array[float] = []

func _init(crowd_size := 11) -> void:
	for section in 5:
		sections.append({"size": maxi(1, crowd_size / 5), "sync": 0.5,
			"phase_scatter": 0.3, "morale_offset": section * 0.01})

func judge(grade: int) -> void:
	history.append([1.0, 0.8, 0.45, 0.0][grade])
	if history.size() > 128:
		history.pop_front()
	for section in sections:
		var delta: float = [0.045, 0.01, -0.015, -0.08][grade]
		section["sync"] = clampf(float(section["sync"]) + delta, 0.0, 1.0)
		section["phase_scatter"] = clampf(
			float(section["phase_scatter"]) - delta * 0.9, 0.02, 0.65)
	sync = float(sections[0]["sync"])
	phase_scatter = float(sections[0]["phase_scatter"])
	joining = minf(0.2, joining + 0.004) if grade == 0 else maxf(0.0, joining - 0.002)

func advance(dt: float, chant_life: float, combo_tier: int, fury: bool) -> void:
	var average := 0.5
	if not history.is_empty():
		average = 0.0
		for value in history:
			average += value
		average /= history.size()
	var target := (average * 0.5 + sync * 0.2 + chant_life / 100.0 * 0.2 \
		+ combo_tier / 4.0 * 0.1) * 100.0
	energy = 100.0 if fury else lerpf(energy, target, 1.0 - exp(-dt / 2.0))

func seat_phase(index: int, seed_value: int) -> float:
	return fmod(float((index * 7919 + seed_value * 17) % 1009) / 1009.0 \
		* phase_scatter, 1.0)
