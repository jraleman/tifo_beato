extends RefCounted

## Empty-tail, off-grid transients preserve the bleed gate's timing guarantee.

const KINDS := ["air_horn", "trumpet", "rival_drums", "inflatable"]
const CAPTIONS := {
	"air_horn": "RIVAL AIR HORN: stay on your drum.",
	"trumpet": "RIVAL TRUMPET: follow your own pitch rungs.",
	"rival_drums": "RIVAL TEMPO: the ghost lane is not yours.",
	"inflatable": "RIVAL INFLATABLE: your notes still count.",
}
var slots: Array[Dictionary] = []
var active := ""
var active_left := 0.0
var _telegraphed: Dictionary = {}
var _fired: Dictionary = {}

func _init(available: Array[Dictionary] = [], seed_value := 1, setting := 0,
	hostile := false) -> void:
	if setting == 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 801
	for index in available.size():
		var ordinary := index % (6 if setting == 1 else 3) == 2
		var extra := hostile and index % (6 if setting == 1 else 3) == (
			5 if setting == 1 else 0)
		if not ordinary and not extra:
			continue
		var slot := available[index].duplicate(true)
		slot["kind"] = KINDS[rng.randi_range(0, KINDS.size() - 1)]
		slot["level"] = 0.5 if setting == 1 else 1.0
		slots.append(slot)

func advance(time: float, dt: float, protected: bool) -> Array[Dictionary]:
	active_left = maxf(0.0, active_left - dt)
	if active_left <= 0.0 or protected:
		active = ""
	var events: Array[Dictionary] = []
	for index in slots.size():
		var slot := slots[index]
		if not _telegraphed.has(index) and time >= float(slot["telegraph"]):
			_telegraphed[index] = true
			events.append({"kind": "telegraph", "text": CAPTIONS[str(slot["kind"])]})
		if not _fired.has(index) and time >= float(slot["t"]):
			_fired[index] = true
			if not protected:
				active = str(slot["kind"])
				active_left = float(slot["beat"]) * (16.0 if active == "rival_drums" else 8.0)
				events.append(slot)
	return events

## A rally moves only unfired slots; past cues and their telegraphs stay consumed.
func retime(available: Array[Dictionary], now: float) -> void:
	var by_phase: Dictionary = {}
	for slot in available:
		by_phase[int(slot["phase"])] = slot
	for index in slots.size():
		if _fired.has(index):
			continue
		var slot := slots[index]
		var phase := int(slot["phase"])
		if not by_phase.has(phase):
			_fired[index] = true
			_telegraphed[index] = true
			continue
		var updated: Dictionary = by_phase[phase]
		for key in ["t", "telegraph", "beat"]:
			slot[key] = updated[key]
		if float(slot["telegraph"]) < now:
			_telegraphed[index] = true
