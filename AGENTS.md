# Tifo Beato

Read the host `dcs_games/AGENTS.md`. This is a self-contained game under the
Compatibility renderer, discovered through `game.gd`. Do not import another
game or add game-name branches to the shared shell.

The owner approved the title/tagline, sections inside the player's curva,
relative capped volume, curated text, cartoon smoke without flares, stars-only
promotion, all three hot-seat modes, and desktop/web/mobile support.
Audio is original synthesis, not recordings. The owner reviews chants and
fictional rival copy before release.

## Invariants

- Models in `sound/`, `chart/`, `match/`, `career/`, `workshop/` and `steward/`
  are node-free, except the microphone capture node. Preload scripts by path.
- All human/CPU inputs pass through the same 100 Hz frames and classifier.
  Timing uses the audio playback clock, not accumulated render-frame delta.
- Never monitor or save microphone audio. Capture is explicit and stops on
  pause, handoff, results and exit. The private capture bus is silenced at
  -80 dB and removed when capture closes.
- Crowd audio is gated to response/rival turns. The guide is below the onset
  band. Known output is gated, and rival transients must avoid judged notes.
- Register known output through the match state's compensated clock, not the
  raw playback clock. Late rival audio that no longer fits stays caption-only.
- Handoffs retain the old positive-latency capture tail before switching
  sources; remap original phase indices only once when inserting lead-ins.
- Volume and Fury are capped at the calibrated carry level. Quiet Mode uses
  speaking level; keys and claps can earn every bonus. No reward for session
  length or excess volume.
- Groups change content/bonuses, never the basic timing judge. Assists cannot
  penalize the same performance.
- Career advances on best stars, not football wins. Saves merge; records and
  unlocks never regress. Quick play and hot seat do not advance the career.
- P1/P2 names and shared blue/red colors survive custom club colors. Every
  sound cue has a caption. Motion/effects overrides call `super(value)`.
- Cosmetics affect presentation only. Shared results/payout wait for the last
  hot-seat turn. Each seat keeps its own input profile.
- Away/ritual/Creator activities are unranked. Short practice has no Fury or
  power-ups; chart rewrites must not alter the player's draft.
- Creator consumes the accepted classifier events. Save only bounded musical
  data with curated lyric ids; never load Resources or paths from chant codes.
  Sustain lengths must remain playable by the same 100 Hz classifier.
- Daily uses local calendar midnight and freezes its date/configuration for
  the whole match. Restore ordinary unlock-constrained selections afterward.
- Derby bonuses merge each ritual's best, never stack repeat attempts.
- Best Moments stores numeric visual checkpoints and judged events, not PCM
  or a new scoreable source. Replay/seek must not capture, settle or save.
- Generated replacement notes need unique ids throughout a match; a later
  solo must not reuse ids from notes that were already playable.

## Validation

Run from `godot-base/`, using Godot 4.7:

```text
godot --headless --path . --import
godot --headless --path . --script res://games/tifo_beato/tests/model_test.gd -- --game=all
godot --headless --path . --script res://games/tifo_beato/tests/sound_test.gd -- --game=all
godot --headless --path . --script res://games/tifo_beato/tests/scene_test.gd -- --game=all
godot --headless --path . --script res://games/tifo_beato/tests/flow_test.gd -- --game=all
godot --headless --path . --script res://games/tifo_beato/tests/post_v1_test.gd -- --game=all
godot --headless --path . --script res://games/tifo_beato/tests/post_v1_flow_test.gd -- --game=all
godot --path . --script res://games/tifo_beato/tests/curva_view_test.gd -- --game=all
godot --path . -- --game=tifo_beato
```

Use the game-owned `tools/validate.ps1` (Windows) or `tools/validate.sh`
(Linux/macOS; Bash 3.2+ and Python 3.10+) for an isolated user profile. The host
framework suites sweep this manifest automatically. `curva_view_test.gd`
also checks all five intro cards and expanded workbench/replay pages after
wrapping at normal/enlarged UI scales, plus real travel/ritual scenery.
`platform_fixture.gd` is a Node for a separate QA export/external pack driver,
not a standalone SceneTree suite; production presets exclude tests and tools.
It covers actual packed native/web Quick, travel, recruitment, Creator
record/save/import/practice, Daily rival and read-only replay flows.
Real-room classification, speaker bleed, physical touch/gamepads and permission
flows require hardware testing; synthetic tests are not evidence that those
release gates passed.
