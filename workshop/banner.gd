extends RefCounted

## An original pixel banner can be sampled directly into the crowd's mosaic.

const Words = preload("res://games/tifo_beato/career/word_list.gd")
const Identity = preload("res://games/tifo_beato/career/identity.gd")
const WIDTH := 168
const HEIGHT := 84
const MISHAPS := ["upside_down", "backwards", "missing_letter", "paw_print", "googly_eyes"]
const GLYPHS := {
	"A": ["01110","10001","10001","11111","10001","10001","10001"],
	"B": ["11110","10001","10001","11110","10001","10001","11110"],
	"C": ["01111","10000","10000","10000","10000","10000","01111"],
	"D": ["11110","10001","10001","10001","10001","10001","11110"],
	"E": ["11111","10000","10000","11110","10000","10000","11111"],
	"F": ["11111","10000","10000","11110","10000","10000","10000"],
	"G": ["01111","10000","10000","10111","10001","10001","01110"],
	"H": ["10001","10001","10001","11111","10001","10001","10001"],
	"I": ["11111","00100","00100","00100","00100","00100","11111"],
	"J": ["00111","00010","00010","00010","10010","10010","01100"],
	"K": ["10001","10010","10100","11000","10100","10010","10001"],
	"L": ["10000","10000","10000","10000","10000","10000","11111"],
	"M": ["10001","11011","10101","10101","10001","10001","10001"],
	"N": ["10001","11001","11001","10101","10011","10011","10001"],
	"O": ["01110","10001","10001","10001","10001","10001","01110"],
	"P": ["11110","10001","10001","11110","10000","10000","10000"],
	"Q": ["01110","10001","10001","10001","10101","10010","01101"],
	"R": ["11110","10001","10001","11110","10100","10010","10001"],
	"S": ["01111","10000","10000","01110","00001","00001","11110"],
	"T": ["11111","00100","00100","00100","00100","00100","00100"],
	"U": ["10001","10001","10001","10001","10001","10001","01110"],
	"V": ["10001","10001","10001","10001","10001","01010","00100"],
	"W": ["10001","10001","10001","10101","10101","10101","01010"],
	"X": ["10001","10001","01010","00100","01010","10001","10001"],
	"Y": ["10001","10001","01010","00100","00100","00100","00100"],
	"Z": ["11111","00001","00010","00100","01000","10000","11111"],
	" ": ["00000","00000","00000","00000","00000","00000","00000"],
}
var fabric := 0
var pattern := 0
var crest := 0
var text := 0
var fringe := false
var glitter := false
var lights := false
var poles := false
var quality := 100.0
var mishaps: Array[String] = []
var primary := Identity.COLORS[0]
var secondary := Identity.COLORS[1]

func cost() -> Dictionary:
	var paint: int = 5 + Words.BANNERS[text].length() + crest * 2
	var cloth: int = [8, 12, 18, 20][fabric]
	var extras := (4 if fringe else 0) + (6 if glitter else 0) \
		+ (8 if lights else 0) + (4 if poles else 0)
	return {"fabric": cloth, "paint": paint, "extras": extras, "total": cloth + paint + extras}

func overspend(budget: int) -> int:
	return maxi(0, int(cost()["total"]) - budget)

func apply_mishap(rng: RandomNumberGenerator) -> void:
	mishaps.append(MISHAPS[rng.randi_range(0, MISHAPS.size() - 1)])

func bonus_scale() -> float:
	return clampf(quality / 100.0, 0.0, 1.0)

func to_data() -> Dictionary:
	return {"fabric": fabric, "pattern": pattern, "crest": crest, "text": text,
		"fringe": fringe, "glitter": glitter, "lights": lights, "poles": poles,
		"quality": quality, "mishaps": mishaps.duplicate(),
		"primary": primary, "secondary": secondary}

