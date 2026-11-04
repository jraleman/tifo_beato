# Tifo Beato

**Ninety minutes. No silence.**

An original football-terrace rhythm game for the DeskCanSaw Godot framework.
Lead the Bucket Brigade from an eleven-person recreation ground to the
Continental Final. Hit calls, hear the crowd answer your actual performance,
make ridiculous banners and support a seeded toy football match.

Milestones 0-15 are implemented; **physical-device and owner release review are
still required**. All clubs, characters, artwork and synthesized chants are
fictional and game-owned. There are no recorded crowds or commentator voices.

## Run

This repository lives at `godot-base\games\tifo_beato`. It needs the adjacent
Godot framework; it is not a second standalone Godot project.

From this folder, with Godot 4.7 on PATH:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=tifo_beato
```

The shared setup selects a ground and curva section. First entry opens the
game's railway/lobby, not an already-running match. Choose Career, Quick,
Chant war, Workshop, Away, Derby, Creator, Daily or Best Moments there.
Hot-seat setup also enables Creator challenges. **Buttons are the default**;
opening a menu never requests microphone access.

## Play

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Beat | F / J | A / X or bumpers | Either Beat pad |
| Shout / unvoiced Hold | Hold Space | Hold RT | Hold Shout |
| Sing LOW / MID / HIGH | Hold A / S / D | LT + vertical stick | Hold a labelled rung |
| Curva Fury | Q | Y | Fury pad |
| Power-up | E | B | Power pad |
| Pause | Escape | Start | Pause |

Keyboard bindings are rebindable in Controls. Touch contacts are independent;
release an old key, trigger or finger before confirming a handoff. All sources,
including CPU rivals, use the same 100 Hz classifier and timing judge.

Square Beat means an onset; Shout needs 150 ms; Sing uses your comfortable
relative pitch; Hold needs 80% coverage; X Rest means silence. Normal timing
windows are 45 / 90 / 140 ms for Perfect / Great / Good. Responses are breath
breaks. Keep Chant Life alive, rally a dead chant with four Beats, and build
combos, Fury and tifos. Crowd energy influences football, but never guarantees
a win. **Career promotion uses best stars, not football results.**

## V1 content

- Five grounds, five curva sections, 24 original chant Resources and a
  star-gated railway career.
- Seeded football, five tifo tiers, six chaos events, safe telegraphed rivals,
  four power-ups and a caption-only tragic-poet commentator.
- Banner design/build races with real saved image mishaps; Sneak the Flag and
  Drum in the Coat; five fictional rival capos and five-exchange sing-offs.
- **Duel:** echo each other's real calls. **Two Capos:** alternate verses with
  shared life, morale and Fury. **Split the Stands:** play the same P1 chart
  and seed in complete successive turns. Desktop hot seat supports two humans;
  mobile remains solo.
- Twenty-one achievements, six cosmetic slots/22 items, 28 base gallery
  exhibits plus the saved banner, frozen match/banner share images, a five-card
  intro and a real 64-second tutorial.

Quick and hot-seat play do not advance career stars. Only completed
performances pay Tokens, once per match/set, capped at 120; workshop and
steward practice pay none. Cosmetics never change the judge.

## Expanded modes

The railway's five additional pages are playable, not roadmap placeholders.

| Page | Rules |
| --- | --- |
| Away days | Choose 60-180 BPM for the wiper bus; potholes are Rests. Station calls leave scored silence for the echo. Hostile ends double only already-safe disruptions, respecting Gentle/Off. Away career stops offer optional bus/train/skip before kickoff. |
| Derby week | Paint a mural, rehearse, or recruit at the pub, bakery and barber. Only each ritual's best counts: up to +25 starting morale and +25% crowd at Cathedral stop 4 against Inter Nebula. Rituals never gate kickoff or overwrite the match banner. |
| Chant Creator | Record classified events at 60-180 BPM over 1-8 bars; edit up to 64 sixteenth-grid notes with curated lyrics and Echo/Clapback/Harmony. Voice notes need at least 160 ms. Explicitly save one of eight local slots. Checked `TB1` codes, at most 8,192 characters, share musical data offline; invalid imports preserve the draft. |
| Daily Derby | Local midnight changes the date seed, ground, section, modifier and real halftime rival. Unlock gates do not apply. The date freezes at kickoff; bests and consecutive completed-date streaks stay local. Replays refresh today's date; repeated attempts cannot inflate a streak. Frozen shares include the date, seed and assist badge. |
| Best Moments | Keep twelve short Fury, tornado, tifo and off-key clips. Real 3D playback/seek reconstructs bounded numeric checkpoints and judged events with frozen banner/outfit, not microphone audio or a newly scored performance. |

Away activities, rituals and Creator practice/challenges pay no Tokens or
career stars and cannot unlock match achievements. Short practice keeps its
authored chart without Fury/power-ups. Choose two humans in shared setup for
the Creator's identical-chart successive challenge; mobile remains solo.
Daily is a complete match with the ordinary bounded one-time payout.
Best Moments opens no input, pays nothing and never changes progress.

## Microphone, comfort and accessibility

Microphone play is optional. Soundcheck starts only after an explicit Start:
room, claps, comfortable speaking/carrying, relative pitch and speaker bleed.
No microphone audio is monitored, uploaded or saved. The private capture bus
is silenced at -80 dB and removed synchronously when capture closes, including
pause, rival turns, handoffs, results and exit.

Denied/no-signal input displays an explicit error and leaves Retry, Cancel and
Use Buttons available. Exact digital silence fails the room step rather than
pretending calibration succeeded. Web needs HTTPS (or localhost), permission
and a user gesture. Android requests `RECORD_AUDIO` at runtime.

Volume is capped at calibrated carry; exceeding it gives no advantage. Quiet
Mode normalizes to speaking level and fixes the score multiplier at the
carry-equivalent 1.2. Timing trim is **added** to each seat's measured profile,
then capped to -100..400 ms. P1/P2 have independent microphone and Buttons
profiles. Headphones are recommended after bleed, never required.

Any sound, wider windows, slower chants, Chant never dies, Quiet Mode, Static
lane and Gentle/Off rivals remain available without blocking achievements.
Notes have shapes and labels, meters have numbers, sound cues have captions,
and P1/P2 retain blue/red identities. Reduced motion and effects settings
also reach the original 3D models. Take a rest or switch to Buttons if using
your voice is uncomfortable.

## Saves

Exported builds permanently use `DeskCanSaw Games/Tifo Beato` as their user
directory. Ordinary source launches retain the framework's development user
directory, so use the isolated runner for tests.

| File | Purpose |
| --- | --- |
| `user://tifo_beato.cfg` | Merged career, identity, banners, records, ritual bests, eight chant slots, daily history and twelve numeric Best Moments |
| `user://tifo_beato_voice.cfg` | Numeric calibration only; not included in progress backups |
| `user://settings.cfg` | Framework-managed options and bindings |
| `user://achievements.cfg`, `user://store.cfg` | Framework-managed achievements, wallet and cosmetics |

