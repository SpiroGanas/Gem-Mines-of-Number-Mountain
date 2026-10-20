# Tests

GdUnit4 suites mirroring `autoload/`, `scripts/` and `scenes/`. GdUnit4 6.2.2 is installed (see `docs/decisions.md`).

| Folder | What it covers |
|---|---|
| `autoload/` | `Text`, `UI`, `InputRouter`, `Profiles`, `Adaptive` and `Rewards` autoloads (synthetic events, a fake clock, a temp save folder); `test_profiles.gd` covers create/select/rename/delete, the four-profile limit, the trash and no leaking between children |
| `core/` | `DigFlow` (the dig loop's rules), `Problem`, `Skill`/`SkillCatalog`, `GameClock`, `RewardsRules`, `ProgressReport`, `ParentGateRules`, `DeviceSettings`, `JsonUtil`, `SfxBank` |
| `generators/` | seeded tests per problem generator (edge cases, distractor rules), `generator_checks.gd` (the invariants every MVP problem must meet, run over 10,000 seeds per skill for all 45 skills) and `test_registry.gd` |
| `curriculum/` | the skill graph on the Godot side: prerequisites exist, no cycle, one root, every generator resolves, every misconception name is allowed |
| `adaptive/` | BKT, skill records, the scheduler, placement, the hint ladder, the engine, and the simulated learners (random guesser never masters; fast learner tests out), the Challenge Door (10,000 simulated doors) and the weekly Deep Dig |
| `save/` | schema, migrator, store (atomic write, crash recovery) and the `SaveSystem` autoload; `save/fixtures/` holds one save file from every schema version (v1, v2, v3); `test_migrations.gd` moves a Version 1.0 single save into profile 1 (schema v3); `test_save_merge.gd` and `test_cross_device.gd` cover Sprint 17's newest-wins import, backups, checksum and log |
| `workshop/` | Sprint 16: recipe and build validation (with a bad fixture), the crafting and build rules, and the crafting bench, build site, build runner and hub machines |
| `scenes/` | screen flow, the mine, every input widget, the visual model, the answer panel (every MVP skill through its widget), Word Gems, the workshop screens, the parent area (dashboard v2's skill map and weekly summary, family rewards), the Sprint 19 screens (badges, glossary, Challenge Door, Deep Dig), Sprint 20's polish (Bolt's poses, zones), the readability audit and `test_hardening.gd` (posture change mid-rock, close and restart, update over an old save, a long dig through every hint rung) |
| `zones/` | zone-specific widgets: Zone 5's `SieveGrid` (tap to cross out, rocks crossed from the start stay crossed, full-size rocks at 4:3) and `FactorTree` (splits through `BoulderSplit`, completion only when every leaf is a prime gem, trees up to 100 fit); Zone 6's `GearBench`, gear train and polish; Zone 7's crystal (`CrystalShards`, `CrystalPicker`), alloy mixer and depth gauge; Zone 9's pattern wall, proof board (`ProofFit`) and Fib poem maker (`FibPoem`) |
| `input/` | the chalk slate (`DigitBox`, `ChalkSlate`, `StrokeDemo`), `SlateReader`, `NumeralCoach` and the debug `StrokeCapture` |
| `handwriting/` | `StrokeRaster` and `DigitNet` against the fixtures the Python tools write (`fixtures/`), the recognizers and `DigitInk` |
| `ui/` | the Explorer theme (contrast, sizes) |
| `helpers/` | `InputSim` builds synthetic touch/mouse/key events and feeds them to an `InputRouter`; `TestWindow` gives layout tests a 1920x1080 window (GdUnit4's headless window is only 64x64, which wrecks every size measured in dp); `PanelDriver` plays an `AnswerPanel` through a problem; `FakeClock` moves days forward for the adaptive engine and rewards |

Run everything (the Godot 4.7.2 binary path goes in `GODOT`; drop the two headless flags when a display is available):

```bash
GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests
```

`-c` makes GdUnit4 continue after a failure; without it a suite stops at its first failing test. After adding a new `class_name` script, run `"$GODOT" --headless --path . --import` once so Godot registers it.

Python tools tests (curriculum checks, lint rules, export permissions, the cross-check's checkers and exporter): `python -m pytest tools`. The independent math cross-check itself is `python tools/crosscheck/run.py --all --n 10000` (see `tools/README.md`).

Layout bugs that unit tests cannot see (stretched pieces, overflowing buttons) were found by rendering the screens under a virtual display: `xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 res://build/probe/shots.tscn` (a throwaway scene under the gitignored `build/`; run it as a scene, not with `--script`, so the autoloads exist), saving `get_viewport().get_texture().get_image()` to a PNG. Each such bug then got a regression test.

Tests that need input events build them with `InputSim` and call `InputRouter.process_event()`, because the engine does not deliver real input in headless CI. Tests that touch saves point `SaveSystem` at a temp folder with `use_directory()` and never at the real save.