func from_data(data: Dictionary) -> void:
	fabric = clampi(int(data.get("fabric", 0)), 0, 3)
	pattern = clampi(int(data.get("pattern", 0)), 0, Words.PATTERNS.size() - 1)
	crest = clampi(int(data.get("crest", 0)), 0, Words.CRESTS.size() - 1)
	text = clampi(int(data.get("text", 0)), 0, Words.BANNERS.size() - 1)
	fringe = bool(data.get("fringe", false))
	glitter = bool(data.get("glitter", false))
	lights = bool(data.get("lights", false))
	poles = bool(data.get("poles", false))
	quality = clampf(float(data.get("quality", 100.0)), 0.0, 100.0)
	mishaps.clear()
	for mishap: String in data.get("mishaps", []):
		if mishap in MISHAPS:
			mishaps.append(mishap)
	primary = data.get("primary", Identity.COLORS[0]) if data.get("primary") is Color \
		else Identity.COLORS[0]
	secondary = data.get("secondary", Identity.COLORS[1]) if data.get("secondary") is Color \
		else Identity.COLORS[1]

## Pure image construction is also the model's testable mosaic source.
func render_image() -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			var alternate := false
			match pattern:
				0: alternate = x / 18 % 2 == 1
				1: alternate = x > WIDTH / 2
				2: alternate = (x / 14 + y / 14) % 2 == 1
				3: alternate = floori(atan2(y - HEIGHT / 2, x - WIDTH / 2) * 4.0) % 2 == 0
			var color: Color = secondary if alternate else primary
			if fabric == 1 and (x < 4 or x >= WIDTH - 4 or y < 4 or y >= HEIGHT - 4):
				color = secondary.lightened(0.1) if (x + y) % 6 < 3 else primary.darkened(0.2)
			elif fabric == 2:
				color = color.lightened(0.12 * maxf(0.0, sin((x + y * 2) * 0.025)))
			image.set_pixel(x, y, color)
	var ink := Color("fff6d8")
	var phrase: String = Words.BANNERS[text]
	var origin := (WIDTH - phrase.length() * 12) / 2
	for index in phrase.length():
		if "missing_letter" in mishaps and index == phrase.length() / 2:
			continue
		var glyph: Array = GLYPHS[phrase[index]]
		for row in 7:
			for col in 5:
				if glyph[row][col] != "1":
					continue
				var gy := 6 - row if "upside_down" in mishaps and index == 0 else row
				image.fill_rect(Rect2i(origin + index * 12 + col * 2, 54 + gy * 2, 2, 2), ink)
	# Each charge has a distinct original silhouette, not a real club crest.
	for y in range(10, 43):
		for x in range(WIDTH / 2 - 19, WIDTH / 2 + 20):
			var p := Vector2(x - WIDTH / 2, y - 26)
			var inside := p.length() < 15.0
			match crest:
				1: inside = absf(p.x) + absf(p.y) < 21.0
				2: inside = p.length() < 17.0 and (x + y) % 4 != 0
				3: inside = absf(p.x) < 18.0 and p.y > -8.0 + absf(sin(p.x * 0.3)) * 7.0
				4: inside = absf(p.x) < 9.0 - p.y * 0.2 and absf(p.y) < 16.0
				5: inside = p.length() < 15.0 or absf(p.x) < 20.0 and absf(p.y) < 4.0
			if inside:
				image.set_pixel(x, y, ink)
	for eye in [-7, 7]:
		var eye_color := Color.BLACK
		image.fill_rect(Rect2i(WIDTH / 2 + eye - 2, 21, 4, 4), eye_color)
		if "googly_eyes" in mishaps:
			image.fill_rect(Rect2i(WIDTH / 2 + eye - 3, 20, 6, 6), Color.WHITE)
			image.fill_rect(Rect2i(WIDTH / 2 + eye, 22, 2, 2), Color.BLACK)
	if "paw_print" in mishaps:
		for point in [Vector2i(28, 28), Vector2i(20, 18), Vector2i(27, 15), Vector2i(34, 18)]:
			image.fill_rect(Rect2i(point, Vector2i(6, 6)), Color("684635"))
	if fringe:
		for x in range(0, WIDTH, 6):
			image.fill_rect(Rect2i(x, HEIGHT - 5, 3, 5), ink)
	if glitter or fabric == 3:
		for x in range(3, WIDTH, 13):
			image.set_pixel(x, (x * 17) % HEIGHT, Color.WHITE)
	if lights:
		for x in range(0, WIDTH, 12):
			image.fill_rect(Rect2i(x, 1, 3, 3), Color("f48fb1"))
	if "backwards" in mishaps:
		image.flip_x()
	return image
