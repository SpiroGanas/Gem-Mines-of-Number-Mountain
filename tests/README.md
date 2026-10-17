# Tests

GdUnit4 suites mirroring `autoload/`, `scripts/` and `scenes/`. GdUnit4 6.2.2 is installed (see `docs/decisions.md`).

| Folder | What it covers |
|---|---|
| `autoload/` | `Text`, `UI` and `InputRouter` autoloads (a fresh instance per test; events are synthetic) |
| `core/` | `DigFlow` (the dig loop's rules), `JsonUtil`, `SfxBank`, the gray-box problem |
| `generators/` | seeded tests per problem generator (10,000-problem runs, edge cases, distractor rules) |
| `adaptive/` | BKT unit tests and simulated-learner suites (random guesser never masters; fast learner tests out) |
| `save/` | schema, migrator, store (atomic write, crash recovery) and the `SaveSystem` autoload; `save/fixtures/` holds one save file from every past schema version |
| `scenes/` | scene-loading, input-mode and screen-flow tests |
| `ui/` | the Explorer theme (contrast, sizes) |
| `helpers/` | `InputSim` builds synthetic touch/mouse/key events and feeds them to an `InputRouter`; `TestWindow` gives layout tests a 1920x1080 window (GdUnit4's headless window is only 64x64, which wrecks every size measured in dp) |

Run everything (the Godot 4.7.2 binary path goes in `GODOT`; drop the two headless flags when a display is available):

```bash
GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests
```

`-c` makes GdUnit4 continue after a failure; without it a suite stops at its first failing test. After adding a new `class_name` script, run `"$GODOT" --headless --path . --import` once so Godot registers it.

Python tools tests (curriculum checks, lint rules, export permissions): `python -m pytest tools`.

Tests that need input events build them with `InputSim` and call `InputRouter.process_event()`, because the engine does not deliver real input in headless CI. Tests that touch saves point `SaveSystem` at a temp folder with `use_directory()` and never at the real save.
