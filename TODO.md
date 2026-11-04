# Tifo Beato - v1 implementation and release gates

The owner approved full v1 (milestones 0-11), all three hot-seat modes,
desktop/web/mobile support and adjacent framework integration. Checked items
below have working code and automated evidence. **Hardware, signing and owner
review are separate unchecked gates, not inferred successes.** Task changes
remain unstaged/uncommitted.

See [DESIGN.md](DESIGN.md) for rules and [README.md](README.md) for commands.
The host `AGENTS.md` framework boundary still takes precedence.

## Approved decisions

- [x] Title/tagline: **Tifo Beato - Ninety minutes. No silence.**
- [x] Curva groups are sections inside the player's own stand.
- [x] Relative, capped loudness; comfortable carry is the ceiling.
- [x] Original synthesized chants/capo/crowd; no real recording requirement.
- [x] Caption-only commentator, curated text and cartoon smoke without flares.
- [x] Stars-only career promotion, even after losing the football match.
- [x] Duel, Two Capos and Split the Stands in v1.
- [x] Owner melody/rival-copy/content review remains mandatory before release.
- [x] Menu order 12 retained after Dolce's Adventure, Sailor Man and Capitan's Walk.

## Phase 0 - Framework contract

- [x] Self-contained manifest, constants, inherited `GameShell`, game notes and
  original theme; no game-to-game import or shared game-name branch.
- [x] Existing submodule registration preserved without registering twice.
- [x] First entry is an inactive railway/lobby; replay immediately starts a
  clean round. Shared shell/lives tests explicitly start lobby-first games.
- [x] Game-owned round rules ignore saved arcade timer/lives preferences.
- [x] Stable standalone branding, user directory and feature overrides.

## Milestones 1-3 - Sound, judge and capo

- [x] One 100 Hz frame/classifier/judge pipeline for mic, keys, pad, independent
  touch contacts and CPU; deterministic PCM/calibration regressions.
- [x] Explicit-start private capture, no monitoring/saved PCM, silenced bus,
  synchronous close/removal and clear denied/no-signal errors.
- [x] Exact digital silence fails room calibration; a genuinely quiet room
  remains usable. Denied web capture recovers through the actual Use Buttons action.
- [x] Original low guide, spectral split, known-output gate and compensated
  emission/input clocks; stronger real input survives the gate.
- [x] Per-seat microphone/Buttons profiles; additive timing trim capped to
  -100..400 ms; current Headphones option overrides old profile flags.
- [x] Beat/Shout/Sing/Hold/Rest, audio-clock windows, grades, combo tiers,
  capped volume, Quiet Mode's fixed carry-equivalent 1.2 and assist parity.
- [x] Call/response synthesis from actual accepted notes, crowd scatter,
  Chant Life/morale/rally/walkout, Fury and four power-ups.
- [x] Accessible HUD/touch input, captions, shaped/labelled notes and all assists.

## Milestones 4-6 - Original world, football and chaos

- [x] Real Compatibility `SubViewport`, original stadiums/capo/crowd/pitch/props,
  three safe camera shots, responsive layouts and motion/effect overrides.
- [x] Deterministic 10 Hz football biased by crowd energy, never a guaranteed win.
- [x] Goals finish the current line and author 16 optional future Beats without
  changing the final whistle or penalizing displaced notes.
- [x] Five tifo tiers, the real banner mosaic and cartoon smoke.
- [x] Four telegraphed disruptions; whole audio intervals avoid protected notes,
  Holds and Rests even with assists. Unsafe late audio is caption-only.
- [x] Six chaos events with persistent reward ledgers; two per normal ground,
  three for Chaos Kids, all six at the Final.

## Milestones 7-9 - Workshop, wars, stewards and career

- [x] Curated banner/identity editor, materials budget, actual store fabric,
  timed build race, seeded mishaps and saved rendered banner image.
- [x] Five distinct fictional rival capos and original patterns, including both
  performing Twin halves; CPU uses ordinary acoustic frames.
- [x] Five escalating war exchanges, two-beat human preparation, safe capture
  tails and equal 700-point echo budgets independent of call density.
- [x] Sneak the Flag and Drum in the Coat with gentle failure and real outcomes.
- [x] Five grounds/sections, 24 original chant Resources, star-gated railway
  career, group bonuses, curated identity and merged non-regressing records.
