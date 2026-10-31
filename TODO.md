# Tifo Beato — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §16, with a scaffolding phase first. Tick a box only when
the item works **and** its tests pass. Each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

---

## Blocked on the owner (DESIGN §17)

These change names, keys or scope that become permanent once shipped. Nothing
below that depends on one should start until it is answered.

- [ ] **Title and tagline** (§17.1) — "Tifo Beato" exactly? This fixes
      `custom_user_dir_name` forever and blocks the `project.godot`
      feature-tag entries in Milestone 11.
- [ ] **Groups vs your curva** (§7.2–§7.3, §17.2) — sections inside the
      player's curva, or separate groups. Blocks `GROUPS` in Milestone 9 and
      the character preview.
- [ ] **Voice health rule** (§4.6, §17.3) — relative, capped loudness. Blocks
      the volume scale and Fury charging constants in Milestone 3.
- [ ] **Crowd and capo recordings** (§10.6, §17.4) — a real group of about a
      dozen people. Placeholders until then. Blocks final crowd audio in
      Milestone 10.
- [ ] **Commentator voice-over in v1?** (§9.5, §17.5) — and who voices it.
      Captions ship either way.
- [ ] **Free text** (§6.4, §8.4, §17.6) — closed word list only, or a filtered
      free-text option. Blocks the identity editor and banner text.
- [ ] **Smoke and pyro** (§6.1, §17.7) — cartoon smoke only, no flares.
- [ ] **Rival names and insult tone** (§6.5, §17.8) — and who reviews the
      insult bank.
- [ ] **Stars-only progression** (§8.2, §17.9) — a lost match can still promote.
- [ ] **Chant composer and melody check** (§9.1, §17.10) — who writes the 24
      chants and who checks none is an existing song.
- [ ] **Daily derby day boundary** (§11.4, §17.11) — local midnight or UTC.
      Only blocks Milestone 15.
- [ ] **Hot seat in v1** (§9.3, §17.12) — all three modes, or Duel only.

## Discrepancies found while planning

- [ ] The project targets Godot **4.7**, but this machine has **4.6.2**
      (`/usr/bin/godot`). Install 4.7 before trusting any test result.
- [ ] `menu_order = 12` assumes Dulce's Adventure (`9`), Sailor Man (`10`) and
      Capitan's Walk (`11`) keep their planned slots. All three are design-only
      so far. Keep `12` anyway so the order doesn't shift later.
- [ ] The folder's `README.md` is a one-line placeholder (`# tifo_beato`).
- [ ] Sailor Man plans to copy the same Dead Metal Jam mic stack. Two games
      with two adapted copies is the rule (no game-to-game dependency), but if
      a third mic game appears, raise a framework-owned `sound/` layer as data
      instead of copying again.
- [ ] `control_bindings` are keyboard-only. The gamepad is polled in
      `gameplay.gd`, as Cube Trials does, so gamepad buttons are not
      rebindable in Settings. Accept that, or raise it as framework data.
- [ ] The soundcheck, career map, workshop, steward checks and identity editor
      are game-owned screens outside the shell round (§14.3). Check they fit
      the shell's flow (instructions → round → results) before building them
      (Milestones 3 and 7–9).
- [ ] The shell's lives pool is unused (`uses_shell_round_rules = false`).
      Morale is the game's own pool (§3.4), so Settings must not show the
      shell's round/assist rows for this game. Confirm it doesn't.

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from here on.

- [ ] Commit `DESIGN.md` and this `TODO.md` to the game repository.
- [ ] A folder `AGENTS.md` with game-specific agent notes, as Chicken Pit has
      (the bleed rules in §4.4 and the off-grid rule belong there).
- [ ] `tifo_beato_options.gd` — constants-only: `GAME_ID`, tunable keys (§13),
      binding keys (§4.5, §13), with empty `GROUNDS`, `GROUPS`, store and
      gallery for now.
- [ ] `game.gd` — minimal manifest (§14.4): id, title, tagline, `menu_order = 12`,
      `CONTROL_STYLE_CUSTOM_KEYS`, `uses_shell_round_rules = false`, tunables,
      bindings. Leave multiplayer off until Milestone 10.
- [ ] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [ ] A `tests/` folder and a smoke test that loads the manifest by path.
- [ ] `godot --headless --path . --import`
- [ ] **Exit:** all 15 framework suites exit 0 with `--game=all`, and
      `godot --path . -- --game=tifo_beato` opens the stub.

## Milestone 1 — Sound spike (§4) ⚠ riskiest

- [ ] `sound/sound_frame.gd`, `sound/sound_event.gd`.
- [ ] `sound/mic_capture.gd` — adapted from `dead_metal_jam/input/`: silenced
      `TifoCapture` bus, dead-mic test, high-pass on the onset path.
