# Tifo Beato — Game Design Document

> V1 rules and implementation reference. Milestones 0–10 are implemented;
> milestone 11's hardware, signing and owner-review gates remain open.
> Numbers marked *(tune)* are starting points, not contracts. Read the
> repository's `AGENTS.md` first — its framework/game boundary takes precedence.
> Every club, league, ground, chant and crest in this game is **invented**.
> Original synthesized melodies and fictional copy still require the owner's
> release review (§17). Automated tests are not physical-device certification.

| | |
| --- | --- |
| Game ID | `tifo_beato` |
| Title | Tifo Beato — Ninety minutes. No silence. (approved) |
| Folder | `godot-base/games/tifo_beato/` (registered submodule, `jraleman/tifo_beato`) |
| Control style | `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` |
| Round rules | Game-owned (`uses_shell_round_rules = false`) |
| Players | Solo vs the match and CPU rival capos; two-human hot seat (`max_local_players = 2`, turns) |
| Menu order | `12` (after Capitan's Walk) |
| Feature tag | `tifo_beato` |
| Input reference | `games/dead_metal_jam/input/` (microphone, MPM pitch detection, latency calibration); `games/sailor_man/DESIGN.md` §4 (voice frames, bleed, voice health) |
| Look-and-feel reference | `games/chicken_pit/`, `games/cube_trials/` (toy-like 3D in a `SubViewport` under the 2D shell) |
| Renderer | `gl_compatibility` — unchanged |

---

## 1. Concept

You are nobody. You have a bucket, two wooden spoons and a voice. Eleven
people stand on the terrace at Bucketwick Rec, and three of them are the
groundsman's family.

**Tifo Beato** is a loud, over-the-top arcade rhythm game about rising from
that bucket to the fence of the most feared, and most ridiculous, ultras group
in the Grand Continental League. The microphone is an optional controller. You sing,
shout, clap and bang out rhythms, and the curva answers. Lead it well and a
whole stand moves as one giant wave of sound. Lead it badly and it stumbles
into an awkward, mumbling mess. Keyboard, gamepad and touch play the same
charts for anyone who can't, or won't, use a microphone. Buttons are the default.

The tone is cartoonish and chaotic: a love letter to terrace culture, with its
devotion, its rivalries, its choreography and the absurd lengths fans go to for
ninety minutes of nonstop noise. Everything is exaggerated. Nothing is
realistic. The crowd takes it all deadly seriously.

### Locked pillars

1. **The chant must not die.** Leading the curva means *never stopping*. The
   never-stop meter (§3.4) is the heartbeat of every match, and silence is the
   only real enemy.
2. **Every sound is an input, and every input is fair.** Claps, shouts, sung
   lines and a pen on a desk all reach the same judge as one frame stream
   (§4.1). Buttons are a first-class instrument, not an apology. The same chart
   played perfectly on keys and perfectly by voice must score within 5 %.
3. **Rhythm first, then volume, then pitch.** Timing decides most of the
   score. Volume is judged **against your own soundcheck** and capped, so
   screaming past it earns nothing (§4.6). Pitch is judged as a **relative
   contour** (low / mid / high for *your* voice), never as absolute notes.
4. **The curva is the feedback.** Sync, stumble, mosaics, banners and the match
   itself are how the game tells you how you're doing. A player who never
   reads a number should still know exactly how well they led.
5. **Rivalry is theatre, never violence.** Ultras culture without the ugly
   parts: no fights, no realistic pyrotechnics, no discriminatory chants, no
   real clubs or groups. Rivals insult your haircut, your drum and your
   scarf-washing habits. Stewards are comically over-vigilant, never villains
   to be hurt. Smoke is cartoon puffs.
6. **Same studio look as Chicken Pit.** A real, toy-like 3D stand and pitch in
   an isolated viewport, driven by a node-free model, under the shared HUD.

### Setting — the Grand Continental League

An invented league that borrows freely from terraces all over Europe. The
vocabulary is a glorious mashup: the **capo** on the fence and the
**curva** from Italy, the **choreo** and the **Vorsänger** from the German
terraces, the **Kop** from England, the arm-in-arm **Bounce** with the whole
stand's back to the pitch, Balkan brass, Iberian drums. No region is mocked and no
accent is played for laughs. Every club is fictional: Bucketwick Rovers (the
player's club, renamed by the player, §8.4), Dynamo Drizzle, Sporting
Sardinas, Olympique Moustache, Lokomotiv Lasagne, Inter Nebula, Borussia
Bratwurst, Athletic Gnocchi.

### Look and tone

A tabletop stadium of painted wood and felt. Fans are chunky toy figures with
round heads, huge scarves and enormous eyebrows. The stand bounces in unison
when you are good and goes out of phase like a bad marching band when you are
not. The **commentator** (§9.5) is equal parts football analyst and tragic
poet, and treats a perfectly timed clap like the fall of an empire.

### Story (for the intro cards and `instructions_rules`)

Five short cards, using the same intro shape as the other games:

1. Bucketwick Rec. Attendance: eleven. Three of them are the groundsman's
   family.
2. You find a bucket. You find two spoons. You find your *purpose*.
3. One day you'll lead the Curva Nord at the Continental Final, with the whole
   city singing.
4. Today, you lead Kevin. Kevin brought a kazoo.
5. Get on the fence. Don't let the chant die. — **Forza!**

---

## 2. Core loop

```
Title ─► Play ─► Career map (ground · match) or Quick match / Chant war / Hot seat
     ─► Mode select (group on the plinth · ground) ─► Instructions
     ─► Railway/lobby; optional explicit-start Soundcheck
     ─► (between career matches) Tifo workshop: design ─► build race
     ─► (some matches) Steward check: sneak the flag / drum in the coat
     ─► MATCH: walk-in chant ─► kick-off TIFO REVEAL
            ─► first half: call ─► response ─► call ─► … (never stop)
               combos ─► power-ups ─► rival disruptions ─► chaos event
               crowd energy drives the toy match on the pitch
            ─► half-time: chant war (rival capo) or chaos
            ─► second half ─► final whistle
        ─► results (Noise, stars, best combo, match score, commentator's verdict)
     ─► Tokens payout ─► career progress ─► Share card / Store / Gallery
```

Normal charts have a 20 s walk-in, two roughly 2-minute halves and a 32 s
half-time or a complete five-exchange war. Whole phrases finish; slower
chants, wars and hot-seat count-ins extend that duration. Every 15 minutes
of actual microphone play is a natural place to rest the voice (§4.6).

---

## 3. Capo mode — the chant

### 3.1 Call and response

The player stands on the fence with a megaphone, facing the curva. Every chant
is a loop of **phrases**, and every phrase has two halves:

| Half | Who | Judged? | What the game plays |
| --- | --- | --- | --- |
| **Call** | The capo (you) | Yes | The **guide drum** only — a low thump, below the judged band (§4.4) — and the visual beat lane |
| **Response** | The curva | No | The crowd answers your call. Its sync, volume and size are the *result* of your call |

The response is your call **played back by the crowd**. Hit the call
perfectly and the response comes back as one giant, tight wave of sound.
Sloppy timing makes the response stumble: voices out of phase, a mumble, one
fan still going after everyone else has stopped. The crowd plays back what
you did, not what the chart said, so the player can always *hear* their
mistake.

Some phrases are **sustains** (§3.4), where the capo and the curva sing
together and there is no response half. A good chant mixes the two.

### 3.2 Notes

A chart's call is a line of **notes** on a beat grid. The beat lane scrolls
toward the capo's megaphone. Every note shows an **icon, a shape and a
label**, never colour alone:

| Note | Icon | Accepts *(tune)* | Typical use |
| --- | --- | --- | --- |
| **Beat** | Fist | Any sharp onset: clap, stamp, drum, a shouted syllable | The backbone of every chant |
| **Shout** | Megaphone | An onset with ≥ 150 ms of loud sustain, voiced or not | "HEY!", "FOR-ZA!" |
| **Sing** | Note on one of 3 rungs | A voiced sustain whose pitch lands in the **low / mid / high** band of *your* calibrated voice | Anthems, the Old Guard's slow songs |
| **Hold** | Long bar | Keep a Shout or Sing going for the bar's length | The end of a line |
| **Rest** | Hand, palm out | Silence. A sound here is a mistake | Dramatic pauses, the hush before the Bounce |

A Beat note accepts a shouted syllable on purpose. You can lead a whole
chant with your voice alone, or with your hands alone, except for Sing
notes. The **Any sound** assist (§3.8) lets every note accept any sound.

### 3.3 Judgement

Timing windows apply after latency compensation (§4.3):

| Grade | Window *(tune)* | Points | Never-stop | Crowd |
| --- | --- | --- | --- | --- |
| **Perfect** | ± 45 ms | 100 | +6 | One fan more joins in sync |
| **Great** | ± 90 ms | 70 | +4 | Holds sync |
| **Good** | ± 140 ms | 40 | +2 | A few fans drift |
| **Miss** | — | 0 | 0 | Fans stumble; the combo breaks |

Volume and pitch **scale** a hit that already landed in time. They never turn
a miss into a hit:

- **Volume.** Each hit's level against the player's calibrated *carry* level
  gives ×0.8 at speaking level to ×1.2 at carry level, capped at ×1.2 *(tune)*.
  In Quiet Mode (§4.6) the scale is pinned to carry-equivalent ×1.2 so the
  assist never penalizes the same performance.
- **Pitch** (Sing notes only). In the right band: ×1.0. One band off: the
  hit counts, ×0.6, and the crowd sings a little sour. Unvoiced: a miss.

### 3.4 The never-stop meter

The **Chant Life** meter, 0–100, drawn as a scarf being knitted with a number
beside it. It starts at 70.

- It drains **only during call halves and sustains** *(tune: 20/s)*, and only
  after **1.5 s** of the capo producing nothing judged (the grace). Response
  halves are safe. You are allowed to breathe.
- Every judged hit refills it (§3.3). A Rest note held silent refills it too.
  Silence on purpose is music.
- At **25** the rivals start a mocking chant, captioned and drawn in the away
  end. At **10** the curva starts to mumble and look at its shoes.
- At **0 the chant dies.** The crowd trails off into an awkward hush. The
  rivals sing a cruel lullaby. **Morale** drops by 30 *(tune)*. To get going
  again you must **rally**: four strong Beats on the guide drum. Then the chant
  restarts from the top of its loop, and Chant Life starts again at 50.

**Morale**, 0–100, is the match's lives pool. It starts at 100, and only a
dead chant lowers it. At 0 the curva **walks out to the pie stand**, which
ends the match early with 0 stars. Then a commentator lament plays, and a
results panel offers one-key restart. The **Chant never dies** assist removes
the walkout. Morale still drops, so the result still tells the truth.

### 3.5 Combos

Consecutive Great-or-better hits build a combo. A Good keeps it but doesn't
add to it. A Miss, or any sound on a Rest, breaks it:

| Hits | Tier | Multiplier | The curva does |
| --- | --- | --- | --- |
| 8 | **Bucket Banger** | ×1.5 | Scarves come out |
| 16 | **Terrace Thunder** | ×2 | The stand bounces as one |
| 32 | **Scarf Hurricane** | ×3 | Scarves spin overhead |
| 64 | **Full Curva Meltdown** | ×4 | The whole stand goes berserk; the pitch shakes (intense effects only) |

Each tier is announced with a caption, a badge and a sting. Combo points are
banked on every hit, so a break never erases them.

### 3.6 Curva Fury — the super move

The **Fury** meter, drawn as a megaphone filling with fire *(cartoon)*,
charges from:

- **Long, strong shouts.** Each Shout or Hold adds charge for its held time
  multiplied by its level against *carry*, **capped at carry** (§4.6).
- **Perfect hits** of any kind, so a clap-only or keys-only player charges it
  at the same rate as a shouter. The tests pin that the ideal clap path and
  the ideal shout path fill Fury within 10 % *(tune)* of each other.

When it is full, the capo unleashes it with **one long shout of 1.5 s or
more** in any call half, or the Fury button. **Curva Fury** lasts 8 s
*(tune)*. Every hit counts as Perfect for the crowd (not for the score, which
gets ×2), Chant Life is frozen full, the crowd energy maxes out (§5) and the
stand erupts. One Fury per half.

### 3.7 Power-ups

Earned by combo milestones and dropped by some chaos events (§6.3). One slot.
The power-up is activated by **three sharp shouts in an empty bar**
("HEY! HEY! HEY!") or by the Power button:

| Power-up | Effect *(tune)* |
| --- | --- |
| **Mega-megaphone** | 12 s: timing windows widen by 30 % and the response is twice as loud and twice as big |
| **Drum solo** | One free 4-bar break: any Beat on the grid scores double, and the drum line is yours |
| **Scarf tornado** | Clears the current rival disruption and protects you from the next one for 15 s |
| **Ref Distraction Chant** | The next rival attack on the pitch stalls while the referee turns to stare at the curva, then blushes |

### 3.8 Assists

| Assist | What it does |
| --- | --- |
| **Any sound** | Every note accepts any onset or sustain. Pitch and note type are ignored |
| **Wide windows** | Normal / Wide (×1.5) / Widest (×2) |
| **Chant speed** | 100 / 85 / 70 % tempo |
| **Chant never dies** | No walkout at 0 morale |
| **Gentle rivals** | Rival disruptions: Full / Gentle / Off (§6.2) |
| **Quiet Mode** | Volume is normalized to speaking level and never scales a score (§4.6) |

Assisted matches carry an **assist badge** on the results and in the records.
They earn every achievement and Tokens normally. Assists must never make the
game *worse*. `model_test.gd` pins that every assist scores a given
performance at least as high as it scores without that assist.

---

## 4. Sound input

### 4.1 Architecture — one stream, many sources

```
MicSoundSource ──┐
KeySoundSource ──┤
PadSoundSource ──┼─► SoundFrame stream ─► SoundClassifier ─► SoundEvents ─► ChantJudge
TouchSoundSource ┘    (100 Hz)              (onset · shout ·     (t, kind,      (pure,
                      ↑ also: CPU rival capos, test fixtures       sing band,     node-free)
                                                                   level, dur)
```

`SoundFrame` is `{t: float, level: float, flux: float, voiced: bool, cents:
float, clarity: float}`. `level` is relative to the player's calibrated
*carry* level. `flux` is high-band spectral flux, which is what finds onsets.
`cents` is relative to the singer's calibrated **centre**. Every source emits
frames at **100 Hz** *(tune)*. The classifier never knows where frames came
from. That is how buttons, the CPU, the Chant Creator (§11.3) and the tests
become first-class: each produces the same kind of stream as a voice.

Copy and adapt Dead Metal Jam's microphone stack into this folder. **Do not
import it.** There must be no game-to-game dependency:

| Dead Metal Jam | Tifo Beato | Change |
| --- | --- | --- |
| `input/mic_capture.gd` | `sound/mic_capture.gd` | Same runtime-created, silenced capture bus (`TifoCapture`), same dead-mic silence test; add a **high-pass at ~250 Hz** *(tune)* on the onset path only (§4.4) |
| `input/pitch_detector.gd` (MPM/NSDF) | `sound/pitch_detector.gd` | Voice range ~75–900 Hz; continuous cents, not quantised notes; onset logic moved out to the classifier |
| `input/pitch_analysis.gd` | `sound/sound_frame.gd` | Becomes the 100 Hz frame |
| `input/latency_calibration.gd` | `sound/latency_calibration.gd` | Same statistics; the player **claps**, the click is a low thump (§4.3) |
| `input/metronome_click.gd` | `sound/guide_drum.gd` | Pre-rendered stream, but a **low, band-limited thump**, not noise |
| Numeric diagnostics | `tools/sound_spike.gd` | Explicit-start counters, measured latency and classification; no PCM files or monitoring |

`audio/driver/enable_input=true` is already the project default. Keep it on
for the `tifo_beato` feature tag.

### 4.2 The classifier — `sound/sound_classifier.gd`

`RefCounted`, node-free and autoload-free. Frames in, `SoundEvent`s out:

| Event | Rule *(tune)* |
| --- | --- |
| **Onset** | High-band flux > `ONSET_FLUX_RATIO` × its trailing median, and level > the noise floor + 12 dB. Refractory 60 ms, so a fast drum roll still reads as separate hits |
| **Clap / bang** | An onset whose level falls 15 dB within 120 ms |
| **Shout** | An onset followed by ≥ 150 ms above 50 % of *carry*, voiced or not |
| **Sing** | ≥ 150 ms voiced with clarity ≥ 0.8. Its band is the median cents over the note: low < −250, mid −250…+250, high > +250, relative to centre |
| **Silence** | Level under the floor + 6 dB for ≥ 250 ms |

Every threshold is a constant at the top of the file, so the tests and the
tunables can quote them. Shouts are often unvoiced, so pitch detection is
never needed to detect one. That keeps the noisiest input the most reliable.

### 4.3 Soundcheck — calibration

A short opt-in overlay reached from the lobby or Soundcheck on resume in
Settings → Game. Buttons need no microphone calibration. Merely opening the
overlay requests nothing; Start is the consent/gesture boundary:

1. **Room** — 2 s of silence. Measures the noise floor. Exact digital silence
   means a dead or denied microphone. Fail this step explicitly, close capture
   and offer Buttons rather than reporting a completed measurement. No samples
   receive a separate ten-second permission/no-signal grace.
2. **Clap** — "Clap along to the big drum." Eight beats at 100 BPM, matched
   by `latency_calibration.gd`. This gives the round-trip latency. The drum is a
   low thump under the onset band, so the mic doesn't hear it as a clap.
3. **Speak** — "Say the name of your club." Speaking level.
4. **Shout** — "Now the way you'd say it with 30,000 people behind you."
   *Carry* level. The copy says "carry", not "louder". The level is clamped to
   what this step measured, so nobody has to scream to max it later.
5. **Sing** — "Hold a comfortable *ooo*." That gives the centre, 0 cents.
   "Now a little higher… and a little lower." That checks the three bands fit
   the player's range, and narrows them if they don't.
6. **Speakers check** — the game plays one bar of crowd response and measures
   how much of it the mic hears (§4.4). It suggests **headphones** if the bleed
   is high, and never requires them.

A profile is `{latency_ms, noise_floor, speak_level, carry_level,
centre_hz, band_width_cents, bleed_level, headphones, calibrated}`. Separate
microphone profiles ("P1"/"P2") and Buttons profiles ("P1_buttons"/"P2_buttons")
are stored in `user://tifo_beato_voice.cfg`. That is
calibration, so it is deliberately **not** a declared `save_files` entry
(`AGENTS.md`: saves are progress only). The Buttons path skips steps 1–6
apart from an optional tap-along latency check. The global timing trim is
added to each seat's measured latency, then capped to −100…400 ms; it does not
replace a calibrated profile. The current Headphones option overrides old
profile flags.

### 4.4 Bleed — the game is louder than you

This is the riskiest problem in the game. A rhythm game that plays a roaring
crowd and rival air horns through the same speakers the mic can hear must not
score its own audio. There are four defences, in order:

1. **Turn gating.** The judge only consumes events inside call halves and
   sustains. The response half is where the game is loud.
2. **Spectral split.** During a call half, the only sound the game makes on a
   judged beat is the **guide drum**, band-limited below ~180 Hz *(tune)*. The
   onset detector is high-passed above ~250 Hz. Claps, stamps and shouts have
   plenty of energy up there, and the guide drum has almost none.
3. **Known-output gate.** The game knows exactly when it emits every
   transient: rival air horns, off-key trumpets and rival drums.
   A mic onset within ± 40 ms *(tune)* of a known emission is discarded unless
   its level beats the emission's measured bleed (§4.3 step 6) by 6 dB.
   **Rival disruptions only ever land off the grid** (§6.2). A correct hit is
   never on a disruption's beat. Emission registration and pruning use the
   same latency-compensated clock as input, including −100/+400 ms profiles.
4. **Never monitor the mic.** The capture bus stays at −80 dB, as in Dead Metal
   Jam. The commentator and crowd duck during call halves.

The **Headphones** toggle relaxes the known-output gate; it does not remove
the low-guide/response discipline. No crowd recording plays under a call.

`sound_test.gd` and `model_test.gd` check synthesized bleed, real-input
precedence, compensated emissions and whole disruption intervals. Physical
speaker verification remains open: target **under one false onset per
minute** of a match's own audio on laptop speakers. Use numeric diagnostics;
no room recording is required or saved by the game.

### 4.5 Buttons, keys and touch

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| **Beat** (two keys for fast rolls) | F / J | A or X / bumpers | Drum pad (left or right half) |
| **Shout** (hold) | Space | Right trigger | Megaphone pad, hold |
| **Sing low / mid / high** (hold) | A / S / D | Left trigger + left stick down / centre / up | The three-rung sing strip, hold a rung |
| **Fury** | Q | Y | Fury button (lit only when full) |
| **Power-up** | E | B | Power-up button |
| Pause | Escape (shell) | Start | Pause icon |

`KeySoundSource` turns those inputs into `SoundFrame`s with a **virtual
profile**: carry level 1.0, centre 0, band ±500 cents. A Beat key is a 40 ms
burst with a sharp decay, and a Shout key is a sustained loud unvoiced frame.
While Shout or Sing is held, the player hears **the capo's synthesized voice**
(§10.6) on the beat. A button chant still sounds like a chant.

Because the same classifier and judge score both paths, keys cannot be easier
or harder by accident (pillar 2). Touch uses **independent multitouch
contacts**, one per pad, as Cube Trials' `drive_controls.gd` does.

### 4.6 Voice health and Quiet Mode

The pitch of this game is shouting, which makes this section non-negotiable:

- **Loudness is relative and capped.** It is judged against *your* carry level
  from soundcheck. Anything above carry earns nothing extra (§3.3, §3.6).
- **Claps and keys charge everything a shout does.** Pillar 2 and the Fury
  test (§3.6) hold that line.
- **Quiet Mode** (tunable): volume never scales a score, and every threshold
  is normalized to speaking level. Hummed, spoken and whispered chants score
  normally at a fixed carry-equivalent ×1.2. It is for night play, shared
  rooms or a tired voice.
- After **15 minutes of mic play in a session** *(tune)*, the career map suggests a
  sip of water and offers Buttons or Quiet Mode for the next match. It never
  forces either.
- Copy never says "louder" or "scream". It says "carry", "lead", "hold" and
  "keep it going".
- **No achievement rewards loudness or session length.**

### 4.7 Platforms

| Platform | Microphone | Notes |
| --- | --- | --- |
| Desktop | Native | Primary target. Device picker in soundcheck (`AudioServer.input_device`) |
| Mobile | Native after runtime permission | Record permission in the export preset. Single-player only (shell rule). Touch fully supported. Phone speakers sit next to the mic, so suggest Headphones or Buttons after the speakers check |
| Web | HTTPS + permission + a user gesture | Soundcheck is the gesture gate. Detector on a main-thread budget when threads are unavailable, as Dead Metal Jam plans |

No gameplay script may branch on the platform. Differences are resolved where
sources are built, as in Dead Metal Jam §4.7.

---

## 5. The match — crowd energy powers the pitch

### 5.1 Crowd energy

**Energy**, 0–100, is the curva's collective power. It is a smoothed function
of the last 8 bars: hit accuracy, sync (the share of Perfect and Great hits),
Chant Life, combo tier and Fury. It is drawn as a flag climbing a pole, with a
number. It drives everything the crowd and the match do.

### 5.2 The toy match — `match/match_sim.gd`

A real, tiny football match plays out on the toy pitch below the stand. It is
node-free, seeded per match and steps at 10 Hz. The model is a possession
random walk across **five zones** (own box → their box). Energy biases it:

| Energy effect | Rule *(tune)* |
| --- | --- |
| **Players glow with flames** (cartoon) | Energy ≥ 70: home players' pass success +15 %. Their outline flames, and an icon shows it |
| **The ball gets heavier for the opponent** | Opponent pass success −(energy − 50) / 5 % above 50. The ball visibly sags and thuds |
| **The rival goalkeeper trembles** | Save chance −energy / 4 %. His knees knock, and the trembling is captioned |
| **Home keeper inspired** | Energy ≥ 80: save chance +10 % |
| **Low energy** | Below 30 the home team looks up at the stand, confused. Rival attacks are 20 % more frequent |

**The curva can't score, but it can make the keeper cry.** The same seed and
the same energy curve always produce the same match. A great performance makes
a win very likely, but never certain. That is football. **Career progress
depends on stars, never on the match result** (§8.2). A win pays a bonus and
plays the better story card.

A **goal** queues a 4-bar **goal moment** after the current line. It authors
16 future Beat opportunities, supersedes the displaced notes without adding
misses, skips handoff phases and preserves the match's final whistle.
A home goal is a
free-form celebration where every Beat on the grid scores, the stand erupts
and a tifo can fire. An away goal is a **defiance** phrase: lead the curva
back to its feet in 4 bars for a big Chant Life refill and a morale point, or
the rivals' end celebrates.

### 5.3 Scoring

```
match Noise = Σ(hit points × volume scale × pitch scale × combo multiplier)
            + tifo reveals + Fury bonus + chant-war result + goal moments
final       = match Noise × crowd-size multiplier (×1.0 at the Rec → ×1.5 at the Final)
```

**Noise** is the headline number and the record key. It pays Tokens (§10.2).
**Stars** (1–5) come from accuracy and from never letting the chant die:

| Stars | Rule *(tune)* |
| --- | --- |
| ★ | Finished the match (no walkout) |
| ★★ | ≥ 60 % accuracy |
| ★★★ | ≥ 75 % accuracy and the chant never died |
| ★★★★ | ≥ 85 % and a tifo reveal |
| ★★★★★ | ≥ 93 %, the chant never died and Full Curva Meltdown reached |

The results panel shows Noise, stars, accuracy, best combo **by name**, the
match score, the tifos revealed and the **commentator's verdict**, a single
tragic-poet line chosen from the match.

---

## 6. Ultras-style chaos

### 6.1 Tifo reveals

A **Perfect streak** of 12 or more in a call half *(tune)* unlocks the next
**tifo** in the match's choreography. It reveals at the next response half, in
place of the normal response, as a 6–10 s set piece with its own bonus. Each
one is more ridiculous than the last:

| Tier | Tifo | What happens |
| --- | --- | --- |
| 1 | **Scarf wall** | Every fan holds a scarf up tight. Their colours make your club's stripes |
| 2 | **Card mosaic** | Coloured cards make the **player's own banner** (§6.4) across the stand. Every fan holds one pixel of it |
| 3 | **The 50-metre banner** | A giant banner rolls down the stand from the top. Its face is the workshop banner |
| 4 | **Cartoon smoke bursts** | Puffs of coloured cartoon smoke in club colours spell out the group's initials. Clearly cartoon: soft, round and slow |
| 5 | **The Unholy Choreo** | All of the above at once, plus a 20 m inflatable of the club mascot rising from the stand |

The **card mosaic** is the technical showpiece. The view samples the banner
texture once per fan seat and sets that fan's card colour. It is one MultiMesh,
one draw call (§12.2). A banner built badly in the workshop shows its mishaps
here (§6.4). That is part of the comedy, not a failure.

With **Reduced motion** the reveal is a cross-fade to the finished tifo. With
**Intense effects off** the smoke is slower and has no burst flash.

### 6.2 Rival disruptions

The rival end tries to throw off your tempo:

| Disruption | Effect | Telegraph |
| --- | --- | --- |
| **Air horn** | A loud, **off-grid** blast mid-call | The rival with the horn stands up and inhales: an icon and a caption, 1 bar ahead |
| **Off-key trumpet** | A wandering, sour melody under your Sing notes | A trumpet appears in the away end |
| **Rival drums** | A drum line **at a slightly different tempo** for 4 bars, trying to drag you | Their drummer twirls a stick, and a "rival tempo" ghost lane appears beside yours |
| **Giant inflatable** | Covers a third of your beat lane for 2 bars. Your hits still count | It inflates slowly, squeaking |

Every disruption is **telegraphed one bar ahead** with a caption, an icon and a
sound, and **always lands off the judged grid** (§4.4). **Gentle rivals**
halves their frequency and loudness, and **Off** removes them. The full
transient must fit outside onset, Hold and Rest windows, including all
assists. Shared margins live in `match_chart.gd`: 0.75 s before a note,
0.5 s after, 0.25 s minimum transient. Longer original patterns play only
inside a safe response tail. A late render batch that misses its safe gap
keeps the caption/visual event but plays no unsafe sound. `model_test.gd`
and `scene_test.gd` pin both the authored intervals and runtime safety.

### 6.3 Chaos events

A normal match draws two chaos events from the ground's pool; Chaos Kids get
three, and the Final runs all six. Each
one changes the rules for a stretch and has a way to **win it**:

| Event | What happens | Win it |
| --- | --- | --- |
| **A seagull steals your banner** | The next tifo is gone. The gull circles the stadium with it | A 4-bar **chase chant**: every Perfect drives the gull lower, and 8 Perfects bring the banner back down |
| **The drum skin splits** | The guide drum stops for 8 bars. Only the visual lane remains | Keep tempo from memory. Completing it pays double, and the drummer is crowned |
| **The power cuts out** | Floodlights out (a dim, not a flash). Backing and guide drum stop. The stadium must carry the song **a cappella** | The judge widens by 20 %, Sing notes dominate, and the response is pure voices. The lights come back on a perfect line |
| **Beach-ball invasion** | Beach balls bounce through the beat lane and cover notes | The notes are still there. Hits pop the balls |
| **Rain** | Sheets of rain. Cards get soggy, so the next mosaic is blurrier | Hold a full sustain and the umbrellas go up |
| **Kevin's kazoo** | Kevin (from the Rec) shows up at every level and kazoos off-grid | Ignore him (Rest notes) and he gives up |

Events that drop **power-ups** (§3.7): winning the seagull chase and the power
cut each drop one.

### 6.4 Tifo workshop

Between career matches, the group meets in a lock-up garage to make the next
banner. It has two phases.

**Design** (untimed). A grid-based banner editor:

| Element | Choices *(tune)* | Costs from the materials budget |
| --- | --- | --- |
| Fabric | Bedsheet, tarpaulin, silk (store-unlocked) | Metres |
| Background | Club colours, stripes, halves, checks, sunburst | Paint |
| Crest | The club crest (§8.4), or a stencil (skull-free cartoon set: lion, owl, pigeon, mascot, crown, rocket) | Paint |
| Text | Up to 14 characters from a fixed, filtered word list plus the club and group names | Paint per letter |
| Extras | Fringe, glitter, a tiny LED string, poles | Sticks / glitter / batteries |

The **materials budget** grows with your ground (§8.1). Going over it is
allowed, but the build race (below) then runs short of paint, which means
more mishaps. The editor shows the budget as numbers and icons.

**Build** (timed, 45–60 s *(tune)*). A rhythm race against the kickoff clock
with the same input as the match: Beats are brush strokes, Shouts unroll
fabric and Sings stitch. Every Miss and every overspent material rolls a
**mishap** from a seeded table:

- an **upside-down letter**
- the banner **unfurls backwards** (mirror-written)
- a letter goes **missing** ("BUCKETWICK" becomes "BUCKETWIC")
- a **paw print** — the club cat walked across it
- the crest gets **googly eyes**

The finished banner's quality (0–100 %) scales its tifo bonus. Mishaps don't
reduce the bonus. They add a **"the crowd loves it anyway"** laugh bonus and a
commentator line. The banner is saved (§10.1) and appears in its match's tifos
and on the share card.

The word list is closed: players can't type free text onto a banner. That
keeps banners safe to show on share cards without moderation (§17).

### 6.5 Chant wars

Rival ultras challenge you to a **sing-off duel**. It is the half-time show
of some career matches and its own Quick-play mode. It is turn-based call
and answer:

```
dramatic stare-down (3 s, skippable) ─► rival capo calls a 2-bar pattern
     ─► you ECHO it (judged against their call)
     ─► you CALL your own 2-bar pattern ─► rival echoes, imperfectly
     ─► escalate: tempo +6 BPM per exchange, patterns get denser
     ─► 5 exchanges, or someone breaks ─► verdict
```

The mic is gated off during the rival's turns (§4.4). Your **echo** is judged
on timing like any call. Your own **call** is free-form: the judge scores it
for its density, its syncopation and how well you held tempo, and the rival
copies it with an accuracy set by its personality. A comic **insult** pops up
between exchanges, captioned and also voiced if voice-over exists (§17):

- *"Your drum is a biscuit tin and everyone knows it."*
- *"We've seen more noise from a library on a Sunday."*
- *"Nice scarf. Did your nan knit it? Tell her it's lovely."*

Insults target **drums, scarves, haircuts, singing and tea**. They never
target people's bodies, identities, places or real groups. The bank is
reviewed before it ships (§17). Human turns have two guide beats before the
call and a 0.6 s capture tail. Every echo has the same 700-point normalized
budget regardless of call density. CPU frames catch up before a turn changes;
both Twin halves actually perform their own part.

**Rival capos** are CPU opponents built from the same `SoundFrame` stream as a
player (§4.1):

| Rival | Group | Club | Style |
| --- | --- | --- | --- |
| **Big Sandro** | Brigata Lasagna | Lokomotiv Lasagne | Slow, crushing, perfect timing |
| **Fräulein Paukenschlag** | Nordblock Bratwurst | Borussia Bratwurst | Very fast drum rolls |
| **El Pulpo** | Los Ocho Brazos | Sporting Sardinas | Wild syncopation; drums with eight arms |
| **Madame Moustache** | Les Sourcils | Olympique Moustache | Long Sing lines; sneers between them |
| **The Twins** | Nebula Ultras | Inter Nebula (derby rival) | Two capos who finish each other's calls |

Winning a chant war pays a bonus and a Fury charge for the second half.
Losing costs morale. Either way, the rival gives a dramatic, poetic salute.

### 6.6 Steward evasion

Short mini-games before some matches, 30–45 s each *(tune)*. They use the
same input, and in both of them **silence is the skill**:

- **Sneak the Flag.** Carry a ridiculous 6-metre flag up the concourse. Stewards
  patrol on a rhythm. Every **Beat** moves you forward a step and every **Rest**
  is a freeze. Freeze when a steward turns (their head telegraphs it with a
  creak and a caption) or you're sent back to the turnstile. It is
  red-light/green-light on a beat.
- **Drum in the Coat.** A steward does a pat-down with a long, suspicious
  interview. Answer with **innocent humming** (a steady Sing) to keep them
  calm. The drum in your coat thumps whenever you make a sharp sound, so no
  claps, shouts or keys except the hum. Buttons players hold Sing-mid and
  must not press Beat.

Success smuggles a bonus item in (the flag adds a tifo tier, the drum unlocks
the drum-solo power-up for the match). Failure is gentle: the item is
"confiscated", given back after the match with a polite note, and you play
without it. Stewards are never hurt, tricked into harm or mocked cruelly.
They are just very, *very* thorough.

---

## 7. The curva and its people

### 7.1 Crowd model — `match/crowd_state.gd`

Node-free. The crowd is a list of **sections**, each with a size, a
**sync** (0–1), a **phase scatter** and a **morale offset**:

- A Perfect raises its section's sync and pulls the phase scatter toward 0.
  A Miss scatters it. The response half plays back **with that scatter**:
  each fan's voice and bounce is offset by its seat's phase. A tight crowd
  sounds like one voice, and a scattered one sounds like a pub at closing
  time.
- The view (§12.2) reads only `sync`, `phase_scatter`, `energy` and per-seat
  phases. It never feeds back.
- Crowd size grows **between** matches with career progress (§8.1), and
  **within** a match by up to +20 % as fans join a hot streak.

### 7.2 The capo — `characters`

The capo on the fence is the player's avatar, and stands on the setup plinth
with their group. The **groups** are the playable characters: sections of
your curva you recruit through the career. Each one changes **the chant pool,
the tifo order and a bonus**, never the judge:

| Id | Group | Personality | Chant pool | Bonus | Unlocked by |
| --- | --- | --- | --- | --- | --- |
| `group_bucket_brigade` | **The Bucket Brigade** | You and your mates. Enthusiastic, unpolished | Balanced | none | always |
| `group_old_guard` | **The Old Guard** | Grey scarves, slow anthems, tears | Long Sing and Hold lines, 70–95 BPM | Sing hits ×1.2; Chant Life drains 25 % slower | `tifo_beato_promoted_town` |
| `group_drum_maniacs` | **The Drum Maniacs** | Eleven drummers, no singer | Dense Beat patterns, 130–170 BPM | Beat combos build 25 % faster | `tifo_beato_drum_solo` |
| `group_flag_wizards` | **The Flag Wizards** | Choreo obsessives | Medium tempo, many Rests | Tifos need a 9-streak, not 12; tifo bonus ×1.5 | `tifo_beato_first_mosaic` |
| `group_chaos_kids` | **The Chaos Kids** | Teenagers with a vuvuzela | Wild tempo changes | +1 chaos event per match; power-ups from 6-hit milestones | `tifo_beato_seagull` |

The Bucket Brigade is always available on purpose: the balanced group must
never sit behind a skill wall. Group declarations live in
`tifo_beato_options.gd`; pool-specific configuration in `match_state.gd`
changes data, not the shared classifier or judge.

### 7.3 Your curva — identity

The player's club and group are **theirs** (§8.4): colours, crest, group name,
scarf pattern, banners and chant lyrics. The groups above are sections
*inside* that curva, wearing its colours. This split is owner-approved (§17).

---

## 8. Career and progression

### 8.1 Grounds — the shared level selector

Use the manifest's `levels` with achievement gates, like Cube Trials. Each
ground has an `icon` captured from the real scene by `tools/capture_art.gd`:

| # | Ground | Division | Crowd | Matches | Signature chaos | Unlocked by |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Bucketwick Rec** | Sunday League | 11 | 3 | Kevin's kazoo, rain | always |
| 2 | **Gasworks Lane** | Town League | 400 | 3 | Seagull, beach balls | `tifo_beato_promoted_rec` |
| 3 | **Stadio Comunale Nebbiolo** | Second Division | 6,000 | 4 | Drum skin splits | `tifo_beato_promoted_town` |
| 4 | **The Cathedral** | Grand Continental League | 30,000 | 4, ending in the derby vs Inter Nebula | Power cut | `tifo_beato_promoted_second` |
| 5 | **Continental Final** | The Final | The whole city | 1 | All of them | `tifo_beato_promoted_league` |

**Promotion** needs **9 stars** across a ground's matches *(tune)*. The last
match of each ground has a chant war (§6.5) and a pre-match steward check
(§6.6). The materials budget, the crowd size, the tifo tiers available and the
chaos pool all grow with the ground.

The crowd counts are **narrative**. The view renders a representative number
of fans (§12.2).

### 8.2 The career map

A game-owned screen inside the play flow: a train-line map of the league,
from the Rec to the Final, with each match as a stop. It shows each stop's
stars, the next workshop, the promotion bar and the commentator's line on the
season so far. Stars, not results, unlock the next stop. A lost match with 3
stars still moves you on.

The **Final** is one match, with the whole city on fire (cartoon flames on
the skyline, a sunset palette, every chaos event and all five tifo tiers). It
ends on a credits-style story card.

### 8.3 Quick play

From mode select: **Quick match** (any unlocked ground and group), **Chant
war** (any defeated rival), **Workshop** (design freely), and the hot-seat
modes (§9.3). Quick play pays Tokens and earns achievements, but never
changes career progress.

### 8.4 Identity editor

A game-owned screen reached from the career map:

- **Club name** and **group name**: picked from a curated, combinable word
  list ("Bucketwick" + "Rovers", "Ultras" + "Tumulto"). V1 has no free-text
  option (owner-approved).
- **Club colours**: two from a palette of 16. Pairs too close in luminance
  get a warning, so the scarf wall stays readable.
- **Crest**: a shape, a charge (lion, owl, pigeon, rocket…) and initials.
- **Scarf pattern**: bars, stripes, checks or a slogan from the word list.
- **Chant lyrics**: every chant has a **slot** ("FOR-ZA ___!") filled with a
  word with the right syllable count from the club name, the group name or the
  word list. Rhythm and judging never change. Only the caption and the crowd
  voices' syllable count do.

Identity is player-made content, so it lives in the progress save
(§10.1). The player's colours must **never** override P1/P2 identity
colours (`AGENTS.md`).

---

## 9. Fun extras

### 9.1 Charts — `chart/`

A **chant** is a `ChantChart` resource with a tempo, a time signature, a loop
of phrases and the lyric slots. A **phrase** is a call (notes on a 16th-note
grid), a response style and an optional sustain. A **match chart** is a
seeded sequence of chants drawn from the group's pool, with disruption and
chaos slots. That keeps the content count sane: **24 original chants** in v1, loaded by `chart/chants.gd`.

Every chant is an **original composition**: no real terrace tunes, no pop
songs and no anthems, even ones people think are folk songs *(verify each
melody before it ships — §17)*.

### 9.2 Combo, Fury, power-up and chaos copy

Every combo tier, power-up and chaos event has a caption, an icon and a sting,
owned by `chant_judge.gd`, `fury.gd`, `chaos_events.gd` and the presentation
layer; `model_test.gd` checks the meaningful effects and captions.

### 9.3 Local multiplayer (hot seat)

Turn-based on purpose: **one microphone, passed between players**, so the
judge never has to tell two voices apart and no player's turn is spoiled by
the other's bleed. `max_local_players = 2`, `local_multiplayer_turns = true`.
Each player has their own soundcheck profile ("P1"/"P2"). A "Pass the
megaphone" card between turns shows the next player's name, colour **and**
P1/P2 label:

| Mode | How it works |
| --- | --- |
| **Duel** (chant war) | §6.5, with two humans. Each player echoes the other's call. Best of 5 exchanges |
| **Two Capos** (co-op) | One match. Players alternate **verses** (each chant loop) on one shared Chant Life, morale and Fury. One shared result |
| **Split the Stands** | Each player leads the same seeded match in turn, for their half of the curva. Highest Noise wins, and results wait for the final turn |

Two Capos and Split use P1's chant pool, chart and seed so shared turns are
comparable. Per-seat input profiles still apply. Verse count-ins contain two
guide beats plus 0.58 s. The old source survives its positive-latency capture
tail (latency +0.18 s), then closes before the next player's lead-in.
Responses begin after the call's capture tail +0.04 s. Final judgement settles
for 0.5 s plus positive latency while football stops at the authored whistle.
No source switch may erase an old seat's late valid hit or the next seat's
first note. Original phase indices are remapped once, not repeatedly in place.

Mobile stays single-player (`GameSession.multiplayer_available()`). A
simultaneous mic-versus-buttons duel is in Stretch (§16).

### 9.4 Records

Best Noise and stars per career match and per Quick-play ground and group,
best combo, rivals beaten and the actual banners. Daily derby remains
post-v1 (§11.4). Stored in
`user://tifo_beato.cfg`, declared in `save_files`. Writes merge into the
file, and a record never regresses.

### 9.5 The commentator — `match/commentator.gd`

The commentator is part football analyst, part tragic poet. `commentator.gd`
is node-free. It maps **model events** (combo tier, chant died, rally, tifo,
goal, keeper trembles, chaos won, chant war verdict, walkout) to line banks,
with a priority, a cooldown (6 s, tune) and no repeat within a match:

- *"A clap. A single, perfect clap. Somewhere, a poet weeps."*
- *"The chant… has died. And with it, a little of all of us."*
- *"Look at the keeper. He has seen the curva. He has seen his own ending."*
- *"Full Curva Meltdown. I have no further words. I have only scarves."*

Every line is a **caption**. V1 deliberately has no voice-over
(owner-approved, §17). A telegraph caption always
wins over a commentator line, because a telegraph is information and the
commentator is decoration.

---

## 10. Shell features

### 10.1 Saves

| File | Holds | Declared in `save_files`? |
| --- | --- | --- |
| `user://tifo_beato.cfg` | Career, identity, actual banners, records, rival and exhibit unlocks | **Yes** — "The Curva" |
| `user://tifo_beato_voice.cfg` | Soundcheck profiles (§4.3) | No — calibration |

### 10.2 Store — currency "Tokens"

Turnstile tokens. `store_currency`: about one Token per 400 Noise *(tune)*, a
`round_bonus` for finishing a match, a `win_bonus` for a chant war won against
a CPU capo, and a ceiling of 120 per match. Everything is **cosmetic only**.
A gold megaphone doesn't widen a timing window.

One completed hot-seat set pays once, after its final seat. Build/steward
practice and incomplete rounds pay zero; duplicate settlement cannot pay again.

| Slot id | Wears | Kind |
| --- | --- | --- |
| `tb_capo_hat` | The capo's hat | `hat` |
| `tb_capo_jacket` | The capo's jacket | `jacket` |
| `tb_megaphone` | The megaphone | `megaphone` |
| `tb_drum` | The drum (starts as the bucket) | `drum` |
| `tb_scarf` | Scarf style worn by the whole curva | `scarf` |
| `tb_fabric` | Banner fabrics available in the workshop | `fabric` |

Starter catalogue: the **bucket** (default drum), a biscuit-tin drum, a proper
bass drum and the Golden Bin (gated: `tifo_beato_final`); a plastic megaphone
(default), a gramophone horn, a traffic cone and a brass Megatron; a bobble hat,
a fisherman's cap, a crown and a traffic-cone hat; a rain jacket, a bomber
and a ridiculous fur coat; silk and glitter fabrics.

### 10.3 Gallery

`GALLERY_EXHIBITS`:

- **Tifos:** each of the five tiers, gated by its first reveal.
- **Groups:** each group (§7.2), gated by its unlock.
- **Rival capos:** each one, gated by beating them.
- **The chaos cast:** the seagull, Kevin and his kazoo, the stewards and the
  beach balls.
- **Ground dioramas:** one per ground, from the Rec to the Final.
- **The bucket:** where it all began.

The stage implements `configure`, `set_view` and `set_auto_spin`. It may draw
the **player's latest banner** on the tifo exhibits by reading the progress
save, falling back to a default banner.

### 10.4 Share card

There are two variants, both through the game's `share_art.tscn`:

- The **match card**: the crest, the group name, Noise as the headline, stars,
  best combo by name, the match score and the biggest tifo revealed.
- The **banner card**: the workshop banner, mishaps and all, with its quality
  and a commentator line.

Both carry the ground and the QR code to `stats_url`. They freeze the actual
finished banner and equipment rather than rereading the wardrobe after a round.
Daily badges are post-v1.

### 10.5 Accessibility (non-negotiable)

- **Buttons are first-class** (pillar 2). The game is fully playable, and
  every achievement earnable, with no microphone.
- **Any sound**, **Wide windows**, **Chant speed**, **Chant never dies**,
  **Gentle rivals** and **Quiet Mode** (§3.8, §4.6).
- **Notes** carry an icon, a shape and a label. Sing rungs are positions *and*
  labels (LOW / MID / HIGH). Meters show numbers and icons, never colour
  alone.
- **Captions** for every meaningful sound: the guide drum (as a visual pulse),
  every disruption telegraph, the rival mocking chant, the chant dying, the
  steward's head turning, the referee, every goal and the commentator.
- **Reduced motion**: the stand's bounce is a gentle pulse, scarf spins and
  the tornado are still frames, tifos cross-fade, and there is no camera shake
  or punch zoom. The beat lane keeps scrolling, because it *is* the gameplay.
  A **static lane** option shows notes appearing in place instead.
- **Intense effects off**: no Meltdown shake, no power-cut flicker (a slow dim
  instead), no flash on goals, slower smoke.
- **P1/P2** labels on the Pass the megaphone card and the HUD.
- Touch pads are large and can be repositioned for left- or right-handed play,
  and they accept independent multitouch.

### 10.6 Audio — `audio/tifo_audio.gd`

All v1 audio is original synthesis: a 55 Hz/8 kHz low guide, layered capo/crowd
syllables, distinct rival patterns, disruptions, stings and steward cues.
Responses render accepted timings, bands and mistakes with crowd scatter,
not a perfect replacement chart. Sustained Buttons notes sound the capo.
The commentator is caption-only. Real group recordings are not a v1
requirement; synthesis is the approved direction, not a missing-recording
fallback. Physical classification and speaker-bleed certification are still
required independently.

### 10.7 Achievements (keys are stable forever)

| Key | Title | Badge | Condition |
| --- | --- | --- | --- |
| `tifo_beato_first_chant` | Eleven Strong | 11 | Finish a match at Bucketwick Rec |
| `tifo_beato_promoted_rec` | Out of the Rec | RECCED | Promotion from Bucketwick Rec |
| `tifo_beato_promoted_town` | Town Criers | TOWN | Promotion from Gasworks Lane |
| `tifo_beato_promoted_second` | Fog Horns | 2ND | Promotion from the Stadio Comunale Nebbiolo |
| `tifo_beato_promoted_league` | The Cathedral Sings | LEAGUE | Promotion from The Cathedral |
| `tifo_beato_final` | The Whole City | FINAL | Finish the Continental Final with 3 stars or more |
| `tifo_beato_never_died` | Ninety Minutes | NONSTOP | Finish a match without the chant dying, assists allowed except Chant never dies |
| `tifo_beato_meltdown` | Full Curva Meltdown | ×4 | Reach a 64-hit combo |
| `tifo_beato_fury` | Curva Fury | FURY | Unleash Curva Fury |
| `tifo_beato_first_mosaic` | Every Fan a Pixel | MOSAIC | Reveal a card mosaic |
| `tifo_beato_unholy_choreo` | The Unholy Choreo | CHOREO | Reveal a tier-5 tifo |
| `tifo_beato_drum_solo` | The Drum Is Mine | SOLO | Score 32 Beats in one Drum solo |
| `tifo_beato_seagull` | Give It Back | GULL | Win the seagull chase |
| `tifo_beato_a_cappella` | Lights Back On | A CAPPELLA | Win the power cut |
| `tifo_beato_rally` | Back from the Dead | RALLY | Rally after the chant dies and still earn 3 stars |
| `tifo_beato_chant_war` | Sing-Off | DUEL | Win a chant war |
| `tifo_beato_all_rivals` | Undisputed | 5 CAPOS | Beat all five rival capos |
| `tifo_beato_mishap` | The Crowd Loves It Anyway | OOPS | Reveal a banner with three or more mishaps |
| `tifo_beato_smuggler` | Nothing to Declare | FLAG | Sneak the flag past every steward |
| `tifo_beato_keeper_tremble` | He Has Seen the Curva | KNEES | Make the rival keeper tremble for a full half |
| `tifo_beato_two_capos` | Two Capos | DUO | Finish a hot-seat match |

These keys gate grounds (§8.1), groups (§7.2), store items and gallery
exhibits. Every achievement can be earned with assists and on Buttons. **None
rewards loudness or session length** (§4.6).

---

## 11. Later milestones (planned, after v1)

These are designed now so v1's architecture leaves room for them. They ship
after the career spine.

### 11.1 Away days

Travel stages between away matches:

- **Bus singalong**: a free-tempo singalong where the bus driver's wipers set
  the beat and potholes are Rests.
- **Train station chants**: the station's **echo** answers you after one beat.
  Leave it room, or your call trips over its own echo.
- **Hostile stadiums**: you are in the away end, and the home crowd tries to
  drown you out. Disruptions double, and the bleed gate's off-grid rule still
  holds.

### 11.2 Derby week

A build-up to the derby with Inter Nebula (ground 4): **painting walls** (a
workshop variant on a mural), **rehearsal** (practice mode for the derby
chants) and **rallying the group** (recruit fans with short chants at the pub
quiz, the bakery and the barber). Each ritual raises the derby's starting
crowd size and morale.

### 11.3 Chant Creator

Record your own chant with the mic or keys over a chosen tempo. The creator
quantises it to the 16th grid, lets you edit notes, write lyric slots and pick
a response style, then saves it as a `ChantChart`. It needs no new input,
because it consumes the same `SoundEvent` stream. **Challenge a friend** offline
through hot seat. A **chant code**, a short text string with the chart in it,
copies to the clipboard and pastes into another copy of the game.

### 11.4 Daily derby and Best Moments

- **Daily derby**: the seed is the player's local date (`YYYYMMDD`) *(§17)*. It
  picks a ground, a rival, a group and a modifier. Everyone gets the same match
  on the same day, so share cards compare fairly. The daily derby ignores
  unlock gates and records a daily best and a streak. Its board is local only.
- **Best Moments**: the match model is deterministic from its seed and
  its **judged-event log**, which is small: a few KB per match. The game keeps
  the 12 best moments (the loudest Fury, the most heroic scarf tornado, the
  biggest tifo and the **worst off-key disaster**) and replays them in the
  real 3D view from the log. Stored in the progress save.

---

## 12. Art direction

### 12.1 Pipeline and camera

Follow Chicken Pit and Cube Trials: a real `Node3D` world in an isolated
`SubViewport` driven by the node-free model, original vertex-coloured
low-poly meshes, scenery batched through `mesh_builder.gd` (copied from
`cube_trials/world/` and adapted), a warm key light with compatibility
shadows, and no SSAO or glow.

The camera has three shots:

- **Fence shot** (default): over the capo's shoulder, looking up at the curva,
  with the pitch visible below and behind.
- **Pitch shot**: on a goal or a match event, a quick cut to the toy pitch
  with the stand behind it.
- **Tifo shot**: wide, from the opposite stand, for reveals.

Cuts happen only in response halves and are never forced during a call. With
**Reduced motion** the camera holds the fence shot and cross-fades for the
others.

### 12.2 The crowd

- **Fans** are one low-poly toy figure: round head, scarf, arms that go up.
  The crowd is a **`MultiMeshInstance3D`** per section, with per-instance
  colour (scarf / card) and per-instance custom data (seat phase, mood). A
  compatibility-safe vertex shader animates the bounce, the arms and the
  scarf from `sync`, `energy` and phase. No skeletons.
- The rendered crowd is **11 individual rigs** at the Rec, up to **≈ 3,000
  instances** at the Final *(tune)*, with painted crowd cards for the far
  stands.
- Budget: **below 90 draw calls** in a match shot *(tune)*, enforced by
  `curva_view_test.gd`.
- The **capo rig** (`world/capo_rig.gd`) and **rival capos** are proper rigs
  with procedural poses: megaphone up, fist pump, the stare-down, the slump
  when the chant dies.

### 12.3 Palette and theme

The default club is Bucketwick Rovers' yellow and navy. The player's colours
replace them in the game, **never** in the framework theme:

```gdscript
const NAVY := Color("1d2a4a")        # plaque, ink
const BUCKET := Color("f4c430")      # accent: Bucketwick yellow
const TERRACE := Color("8c8f94")     # concrete steps
const PITCH := Color("4f9d4a")
const FLOODLIGHT := Color("fff6d8")
const SMOKE_PINK := Color("f48fb1")  # cartoon smoke only
const NIGHT := Color("141824")       # night-match sky
const SCARF_RED := Color("d64541")   # rival end
```

`GameTheme`: accent `BUCKET`, light `FLOODLIGHT`, plaque `NAVY`, a
floodlit-night gradient background, `style_share_card = true`, and the logo
`assets/game-icon.png` (the capo on the fence with a megaphone and a bucket,
captured from the model). Player identities keep the shared blue/red/green
colours, and the theme must not tint them.

---

## 13. Tunables and bindings

| Key | Type | Default |
| --- | --- | --- |
| `game/tifo_beato_input` | choice: Microphone / Buttons | Buttons |
| `game/tifo_beato_latency_ms` | additive trim −100…400 ms; combined total capped | 0 |
| `game/tifo_beato_headphones` | toggle, overrides profile flag | false |
| `game/tifo_beato_quiet_mode` | toggle | false |
| `game/tifo_beato_any_sound` | toggle | false |
| `game/tifo_beato_windows` | choice: Normal / Wide / Widest | Normal |
| `game/tifo_beato_chant_speed` | choice: 100 / 85 / 70 % | 100 % |
| `game/tifo_beato_never_dies` | toggle | false |
| `game/tifo_beato_rivals` | choice: Full / Gentle / Off | Full |
| `game/tifo_beato_static_lane` | toggle | false |
| `game/tifo_beato_commentator` | choice: Off / Captions | Captions |
| `game/tifo_beato_commentator_chattiness` | choice: Quiet / Normal / Chatty | Normal |
| `game/tifo_beato_touch_layout` | choice: Standard / Left-handed / Right-handed | Standard |
| `game/tifo_beato_mode` | Career / Quick match / Chant war / Workshop | Career |
| `game/tifo_beato_hot_seat` | Duel / Two Capos / Split the Stands | Duel |
| `game/tifo_beato_soundcheck` | request Soundcheck on resume; opens no mic in Settings | false |

The lobby Soundcheck action or **Soundcheck on resume** in the Game tab
reopens §4.3. The device picker lives there, not in a tunable.

Bindings (§4.5) all use the prefix `controls/tifo_beato_`: `beat_left`,
`beat_right`, `shout`, `sing_low`, `sing_mid`, `sing_high`, `fury`, `power`.
The beat and sing keys are `movement: false`. In hot seat every seat shares
P1's keys (`local_multiplayer_turns`). The gamepad is polled in `gameplay.gd`,
as Cube Trials does.

---

## 14. Architecture

### 14.1 File layout

```
game.gd, tifo_beato_options.gd   # manifest, constants, content and unlock declarations
gameplay.gd, gameplay.tscn       # inherited GameShell and game-owned orchestration
intro.tscn, presentation/intro.gd # five player-paced still cards, Next/Skip
sound/                         # frames/events, classifier, capture, pitch, profiles,
                               # bleed/latency/guide and mic/key/pad/touch/CPU sources
sound/input_stream.gd          # one timestamped stream with independent contacts
chart/chant_chart.gd, chant_phrase.gd, chants.gd, match_chart.gd
chart/chants/*.tres            # 24 original chant Resources
match/                        # judge, life, Fury, crowd, seeded football, chaos,
                               # disruptions, tifos, war, commentator and match state
career/                       # career_state.gd, identity.gd, word_list.gd, records.gd
workshop/                     # banner.gd, build_race.gd
steward/steward_state.gd       # both gentle steward mini-games
world/                        # procedural mesh builder, capos, rivals, props, drums,
                               # crowds/shader, scenery, pitch, tifos and curva viewport
ui/                           # widgets.gd, lobby.gd, career_map.gd, soundcheck.gd,
                               # match_hud.gd and independent touch_controls.gd
audio/tifo_audio.gd            # original synthesis and audible playback clock
presentation/stage.gd          # shared original-model setup/store/gallery/share stage
character_preview.tscn, store_preview.tscn, gallery_stage.tscn, share_art.tscn
assets/                       # captured icon/ground/intro stills and tutorial/poster
tests/                        # actual suites and event/platform fixtures (§15)
tools/                        # validate.ps1, capture_art.gd, tutorial_driver.gd,
                               # numeric sound_spike and chart_preview scenes/scripts
```

The lobby builds identity/workshop controls through the game-owned widgets;
there are no separate identity-editor/workshop scene wrappers. Steward props
share `world/props.gd`. There is no raw bleed recorder or recorded-fixture folder.

### 14.2 Model / view split

Everything under `sound/` (except `mic_capture.gd`), `chart/`, `match/`,
`career/`, `workshop/` and `steward/` is a node-free `RefCounted` or `Resource`.
It touches **no autoload and no node**, and it is what the headless tests
exercise. `gameplay.gd` collects `SoundFrame`s from the active source,
classifies them, gates them, feeds `match_state.gd` and hands the state to
`curva_view.gd`. The view may add bounce, scarf spin and smoke, but it never
feeds back into the model. Best Moments (§11.4), the daily derby and the
deterministic match all depend on that rule.

The match clock is the **audio clock**: `AudioServer.get_time_since_last_mix()`
and the playback position of the pre-rendered guide drum, never `_process`
delta. Timing judgement against a frame-rate clock would be unfair on slow
machines.

### 14.3 `GameShell` hooks used

`game_id`, `_prepare_session`, `_build_playfield`, `_begin_first_round`,
`_load_round_settings` (`super()`), `_reset_round_state`, `_activate_round`,
`_update_round`, `_handle_gameplay_input`, `_finish_round`, `_round_totals`,
`_player_stats`, `_describe_round_outcome`, `_round_highlight_summary`,
`_award_round_achievements`, `_round_points_earned`, `_configure_mode_ui`
(`super()`), `_on_game_setting_changed`, `_set_reduced_motion_enabled`
(**`super(value)`**), `_set_intense_effects_enabled` (**`super(value)`**).
Copy the signatures exactly from `AGENTS.md`.

A shell **round is one match** (or one chant war, or one full set of
hot-seat turns). With `uses_shell_round_rules = false`, the match ends by its
own rules: the final whistle or a walkout (§3.4). Gameplay then calls the
shell's normal end-of-round path, as Cube Trials does. The soundcheck and career lobby are game-owned overlays; a career performance can
include its workshop/steward preparation and half-time war in the same shell
round. Practice modes can finish their own result without career progression.
First entry is the inactive lobby; replay immediately starts a fresh round.
`_round_totals` reports Noise. `_player_stats` reports Noise, stars, accuracy,
best combo, tifos, Fury uses, match score and the assist badge.

### 14.4 Manifest sketch

```gdscript
game.id = Options.GAME_ID                       # "tifo_beato"
game.title = "Tifo Beato"
game.tagline = "Ninety minutes. No silence."
game.menu_order = 12
game.gameplay_scene_path = "res://games/tifo_beato/gameplay.tscn"
game.intro_scene_path = "res://games/tifo_beato/intro.tscn"
game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
game.uses_shell_round_rules = false
game.supports_multiplayer = true                # hot seat (§9.3)
game.supports_cpu_opponent = false              # solo rival wars are game-owned
game.max_local_players = 2
game.local_multiplayer_turns = true
game.levels = Options.GROUNDS                   # §8.1, achievement-gated
game.characters = Options.GROUPS                # §7.2
game.character_preview_scene_path = ".../character_preview.tscn"
game.save_files = [{"path": "user://tifo_beato.cfg", "title": "Your curva",
		"description": "Career, club identity, banners and records."}]
game.tunables / control_bindings / store_* / gallery_* = Options.*
game.tutorial_video_path / tutorial_poster_path
game.stats_url = "https://deskcansaw.com"       # ≤ 42 bytes
game.theme = theme                              # §12.3
```

### 14.5 Integration checklist (outside this folder)

- [x] `project.godot`: `config/name.tifo_beato`,
      `config/custom_user_dir_name.tifo_beato="DeskCanSaw Games/Tifo Beato"`
      (approved and stable forever),
      `config/icon.tifo_beato`, `dcs/build/single_game_id.tifo_beato`,
      `[share] stats_urls/tifo_beato`. Keep `audio/driver/enable_input=true`
      for the tag.
- [x] `export_presets.cfg`: Windows/Web/Android/iOS presets with the tag and the
      microphone / record-audio permission on mobile. Add `games/tifo_beato/*`
      to the other standalone presets' `exclude_filter`, and keep tests/tools out.
      Packaging does not complete mobile signing/device certification.
- [x] Existing `.gitmodules` and gitlink registration retained:
      `git@github.com:jraleman/tifo_beato.git`. Task changes stay uncommitted.
- [x] Root `AGENTS.md`: games table, submodule list, options-file list, test
      table, feature-tag list and a per-game blurb. Update `godot-base/README.md`
      if it lists games.
- [x] Import, game suites, real-window checks and shared integration sweep.
      The shared aggregate video check remains blocked by Puppy Kraft's missing
      recording; all Tifo media checks pass. Prefer preload-by-path.

---

## 15. Tests — `tests/`

These are the actual suite names. They run headless unless noted, as standalone
`SceneTree` scripts. `tools/validate.ps1` provides an isolated project/user
directory and rejects unexpected engine diagnostics even with exit code 0.

| Suite | Covers |
| --- | --- |
| `sound_test.gd` | Synthesized PCM classification, pitch, calibration, source parity, guide/known-output gating and capture cleanup; no physical microphone is opened |
| `model_test.gd` | All original charts, judge/assists/life/Fury, deterministic football, fixed-duration goals, persistent chaos ledgers, safe disruptions, wars/stewards, banner images, career/records and compensated handoff/output clocks |
| `scene_test.gd` | All owned scripts compile; actual lobby/replay/handoff releases, store/fabric preferences, synthesized responses, compact inventory accessibility, late/safe rival audio, digital-silence errors and developer previews |
| `flow_test.gd` | Complete genuine keyboard/touch input through Quick, workshop, both stewards, war, career and all three hot-seat modes; actual accuracy/stars/earnings and no non-career progression |
| `curva_view_test.gd` *(window)* | Physical sizes/UI scales, real keyboard/touch play, complete cast/camera/effect/model/share geometry, lane/pad separation, all five story cards in 30 layout cases, and <90 visible+shadow Final draws (measured 32) |

`flow_fixture.gd` dispatches real events, never grades. `platform_fixture.gd`
extends Node and is wrapped by `platform_test.tscn` only in a separate QA
export. It verifies actual packed-engine full input, payout, capture cleanup,
branding/exclusions and real tutorial decoding. Browser checks use a deny-only
microphone stub and exercise the real Start/Use Buttons actions; they never
grant hardware access. Neither fixtures nor tools ship in production packs.

The fifteen framework suites discover the manifest automatically. Fourteen
pass; the aggregate walkthrough check currently fails because unrelated
`puppy_kraft` declares no recording. Tifo's video decodes on native and web.
Hardware and owner-review gates are not replaced by these checks.

---

## 16. Milestones

1. **Sound spike.** ⚠ The riskiest part. Copy the mic stack, then build the
   classifier, the bleed gate, the guide drum and latency calibration, with a
   explicit-start numeric readout. Verify real rooms (laptop speakers, a phone,
   a TV, headphones) without saving raw audio. *Goal: it hears you
   and only you.* Targets: ≥ 90 % correct clap / shout / sing classification
   across three testers, under one false onset per minute of match audio on
   laptop speakers, and Perfect hits reachable after calibration.
2. **The judge (grey box).** Chart format, two chants, `chant_judge.gd`, the
   key source, the beat lane HUD and the audio-clock timing.
3. **Capo mode.** Call and response, the crowd model playing back your
   scatter, Chant Life, morale and rally, combos, Fury, scoring, stars,
   results and every assist.
4. **The 3D curva.** View, cameras, crowd MultiMesh and shader, capo rig, the
   Rec and Gasworks Lane.
5. **The match.** `match_sim.gd`, the pitch view, energy effects and goal
   moments.
6. **Chaos.** Rival disruptions (off-grid), chaos events and power-ups.
7. **Tifos and the workshop.** Tifo tiers 1–5, the mosaic from a banner, the
   banner editor, the build race and mishaps.
8. **Chant wars and stewards.** The duel, five rival capos, insults, and both
   steward mini-games.
9. **Career content.** Five grounds, the career map, 24 chants, five groups,
   the identity editor, achievements, gated progression and captured ground
   stills.
10. **Shell features.** Hot seat (Duel, Two Capos, Split the Stands), store,
    gallery, share cards, character preview, intro, theme and icon,
    commentator, credits and tutorial video.
11. **Polish and integration.** Accessibility sweep, mobile touch and mic
    pass, web pass, framework suites with `--game=all`, export preset and docs.

**Later (planned, §11):** 12. Away days. 13. Derby week. 14. Chant Creator
and chant codes. 15. Daily derby and Best Moments.

**Stretch:** online daily leaderboards and chant sharing (needs a backend,
privacy copy, moderation and anti-cheat by event-log verification); a
simultaneous mic-versus-buttons duel; more groups and grounds (a
lower-league cup run, a snowy away day); a women's league curva with its own
career; localisation (Italian, Spanish, German); a "be the steward" mode.

---

## 17. Approved decisions and remaining release review

| Topic | Owner-approved decision |
| --- | --- |
| Scope | Full v1, milestones 0–11; adjacent framework integration authorized |
| Title | Tifo Beato — Ninety minutes. No silence. |
| Groups | Sections inside the player's own curva |
| Comfort | Relative capped loudness; no extra reward above comfortable carry |
| Audio | Original procedural chants and synthesized capo/crowd; no recording requirement |
| Commentator | Captions only in v1 |
| Text | Curated club/group/banner words, no free text |
| Smoke | Cartoon smoke, no flares |
| Rivals | Fictional, gentle humour; owner reviews names/copy/content before release |
| Progression | Stars can promote even when the football team loses |
| Melodies | Original synthesis; owner reviews originality/content before release |
| Hot seat | Duel, Two Capos and Split the Stands |
| Platforms | Desktop/web/mobile support; physical-device checks remain required |
| Daily boundary | Deferred with milestone 15; no v1 daily mode |

Unfinished release gates are tracked in `TODO.md`: three-tester physical
classification/calibration, speaker bleed, real gamepad/multitouch, granted
recording and platform/GPU tests, mobile signing and owner melody/copy review.
Do not mark them complete from synthetic PCM, package exports or deny-only
browser tests. Work remains unstaged/uncommitted as requested.
