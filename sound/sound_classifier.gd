extends RefCounted

## One classifier for every instrument; sustained events retain the original attack.

const Frame = preload("res://games/tifo_beato/sound/sound_frame.gd")
const Event = preload("res://games/tifo_beato/sound/sound_event.gd")
const ONSET_FLUX_RATIO := 3.0
const MIN_FLUX := 0.015
const REFRACTORY_SECONDS := 0.06
const NOISE_MARGIN := 3.981072
const SILENCE_MARGIN := 1.995262
const DECAY_RATIO := 0.177828
const CLAP_SECONDS := 0.12
const SUSTAIN_SECONDS := 0.15
const SILENCE_SECONDS := 0.25
const SHOUT_LEVEL := 0.5
const SING_CLARITY := 0.8
const HISTORY_SIZE := 25
var noise_floor := 0.01
var band_width := 250.0
var _flux_history: Array[float] = []
var _last_onset := -100.0
var _attack := -1.0
var _peak := 0.0
var _quiet_since := -1.0
var _voiced_since := -1.0
var _cents: Array[float] = []
var _clap_emitted := false
var _silence_emitted := false

func reset() -> void:
	_flux_history.clear()
	_cents.clear()
	_last_onset = -100.0
	_attack = -1.0
	_voiced_since = -1.0
	_quiet_since = -1.0
	_peak = 0.0
	_clap_emitted = false
	_silence_emitted = false

## A sustained vowel may change rung without a new amplitude onset.
func consume(frame: Frame) -> Array[Event]:
	var events: Array[Event] = []
	var floor_level := maxf(noise_floor, 0.001)
	var onset := frame.flux >= maxf(MIN_FLUX, _median(_flux_history) * ONSET_FLUX_RATIO) \
		and frame.level >= floor_level * NOISE_MARGIN \
		and frame.t - _last_onset >= REFRACTORY_SECONDS - 0.000001
	if onset:
		_last_onset = frame.t
		_attack = frame.t
		_peak = frame.level
		_clap_emitted = false
		_cents.clear()
		events.append(Event.new(frame.t, Event.ONSET, frame.level, _band(frame.cents)))
	_flux_history.append(frame.flux)
	if _flux_history.size() > HISTORY_SIZE:
		_flux_history.pop_front()
	var silent := frame.level < floor_level * SILENCE_MARGIN
	if silent:
		if _quiet_since < 0.0:
			_quiet_since = frame.t
		if not _silence_emitted and frame.t - _quiet_since >= SILENCE_SECONDS:
			events.append(Event.new(_quiet_since, Event.SILENCE, 0.0, 0,
				frame.t - _quiet_since))
			_silence_emitted = true
	else:
		_quiet_since = -1.0
		_silence_emitted = false
	if _attack >= 0.0:
		var duration := frame.t - _attack
		_peak = maxf(_peak, frame.level)
		if not _clap_emitted and duration <= CLAP_SECONDS + 0.01 \
			and frame.level <= _peak * DECAY_RATIO and duration > 0.0:
			events.append(Event.new(_attack, Event.CLAP, _peak, 0, duration))
			_clap_emitted = true
		if frame.level >= SHOUT_LEVEL and duration >= SUSTAIN_SECONDS - 0.000001:
			events.append(Event.new(_attack, Event.SHOUT, minf(frame.level, 1.0), 0,
				duration, frame.voiced))
		if silent and duration > CLAP_SECONDS:
			_attack = -1.0
	if frame.voiced and frame.clarity >= SING_CLARITY and not silent:
		if _voiced_since < 0.0:
			_voiced_since = frame.t
		_cents.append(frame.cents)
		if _cents.size() > 15:
			_cents.pop_front()
		if frame.t - _voiced_since >= SUSTAIN_SECONDS - 0.000001:
			var start := _attack if _attack >= 0.0 else _voiced_since
			events.append(Event.new(start, Event.SING, minf(frame.level, 1.0),
				_band(_median(_cents)), frame.t - start, true))
	else:
		_voiced_since = -1.0
		_cents.clear()
	return events

func _band(cents: float) -> int:
	return -1 if cents < -band_width else (1 if cents > band_width else 0)

static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var middle := ordered.size() / 2
	return ordered[middle] if ordered.size() % 2 == 1 \
		else (ordered[middle - 1] + ordered[middle]) * 0.5