- [ ] `sound/pitch_detector.gd` — adapted MPM/NSDF, 75–900 Hz, continuous cents.
- [ ] `sound/sound_classifier.gd` (`RefCounted`, every threshold a constant at
      the top):
  - [ ] Onsets from high-band flux, 60 ms refractory
  - [ ] Clap / bang by decay
  - [ ] Shout by sustained level, voiced or not
  - [ ] Sing by voiced sustain, low / mid / high band against the centre
  - [ ] Silence
- [ ] `sound/guide_drum.gd` — pre-rendered low thump, band-limited below ~180 Hz.
- [ ] `sound/latency_calibration.gd` — adapted; clap-along to the guide drum.
- [ ] `sound/bleed_gate.gd` — turn gate and known-output gate (§4.4).
- [ ] `sound/mic_source.gd`, `sound/key_source.gd` (virtual profile).
- [ ] `tools/sound_spike.tscn` — live readout of frames, events, the band and
      the gate. Dev-only.
- [ ] `tools/bleed_recorder.tscn` and `tools/sound_log.gd` — record match
      audio through laptop speakers, a phone, a TV and headphones into fixtures.
- [ ] `tests/sound_classifier_test.gd`, `tests/latency_calibration_test.gd`,
      `tests/bleed_test.gd` (first pass on the recorded fixtures).
- [ ] **Exit:** with three testers, record here: classification accuracy
      (target ≥ 90 % clap / shout / sing), false onsets per minute of match
      audio on laptop speakers (target < 1), and whether Perfect hits are
      reachable after calibration. If speakers can't meet the target, decide
      whether Headphones becomes the recommended default before moving on.

## Milestone 2 — The judge, grey box (§3.2–§3.3, §9.1)

- [ ] `chart/chant_chart.gd`, `chart/chant_phrase.gd` — tempo, 16th grid,
      call / response / sustain, lyric slots.
- [ ] Two placeholder chants in `chart/chants/`.
- [ ] `match/chant_judge.gd` — windows, grades, volume scale capped at carry,
      pitch scale, Rest notes.
- [ ] The audio clock: guide drum playback position plus
      `AudioServer.get_time_since_last_mix()`; never `_process` delta.
- [ ] `ui/match_hud.gd` — the beat lane, with an icon, a shape and a label per note.
- [ ] `tools/chart_preview.tscn` — draw one chart on its grid. Dev-only.
- [ ] `tests/chart_test.gd`, `tests/chant_judge_test.gd` (first pass, including
      keys vs voice within 5 %).
- [ ] **Exit:** play a chant to the end by mic and by keys and see every grade.

## Milestone 3 — Capo mode (§3, §5.3, §7.1)

- [ ] Call and response loop; sustain phrases.
- [ ] `match/crowd_state.gd` — sections, sync, phase scatter; the response
      plays back the scatter.
- [ ] `match/chant_life.gd` — drain in call halves after the grace, refills,
      mocking at 25, death, rally, morale and walkout.
- [ ] Combo tiers by name (§3.5), banking, captions and stings.
- [ ] `match/fury.gd` — charging by shout and by Perfect, capped at carry;
      long-shout and key activation; one per half.
- [ ] `match/match_state.gd` — walk-in, halves, half-time slot, final whistle,
      Noise, stars.
- [ ] Assists (§3.8): Any sound, Wide windows, Chant speed, Chant never dies,
      Quiet Mode, Static lane.
- [ ] `ui/soundcheck.tscn` — room, clap, speak, shout, sing, speakers check;
      `sound/voice_profile.gd` → `user://tifo_beato_voice.cfg`.
- [ ] `sound/pad_source.gd`, `sound/touch_source.gd` (independent multitouch).
- [ ] HUD: Chant Life scarf, morale, Fury, energy flag, combo name, numbers
      and icons throughout.
- [ ] `gameplay.gd` hooks (§14.3): one shell round = one match; shell
      end-of-round path; `_round_totals`, `_player_stats`,
      `_describe_round_outcome`, `_round_highlight_summary`.
- [ ] `tests/chant_life_test.gd`, `tests/fury_test.gd` (clap path vs shout
      path within 10 %), `tests/crowd_state_test.gd`,
      `tests/tifo_scene_test.gd` (first pass).
- [ ] **Exit:** a full grey-box match to the results panel by mic, keyboard,
      gamepad and touch. Framework suites green.

## Milestone 4 — The 3D curva (§12)

- [ ] `world/mesh_builder.gd` — copy from `cube_trials/world/` and adapt.
- [ ] `world/curva_view.gd` — isolated `SubViewport`; fence, pitch and tifo
      shots; cuts only in response halves; reduced motion holds the fence shot.
