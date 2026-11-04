extends RefCounted

## Five escalating exchanges; human calls become the opponent's actual echo chart.

const Judge = preload("res://games/tifo_beato/match/chant_judge.gd")
const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Classifier = preload("res://games/tifo_beato/sound/sound_classifier.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const Cpu = preload("res://games/tifo_beato/sound/cpu_source.gd")
const RIVALS: Array[Dictionary] = [
	{"id": "sandro", "title": "Big Sandro", "club": "Lokomotiv Lasagne",
		"group": "Brigata Lasagna", "accuracy": 0.88, "style": "Slow, crushing timing"},
	{"id": "paukenschlag", "title": "Fraulein Paukenschlag", "club": "Borussia Bratwurst",
		"group": "Nordblock Bratwurst", "accuracy": 0.82, "style": "Fast drum rolls"},
	{"id": "pulpo", "title": "El Pulpo", "club": "Sporting Sardinas",
		"group": "Los Ocho Brazos", "accuracy": 0.78, "style": "Wild syncopation"},
	{"id": "moustache", "title": "Madame Moustache", "club": "Olympique Moustache",
		"group": "Les Sourcils", "accuracy": 0.86, "style": "Long singing lines"},
	{"id": "twins", "title": "The Twins", "club": "Inter Nebula",
		"group": "Nebula Ultras", "accuracy": 0.92, "style": "Two halves of one call"},
]
const INSULTS := [
	"Your drum is a biscuit tin. We respect the biscuits.",
	"Nice scarf. Tell its knitter it is lovely.",
	"Our tea has a stronger rhythm.",
	"Kevin has requested a kazoo solo.",
	"Your megaphone has excellent manners.",
]
const ECHO_BUDGET := 700.0
var phases: Array[Dictionary] = []
var beats: Array[float] = []
var duration := 0.0
var time := 0.0
var phase := -1
var scores: Array[float] = [0.0, 0.0]
var exchange_wins: Array[int] = [0, 0]
var cpu_rival := true
var rival := 0
var complete := false
var judge: Judge
var classifier := Classifier.new()
var cpu_classifier := Classifier.new()
var cpu: Cpu
var calls: Array[Array] = [[], []]
var accepted: Array[Dictionary] = []
var events: Array[Dictionary] = []
var _seed := 1
var _seen: Dictionary = {}
var _exchange_start: Array[float] = [0.0, 0.0]
var _cpu_time := 0.0
var _echo_scale := 0.0
var configuration: Dictionary = {}

func _init(seed_value := 1, rival_index := 0, humans := false,
	settings: Dictionary = {}) -> void:
	_seed = seed_value
	rival = clampi(rival_index, 0, RIVALS.size() - 1)
	cpu_rival = not humans
	configuration = settings.duplicate(true)
	var speed := float(settings.get("speed", 100)) / 100.0
	duration = 3.0
	phases.append({"t": 0.0, "end": duration, "kind": "staredown", "seat": -1,
		"beat": 0.5, "exchange": 0})
	for exchange in 5:
		var beat := 60.0 / (120.0 + exchange * 6.0) / speed
		var order := [1, 0, 0, 1] if cpu_rival else [0, 1, 1, 0]
		for turn in 4:
			var human := not cpu_rival or int(order[turn]) == 0
			var lead := beat * 2.0 if human else 0.0
			var end := duration + lead + beat * 8.0 + (0.6 if human else 0.0)
			phases.append({"t": duration, "end": end, "call_t": duration + lead,
				"kind": "call" if turn % 2 == 0 else "echo", "seat": order[turn],
				"caller": order[turn - 1] if turn % 2 == 1 else order[turn],
				"exchange": exchange, "beat": beat})
			for pulse in (10 if human else 8):
				beats.append(duration + pulse * beat)
			duration = end

func input_seat() -> int:
	if phase < 0:
		return -1
	var seat := int(phases[phase]["seat"])
	return -1 if cpu_rival and seat == 1 else seat

func caption() -> String:
	if phase <= 0:
		return "THE STARE-DOWN. PREPARE YOUR SCARF."
	var turn := phases[phase]
	var who: String = RIVALS[rival]["title"] if cpu_rival and int(turn["seat"]) == 1 \
		else "P%d" % (int(turn["seat"]) + 1)
	return "%s: %s - exchange %d/5. %s" % [who, str(turn["kind"]).to_upper(),
		int(turn["exchange"]) + 1, INSULTS[int(turn["exchange"])]]

func consume(frame: Frame) -> void:
	if complete or input_seat() < 0:
		return
	frame = Frame.new(frame.t - float(configuration.get("latency_ms", 0.0)) / 1000.0,
		frame.level, frame.flux, frame.voiced, frame.cents, frame.clarity)
	_process_frame(frame, classifier)

func advance(now: float) -> Array[Dictionary]:
	if complete:
		return []
	time = minf(now, duration + 0.4)
	var target := phases.size() - 1
	for index in phases.size():
		if time < float(phases[index]["end"]):
			target = index
			break
	while phase < target:
		_advance_cpu(float(phases[phase]["end"]) if phase >= 0 else 0.0)
		_settle()
		phase += 1
		_begin_turn()
	_advance_cpu(time)
	_settle_judgements(time)
	if now >= duration + 0.4:
		_settle()
		complete = true
	var reached := events
	events = []
	return reached

func _advance_cpu(until: float) -> void:
	if not cpu_rival or phase <= 0 or int(phases[phase]["seat"]) != 1:
		return
	while _cpu_time <= until + 0.000001:
		_process_frame(cpu.frame_at(_cpu_time), cpu_classifier)
		_cpu_time += 0.01

func winner() -> int:
	if exchange_wins[0] != exchange_wins[1]:
		return 0 if exchange_wins[0] > exchange_wins[1] else 1
	return -1 if is_equal_approx(scores[0], scores[1]) else (0 if scores[0] > scores[1] else 1)

func _begin_turn() -> void:
	classifier.reset()
	cpu_classifier.reset()
	_seen.clear()
	judge = null
	if phase <= 0:
		return
	var turn := phases[phase]
	var seat := int(turn["seat"])
	var pattern: Array[Dictionary] = []
	if str(turn["kind"]) == "call":
		calls[seat] = []
		if cpu_rival and seat == 1:
			var beat := float(turn["beat"])
			var offsets: Array = [[0.0, 1.0, 2.0, 3.0, 4.0, 5.0],
				[0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5],
				[0.0, 0.75, 1.75, 3.25, 4.5, 6.75],
				[0.0, 1.5, 3.0, 4.0, 5.0, 6.5],
				[0.0, 1.0, 2.5, 4.0, 5.5, 7.0]][rival]
			for hit in offsets.size():
				var offset := float(offsets[hit])
				pattern.append({"id": hit, "t": float(turn["call_t"]) + offset * beat,
					"kind": "sing" if rival == 3 else "beat",
					"duration": beat * (0.8 if rival == 3 else 0.6),
					"band": (hit % 3) - 1, "hold_kind": "sing"})
	else:
		for original: Dictionary in calls[int(turn["caller"])]:
			var note := original.duplicate(true)
			note["t"] = float(turn["call_t"]) + float(original["beat"]) * float(turn["beat"])
			note["duration"] = minf(float(turn["beat"]) * 0.65,
				float(original.get("duration", 0.3)))
			note["id"] = pattern.size()
			pattern.append(note)
		judge = Judge.new(pattern, configuration)
		# Echo accuracy has equal value regardless of the other capo's call density.
		var maximum := 0.0
		for index in pattern.size():
			var combo := index + 1
			var multiplier := 4.0 if combo >= 64 else (3.0 if combo >= 32 else (
				2.0 if combo >= 16 else (1.5 if combo >= 8 else 1.0)))
			maximum += 120.0 * multiplier
		_echo_scale = ECHO_BUDGET / maximum if maximum > 0.0 else 0.0
		if pattern.is_empty():
			scores[seat] += ECHO_BUDGET
			events.append({"kind": "empty_call", "seat": seat,
				"text": "No call: the other capo takes this echo turn."})
	if cpu_rival and seat == 1:
		cpu = Cpu.new(pattern, 1.0 if str(turn["kind"]) == "call" \
			else float(RIVALS[rival]["accuracy"]), _seed + phase)
	_cpu_time = float(turn["t"])
	events.append({"kind": "turn", "seat": input_seat(), "text": caption()})

func _process_frame(frame: Frame, source_classifier: Classifier) -> void:
	if phase <= 0:
		return
	var turn := phases[phase]
	if judge != null:
		judge.observe(frame)
	for event in source_classifier.consume(frame):
		if str(turn["kind"]) == "echo":
			judge.consume(event)
		elif event.kind in [Event.ONSET, Event.SING, Event.SHOUT]:
			var beat := (event.t - float(turn["call_t"])) / float(turn["beat"])
			var grid := roundi(beat * 4.0)
			if grid < 0 or grid >= 32:
				continue
			var error := absf(beat - grid / 4.0) * float(turn["beat"])
			var key := snappedf(event.t, 0.00001)
			if _seen.has(key):
				if event.kind == Event.SING or event.kind == Event.SHOUT:
					var note: Dictionary = calls[int(turn["seat"])][int(_seen[key])]
					note["kind"] = "sing" if event.kind == Event.SING else "shout"
					note["band"] = event.band
					note["duration"] = event.duration
				continue
			if error > 0.14 * [1.0, 1.5, 2.0][int(configuration.get("windows", 0))]:
				continue
			var occupied := false
			for note: Dictionary in calls[int(turn["seat"])]:
				if is_equal_approx(float(note["beat"]), grid / 4.0):
					occupied = true
			if occupied:
				continue
			_seen[key] = calls[int(turn["seat"])].size()
			calls[int(turn["seat"])].append({"beat": grid / 4.0, "kind": "beat",
				"duration": 0.3, "band": event.band, "hold_kind": "sing"})
			var points := 25.0 * (1.0 - minf(error / 0.14, 1.0) * 0.5)
			points *= 1.1 if grid % 4 else 1.0
			scores[int(turn["seat"])] += points
			accepted.append({"t": frame.t, "seat": int(turn["seat"]), "kind": "call"})
			if cpu_rival and int(turn["seat"]) == 1:
				events.append({"kind": "rival_note", "band": event.band})
	_settle_judgements(frame.t)

func _settle_judgements(now: float) -> void:
	if judge == null or phase <= 0:
		return
	for result in judge.advance(now):
		var seat := int(phases[phase]["seat"])
		result["points"] = float(result["points"]) * _echo_scale
		result["seat"] = seat
		scores[seat] += float(result["points"])
		accepted.append(result)
		events.append({"kind": "grade", "seat": seat, "result": result})

func _settle() -> void:
	if phase <= 0:
		return
	_settle_judgements(float(phases[phase]["end"]) + 0.4)
	if phase % 4 == 0:
		var first := scores[0] - _exchange_start[0]
		var second := scores[1] - _exchange_start[1]
		if not is_equal_approx(first, second):
			exchange_wins[0 if first > second else 1] += 1
		_exchange_start = scores.duplicate()