- [x] Career-only progression; Quick, practice and hot seat never advance stars.
- [x] Twenty-one achievements and captured original icon/ground/intro stills.

## Milestone 10 - Shell content and hot seat

- [x] Duel, Two Capos and Split the Stands with named blue/red handoff cards,
  physical-release checks, independent profiles and one final payout.
- [x] Co-op verse leads preserve every note with a one-pass phase-index mapping;
  positive/negative latency profiles retain both sides of each handoff.
- [x] Two Capos/Split use P1's chart pool and seed; shared modes keep distinct
  human identities and per-seat statistics.
- [x] Tokens store: six cosmetic slots, 22 items, actual previews/equipment and
  synchronized fabric selection. Incomplete/build/steward practice pays zero.
- [x] Gallery: 28 base exhibits plus the saved banner, real model turntables,
  progress availability and generic shared availability handling.
- [x] Frozen match/banner share snapshots, setup preview, caption commentator,
  five player-paced story cards, credits and original theme.
- [x] Updated 64-second real-input tutorial and poster. The menu video is
  intentionally silent; no microphone capture is used to record it.
- [x] Next/Skip and complete story text fit all five cards in 30 actual window
  size/UI-scale cases; touch actions remain at least 44 physical pixels.

## Milestone 11 - Automated validation and packaging

- [x] Godot 4.7 import plus `sound`, `model`, `scene` and `flow` suites.
- [x] Complete genuine keyboard/touch input through Quick, workshop, stewards,
  war, career and all three hot-seat modes; bounded one-time payout.
- [x] Actual GPU portrait/short-landscape/desktop/tablet/ultrawide and enlarged
  UI checks, including after judged input, not only time-zero screenshots.
- [x] All original cast/effect/camera/gallery/store/share geometry in shot;
  Cathedral roof framing corrected; Final visible+shadow draws measured 32/90.
- [x] Fourteen shared-framework suites pass, including lobby-first replay,
  untimed rules, intro, availability, saves, store and share integration.
- [x] Tifo's actual Instructions video decodes on native and exported web.
- [ ] Entire collection tutorial sweep green: unrelated `puppy_kraft` has no
  walkthrough, so the aggregate fifteen-suite run correctly exits 1.
- [x] Windows and web release exports; actual native release boot and production
  PCK input/video checks; full pack exclusion/branding audits.
- [x] Exported web full matches: portrait touch/+400 ms and desktop keys/-100 ms,
  100% accuracy, five stars and 120 Tokens. Deny-only microphone tests close
  capture and preserve Buttons without granting hardware access.
- [x] ARM64 Android debug APK export and metadata/permission audit: min SDK 24,
  target SDK 36, microphone only, no NFC. No device is connected.
- [x] iOS preset and microphone purpose text; no fabricated team/signing data.
- [x] Game/host authoring documentation, actual file/suite names and approved
  decisions reconciled.
- [x] Scoped test/import/export profiles keep real player saves and global
  editor SDK preferences untouched; tests/tools/foreign games excluded.

## Unfinished physical and owner release gates

- [ ] Owner review of all 24 original melodies and the rival/name/content banks.
- [ ] Three testers: at least 90% clap/shout/sing classification, reachable
  Perfects after calibration, comfortable relative pitch and loudness.
- [ ] Laptop/phone/TV speakers and headphones: fewer than one false onset per
  minute of match audio, including Full rivals and real room latency.
- [ ] Physical keyboard/gamepad/multitouch, device loss, handoffs and pause/
  resume with an actual instrument; real accessibility use.
- [ ] Granted microphone recording and real no-signal/permission/revocation
  behavior on desktop, secure web and mobile. Denied browser tests are not
  proof of granted-capture correctness.
- [ ] Mobile GPU, thermal/audio budget, touch layout and runtime permission
  validation on real hardware.
- [ ] Release signing/distribution verification for Android.
- [ ] Apple toolchain, team/provisioning, signed iOS build and actual iOS device.

## Post-v1 only

- [ ] Milestone 12: Away days.
- [ ] Milestone 13: Derby week.
- [ ] Milestone 14: Chant Creator and chant codes.
- [ ] Milestone 15: Daily derby and Best Moments; date boundary still undecided.
- [ ] Stretch: online leaderboards/sharing, simultaneous mic-versus-buttons,
  more grounds/groups, women's league, localization and steward mode.