- [ ] `world/crowd_multimesh.gd` + `world/crowd.gdshader` — per-section
      MultiMesh, per-instance colour and phase, bounce / arms / scarf from
      `sync` and `energy`; compatibility-safe.
- [ ] `world/capo_rig.gd` — megaphone, fist pump, slump.
- [ ] `world/ground_scenery.gd` — Bucketwick Rec (11 individual fans) and
      Gasworks Lane.
- [ ] `audio/tifo_audio.gd` — guide drum, layered placeholder crowd voices
      with the phase scatter, stings, ducking under call halves.
- [ ] `tests/curva_view_test.gd` *(window)* — capo, curva and lane in shot,
      draw calls, portrait → ultrawide, touch pads clear of the lane.

## Milestone 5 — The match (§5)

- [ ] `match/match_sim.gd` — five-zone possession walk at 10 Hz, seeded.
- [ ] Energy effects: flaming players, heavy ball, trembling keeper, inspired
      home keeper, confused team at low energy — each with an icon and a caption.
- [ ] Goal moments: home celebration and away-goal defiance.
- [ ] `world/pitch_view.gd` — toy players, ball and keepers.
- [ ] `tests/match_sim_test.gd` — determinism, bias direction, nothing certain.
- [ ] **Exit:** a match where a strong performance visibly wins on the pitch
      more often than a weak one, and the stars never depend on the result.

## Milestone 6 — Chaos (§3.7, §6.2–§6.3)

- [ ] `match/disruptions.gd` — air horn, off-key trumpet, rival drums (ghost
      lane), inflatable; one-bar telegraphs; **always off-grid**; registered
      with the known-output gate; Gentle / Off.
- [ ] `match/chaos_events.gd` — seagull chase, split drum skin, power cut
      (a cappella, slow dim), beach balls, rain, Kevin's kazoo.
- [ ] Power-ups: Mega-megaphone, Drum solo, Scarf tornado, Ref Distraction
      Chant; triple-shout and key activation.
- [ ] `tests/chaos_events_test.gd`; extend `bleed_test.gd` and `chart_test.gd`
      for every disruption pattern.
- [ ] **Exit:** each disruption and event appears in a grey-box match, and
      `bleed_test.gd` still meets its target with disruptions on.

## Milestone 7 — Tifos and the workshop (§6.1, §6.4)

- [ ] `match/tifo_director.gd` — Perfect streaks → tier; reveal at the next
      response half.
- [ ] `world/tifo_view.gd` — scarf wall, card mosaic sampled from the banner
      (one MultiMesh), the 50 m banner, cartoon smoke, the Unholy Choreo;
      cross-fade under reduced motion; slow smoke with intense effects off.
- [ ] `workshop/banner.gd` — fabric, background, crest, text from the word
      list, extras, budget.
- [ ] `workshop/build_race.gd` — timed rhythm race, quality, seeded mishaps
      (upside-down, backwards, missing letter, paw print, googly eyes).
- [ ] `ui/workshop.tscn` — editor and race, budget as numbers and icons.
- [ ] `career/word_list.gd` — closed, curated, filtered (blocked on §17.6).
- [ ] `tests/workshop_test.gd`.
- [ ] **Exit:** a banner designed in the workshop appears, mishaps and all, as
      the card mosaic and the 50 m banner in the next match.

## Milestone 8 — Chant wars and stewards (§6.5–§6.6)

- [ ] `match/chant_war.gd` — stare-down, echo, free-form call, escalation,
      verdict; mic gated during the rival's turns.
- [ ] `sound/cpu_source.gd` — rival capos as `SoundFrame` streams with
      personality accuracy.
- [ ] Five rival capos: Big Sandro, Fräulein Paukenschlag, El Pulpo, Madame
      Moustache, The Twins; `world/rival_rig.gd`.
- [ ] Insult bank, captioned (blocked on §17.8 review).
- [ ] `ui/chant_war_hud.tscn`.
- [ ] `steward/sneak_the_flag.gd`, `steward/drum_in_the_coat.gd`,
      `world/steward_rig.gd`; gentle failure.
- [ ] `tests/chant_war_test.gd`, `tests/steward_test.gd`.

## Milestone 9 — Career content (§7–§9.1)

- [ ] `career/career_state.gd` — grounds, stops, stars, promotion at 9,
      budget growth.
- [ ] `ui/career_map.tscn` — the train-line map.
- [ ] Grounds 3–5 scenery: Stadio Comunale Nebbiolo, The Cathedral, the
      Continental Final (cartoon skyline flames).
