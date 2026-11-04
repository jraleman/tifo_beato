extends RefCounted

## Identity stores curated indices, never arbitrary player-facing strings.

const Words = preload("res://games/tifo_beato/career/word_list.gd")
const COLORS := [
	Color("f4c430"), Color("1d2a4a"), Color("fff6d8"), Color("d64541"),
	Color("4f9d4a"), Color("69b3d0"), Color("f48fb1"), Color("8c8f94"),
	Color("f29045"), Color("704eaa"), Color("2c8781"), Color("a75535"),
	Color("a5cf56"), Color("684635"), Color("eeeeee"), Color("30343a"),
]
var town := 0
var club := 0
var group := 0
var primary := 0
var secondary := 1
var crest := 0
var pattern := 0

func club_name() -> String:
	return Words.TOWNS[town] + " " + Words.CLUBS[club]

func group_name() -> String:
	return Words.GROUPS[group]

func lyric_slot() -> String:
	return Words.TOWNS[town].to_upper()

func low_contrast() -> bool:
	return absf(COLORS[primary].get_luminance() - COLORS[secondary].get_luminance()) < 0.22

func to_data() -> Dictionary:
	return {"town": town, "club": club, "group": group, "primary": primary,
		"secondary": secondary, "crest": crest, "pattern": pattern}

func from_data(data: Dictionary) -> void:
	town = clampi(int(data.get("town", 0)), 0, Words.TOWNS.size() - 1)
	club = clampi(int(data.get("club", 0)), 0, Words.CLUBS.size() - 1)
	group = clampi(int(data.get("group", 0)), 0, Words.GROUPS.size() - 1)
	primary = clampi(int(data.get("primary", 0)), 0, COLORS.size() - 1)
	secondary = clampi(int(data.get("secondary", 1)), 0, COLORS.size() - 1)
	crest = clampi(int(data.get("crest", 0)), 0, Words.CRESTS.size() - 1)
	pattern = clampi(int(data.get("pattern", 0)), 0, Words.PATTERNS.size() - 1)
