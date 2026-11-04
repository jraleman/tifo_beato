extends Node

## Explicit, private capture. The bus is silenced after the capture effect.

signal capture_failed(reason: String)
const BUS_NAME := "TifoCapture"
const SILENT_DB := -80.0
const RECORD_PERMISSION := "android.permission.RECORD_AUDIO"
var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _bus := ""
var _elapsed := 0.0
var _peak := 0.0
var failed := false
var _received := false
var _waiting_permission := false

func _ready() -> void:
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		_fail("Recording is disabled in this build. Use Buttons.")
		return
	if OS.has_feature("android") and RECORD_PERMISSION not in OS.get_granted_permissions():
		_waiting_permission = true
		get_tree().on_request_permissions_result.connect(_on_permission)
		OS.request_permission(RECORD_PERMISSION)
		return
	_open_stream()

func _open_stream() -> void:
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	_bus = BUS_NAME + str(get_instance_id())
	AudioServer.set_bus_name(index, _bus)
	AudioServer.set_bus_volume_db(index, SILENT_DB)
	AudioServer.set_bus_send(index, "Master")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(index, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = _bus
	add_child(_player)
	_player.play()

func poll() -> PackedVector2Array:
	if failed or _capture == null:
		return PackedVector2Array()
	var frames := _capture.get_buffer(_capture.get_frames_available())
	for frame in frames:
		_peak = maxf(_peak, absf(frame.x + frame.y) * 0.5)
	_received = _received or not frames.is_empty()
	return frames

func _process(delta: float) -> void:
	if failed or _waiting_permission:
		return
	_elapsed += delta
	if _elapsed > 10.0 and (not _received or _peak <= 0.0):
		_fail("No microphone signal. Allow recording, choose a device, or use Buttons.")

func clear() -> void:
	if _capture != null:
		_capture.clear_buffer()

## Closing synchronously stops capture even while the owning node awaits deletion.
func close() -> void:
	if _player != null:
		_player.stop()
	if _capture != null:
		_capture.clear_buffer()
	_capture = null
	var index := AudioServer.get_bus_index(_bus)
	if not _bus.is_empty() and index >= 0:
		AudioServer.remove_bus(index)
	_bus = ""

func _on_permission(permission: String, granted: bool) -> void:
	if permission != RECORD_PERMISSION or not _waiting_permission:
		return
	_waiting_permission = false
	if granted:
		_open_stream()
	else:
		_fail("Recording permission was declined. Buttons play the complete game.")

func _fail(reason: String) -> void:
	failed = true
	close()
	capture_failed.emit(reason)

func _exit_tree() -> void:
	close()
