extends RefCounted

## Best stars, not football results, unlock the train line.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const PROMOTIONS := ["tifo_beato_promoted_rec", "tifo_beato_promoted_town",
	"tifo_beato_promoted_second", "tifo_beato_promoted_league"]
const PROMOTION_STARS := 9
var stars: Dictionary = {}

func stop_key(ground: int, stop: int) -> String:
	return "%s_%d" % [Options.GROUNDS[clampi(ground, 0, 4)]["id"], stop]

func best_stars(ground: int, stop: int) -> int:
	return int(stars.get(stop_key(ground, stop), 0))

func ground_stars(ground: int) -> int:
	var total := 0
	for stop in int(Options.GROUNDS[ground]["matches"]):
		total += best_stars(ground, stop)
	return total

func ground_unlocked(ground: int) -> bool:
	return ground == 0 or ground_stars(ground - 1) >= PROMOTION_STARS

func stop_unlocked(ground: int, stop: int) -> bool:
	if not ground_unlocked(ground):
		return false
	return stop == 0 or best_stars(ground, stop - 1) > 0

func next_stop(ground: int) -> int:
	for stop in int(Options.GROUNDS[ground]["matches"]):
		if best_stars(ground, stop) == 0:
			return stop
	return int(Options.GROUNDS[ground]["matches"]) - 1

func record(ground: int, stop: int, earned: int, career_match: bool) -> PackedStringArray:
	if not career_match:
		return PackedStringArray()
	assert(ground >= 0 and ground < 5 and stop >= 0 \
		and stop < int(Options.GROUNDS[ground]["matches"]), "Unknown career stop.")
	var key := stop_key(ground, stop)
	stars[key] = maxi(int(stars.get(key, 0)), clampi(earned, 0, 5))
	var awards := PackedStringArray()
	for index in 4:
		if ground_stars(index) >= PROMOTION_STARS:
			awards.append(PROMOTIONS[index])
	if ground == 4 and earned >= 3:
		awards.append("tifo_beato_final")
	return awards

func merge(data: Dictionary) -> void:
	for key: String in data:
		stars[key] = maxi(int(stars.get(key, 0)), clampi(int(data[key]), 0, 5))
