extends RefCounted

## The date is frozen at kickoff; local midnight never changes an active match.

const MODIFIERS := ["rain", "power_cut", "beach_balls", "kazoo"]
const TITLES := ["Umbrella derby", "A cappella derby", "Beach-ball derby", "Kevin's derby"]
const HISTORY_LIMIT := 366

static func today() -> String:
	return Time.get_date_string_from_system(false)

static func challenge(date: String) -> Dictionary:
	assert(valid_date(date), "Daily Derby needs a real calendar date.")
	var seed_value := int(date.replace("-", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ground := rng.randi_range(0, 4)
	var pool := rng.randi_range(0, 4)
	var rival := rng.randi_range(0, 4)
	var modifier := rng.randi_range(0, MODIFIERS.size() - 1)
	return {"mode": "daily", "date": date, "seed": seed_value,
		"ground": ground, "pool": pool, "rival": rival,
		"modifier": MODIFIERS[modifier], "title": TITLES[modifier]}

static func record(history: Dictionary, date: String, noise: int,
	stars: int, combo: int) -> void:
	assert(valid_date(date), "Cannot record an invalid daily date.")
	var previous: Dictionary = history.get(date, {})
	var yesterday := adjacent(date, -1)
	var streak := int(history.get(yesterday, {}).get("streak", 0)) + 1
	history[date] = {"noise": maxi(noise, int(previous.get("noise", 0))),
		"stars": maxi(stars, int(previous.get("stars", 0))),
		"combo": maxi(combo, int(previous.get("combo", 0))),
		"streak": maxi(streak, int(previous.get("streak", 0)))}
	_refresh(history)

static func merge(history: Dictionary, stored: Dictionary) -> void:
	for date: String in stored:
		var entry: Dictionary = history.get(date, {}).duplicate()
		for key in ["noise", "stars", "combo", "streak"]:
			entry[key] = maxi(int(entry.get(key, 0)), int(stored[date][key]))
		history[date] = entry
	_refresh(history)

static func _refresh(history: Dictionary) -> void:
	var dates: Array = history.keys()
	dates.sort()
	for index in dates.size():
		var day := str(dates[index])
		var yesterday_record: Dictionary = history.get(adjacent(day, -1), {})
		if not yesterday_record.is_empty():
			history[day]["streak"] = maxi(int(history[day]["streak"]),
				int(yesterday_record["streak"]) + 1)
	while dates.size() > HISTORY_LIMIT:
		history.erase(dates.pop_front())

static func streak(history: Dictionary, date: String) -> int:
	return int(history.get(date, history.get(adjacent(date, -1), {})).get("streak", 0))

static func adjacent(date: String, days: int) -> String:
	var seconds := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(seconds + days * 86400)

static func valid_date(date: String) -> bool:
	if date.length() != 10 or date[4] != "-" or date[7] != "-":
		return false
	for index in date.length():
		if index not in [4, 7] and date[index] not in "0123456789":
			return false
	var year := int(date.left(4))
	var month := int(date.substr(5, 2))
	var day := int(date.right(2))
	if year < 1970 or year > 9998 or month < 1 or month > 12:
		return false
	var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var lengths: Array[int] = [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day >= 1 and day <= lengths[month - 1]

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() > HISTORY_LIMIT:
		return false
	for date: Variant in value:
		if not date is String or not valid_date(date) or not value[date] is Dictionary:
			return false
		for key in ["noise", "stars", "combo", "streak"]:
			var number: Variant = value[date].get(key)
			if not (number is int or number is float) or not is_finite(float(number)) \
				or float(number) != floorf(float(number)) or float(number) < 0.0:
				return false
		if int(value[date]["stars"]) > 5 or int(value[date]["streak"]) < 1:
			return false
	return true