- [ ] 24 original chants (blocked on §17.10), with lyric slots.
- [ ] `match/group_profiles.gd` — the five groups (per §17.2); `GROUPS` as
      `characters`.
- [ ] `career/identity.gd` + `ui/identity_editor.tscn` — names, colours with
      the luminance warning, crest, scarf, lyric slots.
- [ ] `career/records.gd` — `user://tifo_beato.cfg` merged, never regressing.
- [ ] `GROUNDS` with achievement gates; Quick play (§8.3).
- [ ] Achievements (§10.7): all twenty-one keys, each reachable with assists
      and on Buttons; none rewards loudness or session length (§4.6).
- [ ] `tools/capture_art.gd` — ground stills to `assets/levels/`.
- [ ] `tests/career_test.gd`, `tests/commentator_test.gd` (once lines exist).
- [ ] **Exit:** every ground and group is reachable from a fresh profile
      through its gate, and Quick play never changes the career.

## Milestone 10 — Shell features (§9.3, §9.5, §10)

- [ ] Hot seat (per §17.12): `supports_multiplayer`, `local_multiplayer_turns`,
      `max_local_players = 2`; Duel, Two Capos, Split the Stands; a
      per-player soundcheck profile; the Pass the megaphone card with name,
      colour and P1/P2.
- [ ] `match/commentator.gd` — event → line banks, priority, 6 s cooldown, no
      repeats, never over a telegraph, voiced only outside call halves.
- [ ] `character_preview.tscn` — the capo and their group on the setup plinth.
- [ ] Store (§10.2): Tokens, six slots, starter catalogue, `store_preview.tscn`.
- [ ] Gallery (§10.3): tifos, groups, rivals, chaos cast, dioramas, the
      bucket; `gallery_stage.tscn` with `configure`, `set_view`,
      `set_auto_spin`; optional player banner.
- [ ] Share cards (§10.4): the match card and the banner card.
- [ ] `GameTheme` (§12.3) + `assets/game-icon.png` captured from the model.
- [ ] `intro.tscn` — five story cards (§1).
- [ ] Instructions copy through `_game_text`; first-run soundcheck.
- [ ] Crowd recordings (blocked on §17.4); commentator voice-over (§17.5).
- [ ] Credits.
- [ ] Tutorial video + poster (`tools/tutorial_driver.gd`, `record_tutorials.ps1`).

## Milestone 11 — Polish and integration (§4.7, §14.5)

- [ ] Accessibility sweep against §10.5.
- [ ] Voice health sweep against §4.6: copy never says "louder", the
      15-minute suggestion, Quiet Mode end to end.
- [ ] Mobile pass (record permission, phone-speaker bleed, touch layouts);
      web pass (HTTPS, gesture gate, main-thread detector budget).
- [ ] `project.godot`: `config/name.tifo_beato`,
      `custom_user_dir_name.tifo_beato` (after the title is fixed),
      `config/icon.tifo_beato`, `dcs/build/single_game_id.tifo_beato`,
      `[share] stats_urls/tifo_beato` (≤ 42 bytes); `enable_input` stays on.
- [ ] `export_presets.cfg`: a standalone preset with mic permission; exclude
      `games/tifo_beato/*` from other presets; keep `tools/` and recorded
      fixtures out.
- [ ] `.gitmodules` + gitlink (`git@github.com:jraleman/tifo_beato.git`) —
      two commits.
- [ ] Root `AGENTS.md`: games table, submodules, options files, test table,
      feature tags, window-only suites, blurb. Update `godot-base/README.md`
      if it lists games.
- [ ] Write the folder `README.md` properly.
- [ ] **Exit:** all framework suites + all game suites exit 0 with
      `--game=all`; `curva_view_test.gd` runs without `--headless`.

## Later — planned after v1 (§11)

- [ ] **Milestone 12 — Away days:** bus singalong, station echo, hostile
      stadiums (disruptions still off-grid).
- [ ] **Milestone 13 — Derby week:** painting walls, rehearsal, rallying the
      group; starting crowd and morale for the derby.
- [ ] **Milestone 14 — Chant Creator:** record, quantise, edit, lyric slots,
      save as `ChantChart`; hot-seat challenge; chant codes via the clipboard.
- [ ] **Milestone 15 — Daily derby and Best Moments:** date seed (per
      §17.11), local board and streak; 12 best moments replayed from the
      judged-event log.

## Stretch (§16)

- [ ] Online daily leaderboards and chant sharing (backend, privacy copy,
      moderation, event-log verification)
- [ ] Simultaneous mic-versus-buttons duel
- [ ] More groups and grounds (cup run, snowy away day)
- [ ] A women's league curva with its own career
- [ ] Localisation (Italian, Spanish, German)
- [ ] "Be the steward" mode
