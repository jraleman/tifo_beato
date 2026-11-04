extends RefCounted

## Preload-safe declarations; persistence and menus belong to the shared shell.

const GAME_ID := "tifo_beato"
const INPUT := "game/tifo_beato_input"
const LATENCY := "game/tifo_beato_latency_ms"
const HEADPHONES := "game/tifo_beato_headphones"
const QUIET := "game/tifo_beato_quiet_mode"
const ANY_SOUND := "game/tifo_beato_any_sound"
const WINDOWS := "game/tifo_beato_windows"
const SPEED := "game/tifo_beato_chant_speed"
const NEVER_DIES := "game/tifo_beato_never_dies"
const RIVALS := "game/tifo_beato_rivals"
const STATIC_LANE := "game/tifo_beato_static_lane"
const COMMENTATOR := "game/tifo_beato_commentator"
const CHATTINESS := "game/tifo_beato_commentator_chattiness"
const TOUCH_LAYOUT := "game/tifo_beato_touch_layout"
const MODE := "game/tifo_beato_mode"
const HOT_SEAT := "game/tifo_beato_hot_seat"
const SOUNDCHECK := "game/tifo_beato_soundcheck"
const BEAT_LEFT := &"tifo_beato_beat_left"
const BEAT_RIGHT := &"tifo_beato_beat_right"
const SHOUT := &"tifo_beato_shout"
const SING_LOW := &"tifo_beato_sing_low"
const SING_MID := &"tifo_beato_sing_mid"
const SING_HIGH := &"tifo_beato_sing_high"
const FURY := &"tifo_beato_fury"
const POWER := &"tifo_beato_power"
const SOUND_ACTIONS: Array[StringName] = [
	BEAT_LEFT, BEAT_RIGHT, SHOUT, SING_LOW, SING_MID, SING_HIGH,
]
const NAVY := Color("1d2a4a")
const BUCKET := Color("f4c430")
const CREAM := Color("fff6d8")
const PITCH := Color("4f9d4a")

const TUNABLES: Array[Dictionary] = [
	{"key": INPUT, "type": "choice", "default": 1, "title": "Instrument",
		"heading": "Tifo Beato - sound", "choices": [
			{"value": 0, "title": "Microphone"}, {"value": 1, "title": "Buttons"}],
		"description": "Microphone needs an explicit soundcheck. Buttons play every chart."},
	{"key": LATENCY, "default": 0.0, "min": -100.0, "max": 400.0, "step": 5.0,
		"format": "milliseconds", "title": "Timing trim",
		"description": "Add to each seat's measured timing. Total compensation is capped at -100 to 400 ms."},
	{"key": HEADPHONES, "type": "toggle", "default": false, "title": "Headphones",
		"description": "Relax the known-output gate after a successful speakers check."},
	{"key": QUIET, "type": "toggle", "default": false, "title": "Quiet Mode",
		"description": "Use comfortable speaking level. Volume never scales your score."},
	{"key": SOUNDCHECK, "type": "toggle", "default": false, "title": "Soundcheck on resume",
		"description": "Request calibration when closing Settings. No microphone opens here."},
	{"key": ANY_SOUND, "type": "toggle", "default": false, "title": "Any sound",
		"heading": "Tifo Beato - assists",
		"description": "Ignore note type and pitch. Rests still mean silence."},
	{"key": WINDOWS, "type": "choice", "default": 0, "title": "Timing windows",
		"choices": [{"value": 0, "title": "Normal"}, {"value": 1, "title": "Wide"},
			{"value": 2, "title": "Widest"}],
		"description": "Widen every grade's window, not just the miss deadline."},
	{"key": SPEED, "type": "choice", "default": 100, "title": "Chant speed",
		"choices": [{"value": 100, "title": "100%"}, {"value": 85, "title": "85%"},
			{"value": 70, "title": "70%"}],
		"description": "Slow the same chart; notes and scoring opportunities are kept."},
	{"key": NEVER_DIES, "type": "toggle", "default": false, "title": "Chant never dies",
		"description": "Prevent walkout. Morale and chant deaths still appear in the results."},
	{"key": RIVALS, "type": "choice", "default": 0, "title": "Rival disruptions",
		"choices": [{"value": 0, "title": "Full"}, {"value": 1, "title": "Gentle"},
			{"value": 2, "title": "Off"}],
		"description": "Gentle halves frequency and sound level. Off removes disruptions."},
	{"key": STATIC_LANE, "type": "toggle", "default": false, "title": "Static beat lane",
		"description": "Notes stay on the phrase grid instead of scrolling."},
	{"key": COMMENTATOR, "type": "choice", "default": 1, "title": "Commentator",
		"heading": "Tifo Beato - presentation",
		"choices": [{"value": 0, "title": "Off"}, {"value": 1, "title": "Captions"}],
		"description": "Original caption-only tragic poetry. No recorded voice-over in this build."},
	{"key": CHATTINESS, "type": "choice", "default": 1, "title": "Commentator chattiness",
		"choices": [{"value": 0, "title": "Quiet"}, {"value": 1, "title": "Normal"},
			{"value": 2, "title": "Chatty"}]},
	{"key": TOUCH_LAYOUT, "type": "choice", "default": 0, "title": "Touch layout",
		"choices": [{"value": 0, "title": "Standard"}, {"value": 1, "title": "Left-handed"},
			{"value": 2, "title": "Right-handed"}]},
	{"key": MODE, "type": "choice", "default": 0, "title": "Solo mode",
		"heading": "Tifo Beato - next match",
		"choices": [{"value": 0, "title": "Career"}, {"value": 1, "title": "Quick match"},
			{"value": 2, "title": "Chant war"}, {"value": 3, "title": "Workshop"}]},
	{"key": HOT_SEAT, "type": "choice", "default": 0, "title": "Hot-seat mode",
		"choices": [{"value": 0, "title": "Duel"}, {"value": 1, "title": "Two Capos"},
			{"value": 2, "title": "Split the Stands"}]},
]

