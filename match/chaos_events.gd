extends RefCounted

## Seeded events have explicit success criteria and a gentle, visible failure.

const KINDS := ["seagull", "drum_skin", "power_cut", "beach_balls", "rain", "kazoo"]
const CAPTIONS := {
	"seagull": "SEAGULL CHASE: 8 Perfects bring the banner back.",
	"drum_skin": "SPLIT DRUM: keep the visual beat for eight bars.",
	"power_cut": "A CAPPELLA: carry a perfect line to restore the lights.",
	"beach_balls": "BEACH BALLS: hits pop them; the notes still count.",
	"rain": "RAIN: finish a Hold to raise the umbrellas.",
	"kazoo": "KEVIN'S KAZOO: hold the Rests to let him finish.",
}
var active := ""
var left := 0.0
var progress := 0
var successes: Array[String] = []
var failures: Array[String] = []
var resolutions: Array[Dictionary] = []
var score_during := 0.0
var seat_points: Array[float] = [0.0, 0.0]
var _target := 8
var _misses := 0
var _queue: Array[String] = []
var _next_time := 35.0
var _slots: Array[float] = []

func _init(seed_value := 1, ground := 0, extra := false) -> void:
	var pools := [["kazoo", "rain"], ["seagull", "beach_balls"],
		["drum_skin", "rain"], ["power_cut", "beach_balls"], KINDS]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 901
	var pool: Array = pools[clampi(ground, 0, 4)]
	var available := pool.duplicate()
	while not available.is_empty():
		_queue.append(str(available.pop_at(rng.randi_range(0, available.size() - 1))))
		if ground != 4 and _queue.size() == (3 if extra else 2):
			break
	if extra and ground != 4 and _queue.size() < 3:
		_queue.append(str(pool[rng.randi_range(0, pool.size() - 1)]))

## Slots span playable responses, not the long half-time reservation.
func schedule(responses: Array[float]) -> void:
	_slots.clear()
	for index in _queue.size():
		var at := floori(float(index + 1) * responses.size() / (_queue.size() + 1))
		if not responses.is_empty():
			_slots.append(responses[mini(at, responses.size() - 1)])
	if not _slots.is_empty():
		_next_time = _slots[0]

func retime(after: float, shift: float) -> void:
	for index in _slots.size():
		if _slots[index] >= after:
			_slots[index] += shift
	if not _slots.is_empty():
		_next_time = _slots[0]

func begin(kind: String, beat_seconds := 0.6) -> void:
	assert(kind in KINDS, "Unknown chaos event.")
	active = kind
	left = beat_seconds * 32.0
	progress = 0
	_misses = 0
	score_during = 0.0
	seat_points = [0.0, 0.0]
	_target = 1 if kind == "rain" else (2 if kind == "kazoo" else 8)

func judge(result: Dictionary) -> bool:
	if active.is_empty():
		return false
	var grade := int(result["grade"])
	score_during += float(result.get("points", 0.0))
	seat_points[clampi(int(result.get("seat", 0)), 0, 1)] += float(result.get("points", 0.0))
	if grade == 3:
		_misses += 1
	var kind := str(result["kind"])
	match active:
		"rain":
			progress += 1 if kind == "hold" and grade < 3 else 0
		"kazoo":
			progress += 1 if kind == "rest" and grade == 0 else 0
		"beach_balls":
			progress += 1 if grade < 3 else 0
		_:
			progress += 1 if grade == 0 else 0
	if progress >= _target and active != "drum_skin":
		_finish(true)
		return true
	return false

func advance(time: float, dt: float, beat: float, allow_start: bool) -> String:
	if not active.is_empty():
		left -= dt
		if left <= 0.0:
			_finish(active == "drum_skin" and _misses == 0 and progress > 0)
	if active.is_empty() and allow_start and time >= _next_time and not _queue.is_empty():
		begin(_queue.pop_front(), beat)
		if not _slots.is_empty():
			_slots.pop_front()
		_next_time = _slots[0] if not _slots.is_empty() else time + 70.0
		return active
	return ""

func _finish(won: bool) -> void:
	(successes if won else failures).append(active)
	resolutions.append({"kind": active, "success": won,
		"points": score_during if won and active == "drum_skin" else 0.0,
		"seat_points": seat_points.duplicate() if won and active == "drum_skin" else [0.0, 0.0]})
	active = ""
	left = 0.0
