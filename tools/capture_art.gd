extends SceneTree

## Captures only the game's original Godot models, never the user's desktop.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Stage = preload("res://games/tifo_beato/presentation/stage.gd")
var _failures := PackedStringArray()
var _stage: Control

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Original art capture needs a real Compatibility graphics window.")
		quit(1)
		return
	var destination := "res://games/tifo_beato/assets"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--art-dir="):
			destination = argument.trim_prefix("--art-dir=").replace("\\", "/")
	for folder in ["", "levels", "intro"]:
		var error := DirAccess.make_dir_recursive_absolute(destination.path_join(folder))
		if error != OK:
			printerr("Cannot create the scoped art destination: " + error_string(error))
			quit(1)
			return
	_stage = Stage.new()
	_stage.set("purpose", "capture")
	_stage.size = Vector2(1200, 675)
	get_root().add_child(_stage)
	await process_frame
	for index in 5:
		_stage.size = Vector2(1200, 675)
		_stage.call("configure", {"id": Options.GROUNDS[index]["id"], "model": "ground", "ground": index})
		await _save(destination.path_join("levels/%s.png" % Options.GROUNDS[index]["id"]))
	for index in 5:
		_stage.call("configure", {"id": "intro_%d" % index, "model": "intro", "card": index})
		await _save(destination.path_join("intro/card%d.png" % (index + 1)))
	_stage.size = Vector2(512, 512)
	_stage.call("configure", {"id": "the_fence", "model": "intro", "card": 4})
	await _save(destination.path_join("game-icon.png"))
	get_root().remove_child(_stage)
	_stage.free()
	if _failures.is_empty():
		print("Original game icon, five grounds and five story cards captured: " + destination)
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _save(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport := _stage.get("world_viewport") as SubViewport
	var image := viewport.get_texture().get_image()
	if image.is_empty():
		_failures.append("GPU returned no original artwork for " + path)
		return
	var backdrop := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	backdrop.fill(Options.NAVY)
	backdrop.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	var error := backdrop.save_png(path)
	if error != OK:
		_failures.append("Artwork save failed: %s (%s)" % [path, error_string(error)])
	else:
		print("Captured " + path)
