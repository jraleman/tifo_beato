extends RefCounted

## Tifo Beato's complete shell contract remains game-owned and preload-safe.

const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
const Records = preload("res://games/tifo_beato/career/records.gd")
const War = preload("res://games/tifo_beato/match/chant_war.gd")

static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Tifo Beato"
	game.tagline = "Ninety minutes. No silence."
	game.menu_order = 12
	game.gameplay_scene_path = "res://games/tifo_beato/gameplay.tscn"
	game.intro_scene_path = "res://games/tifo_beato/intro.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.uses_shell_round_rules = false
	game.supports_multiplayer = true
	game.supports_cpu_opponent = false
	game.max_local_players = 2
	game.local_multiplayer_turns = true
	game.characters = Options.GROUPS
	game.levels = Options.GROUNDS
	game.character_preview_scene_path = "res://games/tifo_beato/character_preview.tscn"
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.solo_setup_choices = [Options.MODE]
	game.store_currency = Options.STORE_CURRENCY
	game.store_slots = Options.STORE_SLOTS
	game.store_items = Options.STORE_ITEMS
	game.store_preview_scene_path = "res://games/tifo_beato/store_preview.tscn"
	refresh_gallery(game, {})
	game.gallery_stage_scene_path = "res://games/tifo_beato/gallery_stage.tscn"
	game.share_art_scene_path = "res://games/tifo_beato/share_art.tscn"
	game.tutorial_video_path = "res://games/tifo_beato/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/tifo_beato/assets/video/tutorial_poster.webp"
	game.stats_url = "https://deskcansaw.com"
	game.save_files = [{"path": Records.SAVE_PATH, "title": "The Curva",
		"description": "Career, identity, banners, derby preparation, saved chants, daily bests and read-only Best Moments."}]
	game.achievements = Options.ACHIEVEMENTS
	game.copy = {
		"level_label": "Ground", "character_label": "Curva section",
		"mode_select_intro": "Choose your ground and a section inside your own curva.",
		"single_player_description": "Lead original chants with a microphone or Buttons. Your railway also has Away days, Derby week, Chant Creator, Daily Derby and Best Moments.",
		"multiplayer_description": "Pass one instrument for Duel, Two Capos, Split the Stands or an unranked Creator challenge.",
		"solo_confirm_title": "Your ground, your curva",
		"solo_confirm_description": "Choose %s. Buttons are the privacy-first default. The microphone opens only after an explicit soundcheck.",
		"versus_confirm_title": "Two capos. One instrument.",
		"versus_confirm_description": "P1 stays blue and P2 red. Duel echoes each other's calls. Two Capos shares life and Fury. Split gives both seats the same P1 chart and seed. Select the hot-seat mode on the railway.",
		"player_one_control_description": "Beat, Shout and three comfortable pitch rungs; Hold means sustain, X means silence.",
		"player_two_control_description": "Pass the megaphone after the named P2 card. Release the old inputs before confirming. Your own soundcheck stays with your seat.",
		"instructions_headline": "GET ON THE FENCE",
		"instructions_solo_summary": "Hit the shaped notes in your call; breathe while your actual call comes back.",
		"instructions_versus_summary": "Hot seat uses one instrument and deliberate handoffs. Results and one Tokens payout wait for the final turn.",
		"instructions_rules": "Attendance: eleven. You find a bucket, two spoons and a purpose. Kevin brought a kazoo.\n"
			+ "Square BEAT: a sharp clap, stamp or button. Circle SHOUT: carry for at least 150 ms. SING: LOW, MID and HIGH are relative to your comfortable centre, never an absolute song pitch. HOLD needs 80% coverage; X REST means silence.\n"
			+ "Perfect / Great / Good windows: 45 / 90 / 140 ms. Timing comes from the audible guide drum, not the render frame. Button, touch, gamepad and microphone streams use the same classifier.\n"
			+ "Chant Life starts at 70. Call silence has 1.5s grace, then drains; responses and Rests are safe. A dead chant costs morale. Four strong on-grid Beats rally it. Zero morale sends the curva to the pie stand.\n"
			+ "Combos grow at 8, 16, 32 and 64. Perfects fill Fury, once per half for eight seconds. Every bonus can be earned with Buttons. Q unleashes Fury; E uses your one-slot power-up. Volume is capped at comfortable carry level.\n"
			+ "Perfect streaks reveal scarf walls, your real banner mosaic, the giant banner, cartoon smoke and the Unholy Choreo. Crowd energy biases the seeded toy football match, but even perfect support cannot guarantee a win.\n"
			+ "Career promotion needs nine best stars, not football wins. Last stops have gentle steward checks and five-exchange halftime sing-offs. Quick and hot-seat modes never change career stars. Workshop quality and mishaps are saved into the real banner image.\n"
			+ "Away days offer a chosen-tempo wiper bus, station echoes with scored silence, and hostile ends with twice the safe disruptions. Away career stops offer optional bus/train travel. Short practice keeps its authored chart: no Fury or power-ups.\n"
			+ "Derby week prepares Cathedral stop 4 against Inter Nebula: paint a mural, rehearse, or rally the pub, bakery and barber. Only each ritual's best counts, up to +25 starting morale and +25% crowd. These activities never gate the derby or pay Tokens.\n"
			+ "Chant Creator records classified notes, never audio. Choose 60-180 BPM, 1-8 bars, curated lyrics and Echo/Clapback/Harmony; edit the sixteenth grid, then explicitly save one of eight local slots. Voice notes must last at least 160 ms. Checked TB1 codes share musical data offline. Practice and successive two-human challenges are unranked.\n"
			+ "Daily Derby changes at local midnight. Its frozen date seeds the ground, section, modifier and real halftime rival, ignoring unlocks. Best Noise and streaks stay local; shares include the date and assist badge. Best Moments keeps twelve bounded numeric 3D clips. Seeking never records, scores, pays or changes progress.\n"
			+ "Microphone consent is explicit. No monitoring, saved audio or required headset. Calibrate room, claps, comfortable speaking/carrying, relative pitch and speaker bleed. Capture stops on pause, rival turns, handoffs, results and exit. Denied or dead input always leaves Buttons available.\n"
			+ "Use a comfortable voice; stop if it strains. After about fifteen minutes, take water, a rest, or a few rounds on Buttons. Any sound, wider windows, slower tempo, Quiet Mode, Static lane and gentle/off rivals are available in Settings.",
		"instructions_player_one_controls": "F/J Beat, Space Shout, A/S/D LOW/MID/HIGH, Q Fury, E power. Rebind in Controls. Touch supports independent fingers. Gamepad A/X or bumpers Beat, RT Shout, LT + vertical stick Sing, Y Fury, B power. Escape / Start / Pause opens the shared menu.",
		"instructions_player_two_controls": "The same keys, a passed controller, or Controller 2. Never share an active microphone turn.",
		"instructions_demo_prompt": "NINETY MINUTES. NO SILENCE.",
		"store_intro": "Completed performances pay Tokens once per match or hot-seat set. Hats, jackets, megaphones, drums, scarves and fabric are cosmetic. Practice/build-only rounds pay no Tokens.",
		"gallery_intro": "The real original tifos, curva sections, fictional rivals, chaos cast, grounds and the bucket. No real club models, melodies or chants.",
	}
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/tifo_beato/assets/game-icon.png"
	theme.accent = Options.BUCKET
	theme.light = Options.CREAM
	theme.plaque_color = Options.NAVY
	theme.background_top = Color("23334b")
	theme.background_bottom = Color("101c2e")
	theme.style_share_card = true
	game.theme = theme
	game.credits = [
		{"heading": "Tifo Beato", "lines": ["Game design and development: DeskCanSaw Games",
			"Tifo Beato - Ninety minutes. No silence."]},
		{"heading": "Original art and audio", "lines": [
			"Procedural toy stadiums, capos, crowd, fictional rivals and comic props.",
			"24 original procedural chants and synthesized voices, drums and cues.",
			"Caption-only commentator. No raw microphone audio is stored.",
			"Curated words and cartoon smoke, never real-club banners or flares."]},
		{"heading": "Framework and release review", "lines": [
			"Shared DeskCanSaw Godot framework, menus, accessibility and save management.",
			"Pitch detection uses an adapted MPM/NSDF mathematical approach.",
			"Original chant melodies and fictional rival lines require the owner's release review.",
			"Hardware microphone, speaker, touch and platform-permission certification is separate."]},
	]
	return game