const CONTROL_BINDINGS: Array[Dictionary] = [
	{"key": "controls/tifo_beato_beat_left", "action": BEAT_LEFT, "default": KEY_F,
		"title": "Beat left", "player": 0, "movement": false, "heading": "Tifo Beato",
		"description": "A sharp clap, stamp or bucket hit."},
	{"key": "controls/tifo_beato_beat_right", "action": BEAT_RIGHT, "default": KEY_J,
		"title": "Beat right", "player": 0, "movement": false, "heading": "Tifo Beato",
		"description": "Alternate Beat keys for quick rolls."},
	{"key": "controls/tifo_beato_shout", "action": SHOUT, "default": KEY_SPACE,
		"title": "Shout / hold", "player": 0, "movement": false, "heading": "Tifo Beato",
		"description": "Hold to carry an unvoiced line."},
	{"key": "controls/tifo_beato_sing_low", "action": SING_LOW, "default": KEY_A,
		"title": "Sing LOW", "player": 0, "movement": false, "heading": "Tifo Beato"},
	{"key": "controls/tifo_beato_sing_mid", "action": SING_MID, "default": KEY_S,
		"title": "Sing MID", "player": 0, "movement": false, "heading": "Tifo Beato"},
	{"key": "controls/tifo_beato_sing_high", "action": SING_HIGH, "default": KEY_D,
		"title": "Sing HIGH", "player": 0, "movement": false, "heading": "Tifo Beato"},
	{"key": "controls/tifo_beato_fury", "action": FURY, "default": KEY_Q,
		"title": "Curva Fury", "player": 0, "movement": false, "heading": "Tifo Beato",
		"description": "Unleash a full meter once per half."},
	{"key": "controls/tifo_beato_power", "action": POWER, "default": KEY_E,
		"title": "Power-up", "player": 0, "movement": false, "heading": "Tifo Beato",
		"description": "Use the item in your one-slot inventory."},
]

