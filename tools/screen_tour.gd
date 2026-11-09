extends RefCounted

## Screen-tour hook: a finished career opens every ground, rival and tifo exhibit.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const Career = preload("res://games/tifo_beato/career/career_state.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")
const Registration = preload("res://games/tifo_beato/game.gd")

## Runs only in the tour's isolated profile. Club, banner, chants, derby, daily
## and moments stay fresh, so their first-run screens are kept.
func seed_profile() -> String:
	var records := Records.new()
	if records.load_file() != OK:
		return "Tifo Beato's progress could not be read; its career was not seeded."
	var career := Career.new()
	career.merge(records.data["stars"])
	var stops := 0
	for ground in Options.GROUNDS.size():
		for stop in int(Options.GROUNDS[ground]["matches"]):
			career.record(ground, stop, 5, true)
			stops += 1
	records.data["stars"] = career.stars.duplicate()
	for rival in War.RIVALS:
		if str(rival["id"]) not in records.data["rivals"]:
			records.data["rivals"].append(str(rival["id"]))
	for exhibit in Options.GALLERY_EXHIBITS:
		var tifo := "tifo_%d" % int(exhibit.get("tier", 0))
		if str(exhibit["model"]) == "tifo" and tifo not in records.data["exhibits"]:
			records.data["exhibits"].append(tifo)
	var error := records.save_file()
	if error != OK:
		return "Tifo Beato's career could not be saved (%s)." % error_string(error)
	var game := GameCatalog.get_manifest(Options.GAME_ID)
	if game != null:
		Registration.refresh_gallery(game, records.data)
	return "Seeded Tifo Beato's career: %d stops at five stars, %d rivals, %d tifos." % [
		stops, records.data["rivals"].size(), records.data["exhibits"].size()]