static func refresh_gallery(game: GameManifest, progress: Dictionary) -> void:
	game.gallery_exhibits = Options.GALLERY_EXHIBITS.duplicate(true)
	for entry in game.gallery_exhibits:
		var model := str(entry["model"])
		if model == "rival":
			var rival: Dictionary = War.RIVALS[int(entry["rival"])]
			entry["description"] = "%s / %s. %s; ordinary acoustic frames, never a scoring shortcut." % [
				rival["club"], rival["group"], rival["style"]]
			entry["available"] = str(rival["id"]) in progress.get("rivals", [])
			entry["locked_description"] = "Win the complete sing-off against " + str(rival["title"]) + "."
		elif model == "tifo" and int(entry["tier"]) in [1, 3, 4]:
			entry["available"] = "tifo_%d" % int(entry["tier"]) in progress.get("exhibits", [])
			entry["locked_description"] = "Reveal this tifo in a completed match."
		if model == "tifo":
			entry["description"] = ["", "Club-coloured scarves lift together across the curva.",
				"Each card samples a real pixel of your latest saved banner, mishaps included.",
				"The latest saved banner unrolls across the terrace.",
				"Soft coloured cartoon clouds. No flares, rapid flashes or dangerous pyro.",
				"An original inflatable owl watches over the whole stand."][int(entry["tier"])]
		elif model in ["ground", "group"]:
			var option: Dictionary = Options.GROUNDS[int(entry["ground"])] if model == "ground" \
				else Options.GROUPS[int(entry["pool"])]
			if option.has("requires_achievement"):
				entry["requires_achievement"] = option["requires_achievement"]
				entry["locked_description"] = str(option.get("locked_description", "Unlock this curva section."))
			entry["description"] = option["description"]
		elif model not in ["rival", "bucket"]:
			entry["description"] = {"seagull": "Eight Perfects recover the actual stolen banner.",
				"drum_skin": "A visibly split bucket. Keep the visual beat; scored points double on success.",
				"power_cut": "The floodlights dim slowly. Sing the visible Holds until the power returns.",
				"beach_balls": "Harmless toy balls drift across the stand; real hits pop them.",
				"rain": "Finish a comfortable sung Hold and the umbrella section rises.",
				"kevin": "Kevin brought his original pink kazoo. Keep the Rests to hear him finish.",
				"steward": "Look away, step; look back, freeze. Confiscated items are always politely returned."
			}[model]