const GROUNDS: Array[Dictionary] = [
	{"id": "bucketwick_rec", "title": "Bucketwick Rec", "description": "Sunday League. Eleven strong.",
		"crowd": 11, "matches": 3, "budget": 24, "tiers": 1, "size_scale": 1.0,
		"icon": "res://games/tifo_beato/assets/levels/bucketwick_rec.png"},
	{"id": "gasworks_lane", "title": "Gasworks Lane", "description": "Town League. Find your voice.",
		"crowd": 400, "matches": 3, "budget": 36, "tiers": 2, "size_scale": 1.1,
		"requires_achievement": "tifo_beato_promoted_rec", "locked_description": "Earn 9 stars at the Rec.",
		"icon": "res://games/tifo_beato/assets/levels/gasworks_lane.png"},
	{"id": "stadio_nebbiolo", "title": "Stadio Comunale Nebbiolo",
		"description": "Second Division. The fog sings back.",
		"crowd": 6000, "matches": 4, "budget": 48, "tiers": 3, "size_scale": 1.2,
		"requires_achievement": "tifo_beato_promoted_town", "locked_description": "Earn 9 stars at Gasworks Lane.",
		"icon": "res://games/tifo_beato/assets/levels/stadio_nebbiolo.png"},
	{"id": "the_cathedral", "title": "The Cathedral", "description": "The League. A derby for the city.",
		"crowd": 30000, "matches": 4, "budget": 64, "tiers": 4, "size_scale": 1.35,
		"requires_achievement": "tifo_beato_promoted_second", "locked_description": "Earn 9 stars at Nebbiolo.",
		"icon": "res://games/tifo_beato/assets/levels/the_cathedral.png"},
	{"id": "continental_final", "title": "Continental Final", "description": "The whole city. One fence.",
		"crowd": 60000, "matches": 1, "budget": 80, "tiers": 5, "size_scale": 1.5,
		"requires_achievement": "tifo_beato_promoted_league", "locked_description": "Earn 9 stars at The Cathedral.",
		"icon": "res://games/tifo_beato/assets/levels/continental_final.png"},
]
const GROUPS: Array[Dictionary] = [
	{"id": "group_bucket_brigade", "title": "The Bucket Brigade",
		"description": "Your mates, your bucket. Balanced original chants.", "pool": 0},
	{"id": "group_old_guard", "title": "The Old Guard",
		"description": "Comfortable long anthems. Sing +20%; slower life drain.", "pool": 1,
		"requires_achievement": "tifo_beato_promoted_town"},
	{"id": "group_drum_maniacs", "title": "The Drum Maniacs",
		"description": "Dense Beat rolls. Beat combos build 25% faster.", "pool": 2,
		"requires_achievement": "tifo_beato_drum_solo"},
	{"id": "group_flag_wizards", "title": "The Flag Wizards",
		"description": "Choreo specialists. 9-Perfect tifos; tifo bonus +50%.", "pool": 3,
		"requires_achievement": "tifo_beato_first_mosaic"},
	{"id": "group_chaos_kids", "title": "The Chaos Kids",
		"description": "Playful tempo changes. Extra chaos and earlier power-ups.", "pool": 4,
		"requires_achievement": "tifo_beato_seagull"},
]
const STORE_CURRENCY := {
	"name": "Token", "plural": "Tokens", "points_per_score": 0.0025,
	"round_bonus": 5, "win_bonus": 10, "max_per_round": 120,
}
const STORE_SLOTS: Array[Dictionary] = [
	{"id": "tb_capo_hat", "kind": "hat", "title": "Capo hat"},
	{"id": "tb_capo_jacket", "kind": "jacket", "title": "Capo jacket"},
	{"id": "tb_megaphone", "kind": "megaphone", "title": "Megaphone"},
	{"id": "tb_drum", "kind": "drum", "title": "Drum"},
	{"id": "tb_scarf", "kind": "scarf", "title": "Curva scarf"},
	{"id": "tb_fabric", "kind": "fabric", "title": "Banner fabric"},
]
const STORE_ITEMS: Array[Dictionary] = [
	{"id": "tb_hat_bobble", "kind": "hat", "title": "Bobble hat", "price": 0, "default": true, "badge": "BOB", "color": BUCKET},
	{"id": "tb_hat_fisher", "kind": "hat", "title": "Fisherman's cap", "price": 35, "badge": "FISH", "color": NAVY},
	{"id": "tb_hat_crown", "kind": "hat", "title": "Fence crown", "price": 80, "badge": "KING", "color": BUCKET},
	{"id": "tb_hat_cone", "kind": "hat", "title": "Traffic-cone hat", "price": 55, "badge": "CONE", "color": Color("f29045")},
	{"id": "tb_jacket_rain", "kind": "jacket", "title": "Rain jacket", "price": 0, "default": true, "badge": "RAIN", "color": BUCKET},
	{"id": "tb_jacket_bomber", "kind": "jacket", "title": "Bomber jacket", "price": 50, "badge": "BOMB", "color": NAVY},
	{"id": "tb_jacket_fur", "kind": "jacket", "title": "Ridiculous faux fur", "price": 85, "badge": "FUR", "color": Color("ad855a")},
	{"id": "tb_mega_plastic", "kind": "megaphone", "title": "Plastic megaphone", "price": 0, "default": true, "badge": "HEY", "color": CREAM},
	{"id": "tb_mega_horn", "kind": "megaphone", "title": "Gramophone horn", "price": 45, "badge": "HORN", "color": Color("ae873c")},
	{"id": "tb_mega_cone", "kind": "megaphone", "title": "Traffic cone", "price": 35, "badge": "CONE", "color": Color("f29045")},
	{"id": "tb_mega_megatron", "kind": "megaphone", "title": "Brass Megatron", "price": 100, "badge": "MEGA", "color": BUCKET},
	{"id": "tb_drum_bucket", "kind": "drum", "title": "The bucket", "price": 0, "default": true, "badge": "11", "color": Color("8c8f94")},
	{"id": "tb_drum_tin", "kind": "drum", "title": "Biscuit tin", "price": 25, "badge": "TIN", "color": Color("d64541")},
	{"id": "tb_drum_bass", "kind": "drum", "title": "Bass drum", "price": 60, "badge": "BASS", "color": NAVY},
	{"id": "tb_drum_golden", "kind": "drum", "title": "The Golden Bin", "price": 110, "badge": "BIN", "color": BUCKET,
		"requires_achievement": "tifo_beato_final"},
	{"id": "tb_scarf_bars", "kind": "scarf", "title": "Bar scarf", "price": 0, "default": true, "badge": "BARS", "color": BUCKET},
	{"id": "tb_scarf_checks", "kind": "scarf", "title": "Check scarf", "price": 35, "badge": "CHECK", "color": NAVY},
	{"id": "tb_scarf_fringe", "kind": "scarf", "title": "Festival fringe", "price": 65, "badge": "FRINGE", "color": BUCKET},
	{"id": "tb_fabric_sheet", "kind": "fabric", "title": "Bedsheet", "price": 0, "default": true, "badge": "SHEET", "color": CREAM},
	{"id": "tb_fabric_tarp", "kind": "fabric", "title": "Tarpaulin", "price": 30, "badge": "TARP", "color": NAVY},
	{"id": "tb_fabric_silk", "kind": "fabric", "title": "Silk", "price": 70, "badge": "SILK", "color": BUCKET},
	{"id": "tb_fabric_glitter", "kind": "fabric", "title": "Glitter fabric", "price": 90, "badge": "GLIT", "color": Color("f48fb1")},
]

