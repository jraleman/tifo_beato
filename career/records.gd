extends RefCounted

## Merge-on-write protects progress from stale views and smaller standalone registries.

const SAVE_PATH := "user://tifo_beato.cfg"
var data: Dictionary = {"stars": {}, "records": {}, "rivals": [], "exhibits": [],
	"identity": {}, "banner": {}}
var readable := true

func load_file(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		readable = false
		push_error("Tifo Beato: progress could not be read (%s)." % error_string(error))
		return error
	var stored: Variant = config.get_value("curva", "data", {})
	if not stored is Dictionary or not _valid(stored):
		readable = false
		push_error("Tifo Beato: invalid progress; refusing to overwrite it.")
		return ERR_INVALID_DATA
	readable = true
	_merge(stored, false)
	return OK

func record(key: String, noise: int, stars: int, combo: int) -> void:
	var records: Dictionary = data["records"]
	var previous: Dictionary = records.get(key, {})
	records[key] = {"noise": maxi(noise, int(previous.get("noise", 0))),
		"stars": maxi(stars, int(previous.get("stars", 0))),
		"combo": maxi(combo, int(previous.get("combo", 0)))}

func save_file(path := SAVE_PATH) -> Error:
	if not readable:
		push_error("Tifo Beato: progress is unreadable; save blocked.")
		return ERR_INVALID_DATA
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Tifo Beato: refusing to replace unreadable progress.")
		return error
	var latest: Variant = config.get_value("curva", "data", {})
	if not latest is Dictionary or not _valid(latest):
		push_error("Tifo Beato: progress changed to invalid data; save blocked.")
		return ERR_INVALID_DATA
	_merge(latest, true)
	config.set_value("curva", "data", data)
	error = config.save(path)
	if error != OK:
		push_error("Tifo Beato: progress save failed (%s)." % error_string(error))
	return error

func _valid(stored: Dictionary) -> bool:
	for key in ["stars", "records", "identity", "banner"]:
		if stored.has(key) and not stored[key] is Dictionary:
			return false
	for key in ["rivals", "exhibits"]:
		if stored.has(key) and not _string_array(stored[key]):
			return false
	for key: Variant in stored.get("stars", {}):
		var value: Variant = stored["stars"][key]
		if not key is String or not _number(value) or float(value) < 0.0 \
			or float(value) > 5.0 or float(value) != floorf(float(value)):
			return false
	for key: Variant in stored.get("records", {}):
		var entry: Variant = stored["records"][key]
		if not key is String or not entry is Dictionary:
			return false
		for field in ["noise", "stars", "combo"]:
			var value: Variant = entry.get(field, 0)
			if not _number(value) or float(value) < 0.0:
				return false
		if float(entry.get("stars", 0)) > 5.0:
			return false
	var identity: Dictionary = stored.get("identity", {})
	for key in ["town", "club", "group", "primary", "secondary", "crest", "pattern"]:
		if identity.has(key) and not _number(identity[key]):
			return false
	var banner: Dictionary = stored.get("banner", {})
	for key in ["fabric", "pattern", "crest", "text", "quality"]:
		if banner.has(key) and not _number(banner[key]):
			return false
	for key in ["fringe", "glitter", "lights", "poles"]:
		if banner.has(key) and not banner[key] is bool:
			return false
	for key in ["primary", "secondary"]:
		if banner.has(key) and not banner[key] is Color:
			return false
	return not banner.has("mishaps") or _string_array(banner["mishaps"])

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String:
			return false
	return true

func _merge(stored: Dictionary, keep_edits: bool) -> void:
	var stars: Dictionary = data["stars"]
	for key: String in stored.get("stars", {}):
		stars[key] = maxi(int(stars.get(key, 0)), int(stored["stars"][key]))
	for key: String in stored.get("records", {}):
		var entry: Variant = stored["records"][key]
		record(key, int(entry.get("noise", 0)), int(entry.get("stars", 0)),
			int(entry.get("combo", 0)))
	for key in ["rivals", "exhibits"]:
		var entries: Array = data[key]
		for entry: String in stored.get(key, []):
			if entry not in entries:
				entries.append(entry)
	for key in ["identity", "banner"]:
		if not keep_edits or (data[key] as Dictionary).is_empty():
			data[key] = (stored.get(key, {}) as Dictionary).duplicate(true)
	for key: String in stored:
		if not data.has(key):
			data[key] = stored[key]
