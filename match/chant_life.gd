extends RefCounted

## Only judged music refreshes the grace; crowd responses are safe breathing time.

const GRACE_SECONDS := 1.5
const DRAIN_PER_SECOND := 20.0
var life := 70.0
var morale := 100.0
var deaths := 0
var dead := false
var walkout := false
var never_dies := false
var drain_scale := 1.0
var rally_beats := 0
var rallied := false
var _quiet_seconds := 0.0
var _last_rally_beat := -100.0

func refill(amount: float) -> void:
	if dead:
		return
	life = minf(100.0, life + maxf(0.0, amount))
	_quiet_seconds = 0.0

func sustain() -> void:
	if not dead:
		_quiet_seconds = 0.0

func advance(dt: float, judging: bool, protected_rest: bool, fury_active: bool) -> bool:
	if dead or walkout:
		return false
	if fury_active:
		life = 100.0
		_quiet_seconds = 0.0
		return false
	if not judging or protected_rest:
		_quiet_seconds = 0.0
		return false
	var before := maxf(0.0, _quiet_seconds - GRACE_SECONDS)
	_quiet_seconds += maxf(0.0, dt)
	var draining := maxf(0.0, _quiet_seconds - GRACE_SECONDS) - before
	life = maxf(0.0, life - draining * DRAIN_PER_SECOND * drain_scale)
	if life <= 0.0:
		dead = true
		deaths += 1
		morale = maxf(0.0, morale - 30.0)
		rally_beats = 0
		walkout = morale <= 0.0 and not never_dies
		return true
	return false

func rally(time: float, strength: float, beat_error: float) -> bool:
	if not dead or walkout or strength < 0.8 or absf(beat_error) > 0.14:
		return false
	if time - _last_rally_beat < 0.06:
		return false
	_last_rally_beat = time
	rally_beats += 1
	if rally_beats < 4:
		return false
	dead = false
	rallied = true
	life = 50.0
	_quiet_seconds = 0.0
	return true