const GALLERY_EXHIBITS: Array[Dictionary] = [
	{"id": "tb_bucket", "title": "The Bucket and Two Spoons", "heading": "Eleven strong", "model": "bucket", "description": "An original bucket. A pair of spoons. An attendance of eleven."},
	{"id": "tb_scarf_wall", "title": "Scarf Wall", "heading": "Tifos", "model": "tifo", "tier": 1},
	{"id": "tb_mosaic", "title": "Every Fan a Pixel", "model": "tifo", "tier": 2, "requires_achievement": "tifo_beato_first_mosaic"},
	{"id": "tb_banner", "title": "The Giant Banner", "model": "tifo", "tier": 3},
	{"id": "tb_smoke", "title": "Soft Cartoon Smoke", "model": "tifo", "tier": 4},
	{"id": "tb_unholy", "title": "The Unholy Choreo", "model": "tifo", "tier": 5, "requires_achievement": "tifo_beato_unholy_choreo"},
	{"id": "tb_group_bucket", "title": "The Bucket Brigade", "heading": "Your curva sections", "model": "group", "pool": 0},
	{"id": "tb_group_guard", "title": "The Old Guard", "model": "group", "pool": 1},
	{"id": "tb_group_drums", "title": "The Drum Maniacs", "model": "group", "pool": 2},
	{"id": "tb_group_flags", "title": "The Flag Wizards", "model": "group", "pool": 3},
	{"id": "tb_group_chaos", "title": "The Chaos Kids", "model": "group", "pool": 4},
	{"id": "tb_rival_sandro", "title": "Big Sandro", "heading": "Fictional rival capos", "model": "rival", "rival": 0},
	{"id": "tb_rival_pauk", "title": "Fraulein Paukenschlag", "model": "rival", "rival": 1},
	{"id": "tb_rival_pulpo", "title": "El Pulpo", "model": "rival", "rival": 2},
	{"id": "tb_rival_moustache", "title": "Madame Moustache", "model": "rival", "rival": 3},
	{"id": "tb_rival_twins", "title": "The Twins", "model": "rival", "rival": 4},
	{"id": "tb_seagull", "title": "The Banner Thief", "heading": "Chaos cast", "model": "seagull"},
	{"id": "tb_skin", "title": "The Split Drum Skin", "model": "drum_skin"},
	{"id": "tb_cut", "title": "A Cappella Floodlights", "model": "power_cut"},
	{"id": "tb_balls", "title": "Beach Balls", "model": "beach_balls"},
	{"id": "tb_rain", "title": "The Umbrella Section", "model": "rain"},
	{"id": "tb_kevin", "title": "Kevin and His Kazoo", "model": "kevin"},
	{"id": "tb_steward", "title": "Very Thorough Stewards", "model": "steward"},
	{"id": "tb_rec", "title": "Bucketwick Rec", "heading": "Ground dioramas", "model": "ground", "ground": 0},
	{"id": "tb_gasworks", "title": "Gasworks Lane", "model": "ground", "ground": 1},
	{"id": "tb_nebbiolo", "title": "Stadio Comunale Nebbiolo", "model": "ground", "ground": 2},
	{"id": "tb_cathedral", "title": "The Cathedral", "model": "ground", "ground": 3},
	{"id": "tb_final", "title": "Continental Final", "model": "ground", "ground": 4},
]

