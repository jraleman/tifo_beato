extends RefCounted

## A seeded five-zone possession walk, stepped only at 10 Hz.

const STEP_SECONDS := 0.1
var home := 0
var away := 0
var zone := 2
var home_possession := true
var keeper_tremble_seconds := 0.0
var time := 0.0
var events: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _pending := 0.0
var _decision := 0.0
var _away_keeper_form := 0.0

func _init(seed_value := 1) -> void:
	_rng.seed = seed_value
	_away_keeper_form = 0.45 if _rng.randf() < 0.08 else _rng.randf_range(-0.08, 0.08)

func advance(dt: float, energy: float, ref_stall := false) -> Array[Dictionary]:
	_pending += maxf(0.0, dt)
	while _pending >= STEP_SECONDS - 0.000001:
		_pending -= STEP_SECONDS
		time += STEP_SECONDS
		if energy >= 70.0:
			keeper_tremble_seconds += STEP_SECONDS
		_decision -= STEP_SECONDS
		if _decision > 0.0:
			continue
		_decision = 0.7 + _rng.randf() * 0.7
		if ref_stall and not home_possession:
			events.append({"kind": "ref", "t": time})
			continue
		var pass_chance := 0.6
		if home_possession:
			pass_chance += 0.15 if energy >= 70.0 else 0.0
			pass_chance += (energy - 50.0) / 500.0
		else:
			pass_chance -= maxf(0.0, energy - 50.0) / 500.0
			pass_chance += 0.12 if energy < 30.0 else 0.0
		if _rng.randf() > pass_chance:
			home_possession = not home_possession
			zone = clampi(zone + (1 if home_possession else -1), 0, 4)
			continue
		zone = clampi(zone + (1 if home_possession else -1), 0, 4)
		if (home_possession and zone == 4) or (not home_possession and zone == 0):
			var save_chance := 0.78 + _away_keeper_form - energy / 400.0 if home_possession else (
				0.78 + (0.1 if energy >= 80.0 else 0.0))
			save_chance = clampf(save_chance, 0.05, 0.98)
			if _rng.randf() > save_chance:
				if home_possession:
					home += 1
				else:
					away += 1
				events.append({"kind": "goal_home" if home_possession else "goal_away",
					"t": time, "home": home, "away": away})
			zone = 2
			home_possession = not home_possession
	var reached := events
	events = []
	return reached
