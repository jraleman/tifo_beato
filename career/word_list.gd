extends RefCounted

## Closed selections keep banners, lyric slots and share cards safe without free text.

const TOWNS := ["Bucketwick", "Drizzle", "Nebbiolo", "Moonbridge", "Spoonford", "Cloudbank"]
const CLUBS := ["Rovers", "Comets", "Owls", "Spoons", "Pigeons", "Wanderers"]
const GROUPS := ["Bucket Brigade", "Scarf Society", "Fence Choir", "Terrace Club", "Curva Comets"]
const BANNERS := ["FORZA", "ELEVEN STRONG", "SCARVES UP", "KEEP IT GOING", "BUCKETWICK", "OUR CURVA", "SPOONS ALOFT"]
const CRESTS := ["owl", "pigeon", "lion", "crown", "rocket", "mascot"]
const PATTERNS := ["stripes", "halves", "checks", "sunburst", "plain"]
const FABRICS := ["sheet", "tarp", "silk", "glitter"]

static func safe_banner(text: String) -> bool:
	return text in BANNERS and text.length() <= 14