const ACHIEVEMENTS := {
	"tifo_beato_first_chant": {"title": "Eleven Strong", "badge": "11", "description": "Finish a match at Bucketwick Rec."},
	"tifo_beato_promoted_rec": {"title": "Out of the Rec", "badge": "RECCED", "description": "Earn 9 career stars at Bucketwick Rec."},
	"tifo_beato_promoted_town": {"title": "Town Criers", "badge": "TOWN", "description": "Earn 9 career stars at Gasworks Lane."},
	"tifo_beato_promoted_second": {"title": "Fog Horns", "badge": "2ND", "description": "Earn 9 career stars at Stadio Comunale Nebbiolo."},
	"tifo_beato_promoted_league": {"title": "The Cathedral Sings", "badge": "LEAGUE", "description": "Earn 9 career stars at The Cathedral."},
	"tifo_beato_final": {"title": "The Whole City", "badge": "FINAL", "description": "Finish the Continental Final with at least 3 stars."},
	"tifo_beato_never_died": {"title": "Ninety Minutes", "badge": "NONSTOP", "description": "Finish a match without an actual chant death."},
	"tifo_beato_meltdown": {"title": "Full Curva Meltdown", "badge": "4X", "description": "Reach a 64-hit combo."},
	"tifo_beato_fury": {"title": "Curva Fury", "badge": "FURY", "description": "Unleash Curva Fury."},
	"tifo_beato_first_mosaic": {"title": "Every Fan a Pixel", "badge": "MOSAIC", "description": "Reveal your actual banner as a card mosaic."},
	"tifo_beato_unholy_choreo": {"title": "The Unholy Choreo", "badge": "CHOREO", "description": "Reveal a tier-5 tifo."},
	"tifo_beato_drum_solo": {"title": "The Drum Is Mine", "badge": "SOLO", "description": "Score 32 Beats in one Drum solo."},
	"tifo_beato_seagull": {"title": "Give It Back", "badge": "GULL", "description": "Win the seagull chase."},
	"tifo_beato_a_cappella": {"title": "Lights Back On", "badge": "A CAPPELLA", "description": "Win the power cut."},
	"tifo_beato_rally": {"title": "Back from the Dead", "badge": "RALLY", "description": "Rally a dead chant and still earn 3 stars."},
	"tifo_beato_chant_war": {"title": "Sing-Off", "badge": "DUEL", "description": "Win a complete chant war."},
	"tifo_beato_all_rivals": {"title": "Undisputed", "badge": "5 CAPOS", "description": "Beat all five fictional rival capos."},
	"tifo_beato_mishap": {"title": "The Crowd Loves It Anyway", "badge": "OOPS", "description": "Reveal a banner with at least three mishaps."},
	"tifo_beato_smuggler": {"title": "Nothing to Declare", "badge": "FLAG", "description": "Sneak the flag through without a setback, then finish its career match."},
	"tifo_beato_keeper_tremble": {"title": "He Has Seen the Curva", "badge": "KNEES", "description": "Keep the rival keeper trembling for a full half."},
	"tifo_beato_two_capos": {"title": "Two Capos", "badge": "DUO", "description": "Finish a complete two-human hot-seat set."},
}
