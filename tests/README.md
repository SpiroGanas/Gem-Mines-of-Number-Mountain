# Tests

GdUnit4 suites mirroring `autoload/`, `scripts/` and `scenes/`. GdUnit4 6.2.2 is installed (see `docs/decisions.md`).

| Folder | What it covers |
|---|---|
| `autoload/` | `Text`, `UI` and `InputRouter` autoloads (a fresh instance per test; events are synthetic) |
| `core/` | `DigFlow` (the dig loop's rules), `Problem`, `Skill`/`SkillCatalog`, `ProblemSource`, `JsonUtil`, `SfxBank` |
| `generators/` | seeded tests per problem generator (edge cases, distractor rules), `generator_checks.gd` (the invariants every Zone 1 problem must meet, run over 10,000 seeds per skill) and `test_registry.gd` |
| `curriculum/` | the skill graph on the Godot side: prerequisites exist, no cycle, one root, every generator resolves, every misconception name is allowed |
| `adaptive/` | BKT unit tests and simulated-learner suites (random guesser never masters; fast learner tests out) |
| `save/` | schema, migrator, store (atomic write, crash recovery) and the `SaveSystem` autoload; `save/fixtures/` holds one save file from every past schema version |
| `scenes/` | scene-loading, input-mode and screen-flow tests, the mine, the drag board, choice buttons, the visual model and the answer panel |
| `ui/` | the Explorer theme (contrast, sizes) |
| `helpers/` | `InputSim` builds synthetic touch/mouse/key events and feeds them to an `InputRouter`; `TestWindow` gives layout tests a 1920x1080 window (GdUnit4's headless window is only 64x64, which wrecks every size measured in dp); `PanelDriver` plays an `AnswerPanel` through a problem |

Run everything (the Godot 4.7.2 binary path goes in `GODOT`; drop the two headless flags when a display is available):

```bash
GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests
```

`-c` makes GdUnit4 continue after a failure; without it a suite stops at its first failing test. After adding a new `class_name` script, run `"$GODOT" --headless --path . --import` once so Godot registers it.

Python tools tests (curriculum checks, lint rules, export permissions, the cross-check's checkers and exporter): `python -m pytest tools`. The independent math cross-check itself is `python tools/crosscheck/run.py --all --n 10000` (see `tools/README.md`).

Layout bugs that unit tests cannot see (stretched pieces, overflowing buttons) were found by rendering the screens under a virtual display: `xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 --script some_probe.gd`, saving `get_viewport().get_texture().get_image()` to a PNG. Each such bug then got a regression test.

Tests that need input events build them with `InputSim` and call `InputRouter.process_event()`, because the engine does not deliver real input in headless CI. Tests that touch saves point `SaveSystem` at a temp folder with `use_directory()` and never at the real save.