The shared Saves screen manages progress backups. Records/unlocks never
regress. Completed share cards freeze the actual banner and wardrobe instead
of rereading later equipment.

## Validate and regenerate

From this folder:

```powershell
.\tools\validate.ps1 -Godot 'C:\path\to\godot.exe' `
  -Suites @('sound','model','scene','flow','post_v1','post_v1_flow') -Window -Framework `
  -TimeoutSeconds 300
```

The runner imports an isolated junction project/user directory, saves logs and
checks engine diagnostics as well as exit codes. `sound_test.gd`,
`model_test.gd`, `scene_test.gd`, `flow_test.gd`, `post_v1_test.gd` and
`post_v1_flow_test.gd` run headless;
`curva_view_test.gd` requires an actual graphics window. Flow tests route real
keyboard/touch events through complete matches and every mode, not direct
score assignments. The platform fixture is a Node for a separate QA export
or an external native-pack driver, not another headless SceneTree suite.

The game suites and GPU input/layout checks pass. Native production-pack and
exported web checks cover complete Quick matches, bus/station travel, pub
recruitment, live Creator recording/save/code import/practice, Daily's actual
rival and read-only Best Moments. Web runs cover portrait touch/+400 ms and
desktop keyboard/-100 ms, actual tutorial decoding, deny-only microphone
recovery and capture cleanup.
All fifteen shared-framework suites pass, including the collection tutorial
decoder. Window checks cover the expanded workbench/replay pages at normal
and enlarged UI scales, real travel/ritual scenery and frozen daily shares.

From `godot-base`, regenerate original stills or the silent tutorial:

```powershell
godot --path . --script res://games/tifo_beato/tools/capture_art.gd -- --game=tifo_beato
.\tools\record_tutorials.ps1 -Godot 'C:\path\to\godot.exe' -Games tifo_beato
```

`sound_spike.tscn` offers explicit-start numeric diagnostics; `chart_preview.tscn`
inspects the 24 original charts without awarding grades. Neither is shipped.
There is deliberately no raw-audio recorder.

## Packaging and outstanding release gates

The host declares Windows, Web, Android and iOS standalone presets with feature
`tifo_beato`. They exclude foreign games, tests and tools. Matching official
Godot export templates are required. Android additionally needs configured JDK/
SDK paths and private signing settings; the non-Gradle template supplies its
SDK defaults. The tested ARM64 debug APK has min SDK 24, target SDK 36 and only
the microphone permission, not NFC.

The SDK auditor reports a missing template `themed_icon.xml`; the declared
adaptive launcher icon is present and parses. Themed-launcher behavior still
needs Android device validation.

Windows release and web exports have boot/runtime checks; Android packaging
is verified but no device is connected. iOS still needs an Apple team,
provisioning and the Apple toolchain. Do not treat package export, browser
permission denial or synthetic PCM as physical microphone certification.

Release still requires owner review of melodies/rival copy/content,
three-tester microphone/latency and speaker-bleed checks, real gamepad and
multitouch use, granted recording on desktop/web/mobile, and mobile GPU,
permission and signing verification. See [TODO.md](TODO.md) for the gates and
[DESIGN.md](DESIGN.md) for rules. Online boards/sharing, simultaneous microphone
versus Buttons and the other stretch modes remain outside this implementation.