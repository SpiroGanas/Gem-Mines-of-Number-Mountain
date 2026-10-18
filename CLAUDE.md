# CLAUDE.md: Gem Mines of Number Mountain

Educational mining-and-crafting game teaching number theory (place value → modular arithmetic, ciphers, proof) to a gifted 6-year-old, Charlie, and later other families' kids aged 6–12. Built in **Godot 4.7 (GDScript)**, exported as an **Android app** for a touchscreen ARM 2-in-1 Chromebook (with stylus) and an Android tablet. Phones are out of scope.

Developer and product owner: **Spiro**, an experienced software engineer and AI expert who is **new to Godot and game development**. When you introduce a Godot idiom he may not know (signals, autoloads, scene inheritance, resources, tweens), explain it in 1–2 lines in your summary.

Full plan: `docs/development-plan.md`. Architecture decisions: `docs/decisions.md`. Game design: `docs/gdd.md`.

---

## Non-negotiable rules

Never break these. If a task seems to require breaking one, stop and ask.

1. **No network access in the shipped game.**
   - The Android export preset must not request `INTERNET`.
   - No analytics, ads, crash-reporting SDKs, accounts or live AI calls.
   - AI is used only at build time (code, scripts, pre-generated audio).
2. **No data leaves the device** unless a parent triggers export from the parent-gated area.
   - Never store handwriting images. Strokes are discarded after recognition.
   - Never collect location, contacts, camera, microphone or advertising IDs.
3. **No new dependency, plugin or SDK without asking Spiro first.** Every approved one gets an entry in `docs/sdk-audit.md`, because the app must pass Google Play's **Families Policy** for children's apps.
4. **Every child-facing string comes from the text table** (`text/lines.csv`) through the `Text` autoload, using a stable line ID. Never hard-code child-facing text in scenes or scripts; CI fails on hard-coded strings. This is what keeps adding narration in Phase 3 cheap. The MVP has no narration, because Charlie reads well.
5. **Text is written for a strong first-grade reader.**
   - Short sentences, and a picture alongside every instruction.
   - Math terms are tappable for a picture and a kid-sized definition.
   - From Phase 3, a read-aloud setting must make every screen usable without reading.
6. **Child-facing answer input never uses `LineEdit` or `TextEdit`.** Those pop up the system keyboard in tablet mode. Use the `NumberPad`, `ChalkSlate` (handwriting) or tap/drag targets. A `LineEdit` is allowed only in the parent area.
7. **Touch targets are at least 64 dp.** Use `UI.min_target_px()`; never hard-code pixel sizes for interactive controls.
8. **Wrong answers never cost anything.** No lost gems, no game-over, no timers or countdowns in Explorer mode, no streak resets. Missed days *pause* the lantern streak.
9. **Rewards are earned and never random-for-value.**
   - No loot boxes, spinners, slot-machine reveals or chance-based paid items. Rare gems come from rare *numbers* (twin primes, Mersenne primes), which is deterministic.
   - No in-game purchases.
10. **Math must be correct.** Every problem generator has a seeded automated test **and** an independent Python cross-check (see Testing). A generator and its checker must not share code.

## Content rules (family requirements)

Apply to all art, narration, story, examples, word problems and minerals:

- **Never include:**
  - Alcohol, gambling (or gambling-like mechanics), tobacco or smoking.
  - Poor air quality: campfires, fireplaces, smoky torches, smoke effects, forges with smoke.
  - Bees (no bee or honeycomb themes) and cats or dogs (no pet companions or pet examples).
  - Eating octopus or shellfish.
- **Light sources** in the mine are **electric** (Bolt's headlamp, electric lanterns, glowing crystals).
- **Tone:** warm, curious, encouraging. Bolt never mocks, sighs or uses sarcasm.
- **Feedback wording:** never "Wrong!" Use "Not quite. Let's look again."

## Writing child-facing text (`text/lines.csv`)

- **Explorer mode** (about ages 5–8): sentences of 12 words or fewer, first-grade vocabulary, one instruction per line.
- **Use real math terms, always with a kid explanation the first time:** "When we swap ten ones for one ten, that's called **regrouping**." Record each term as a Word Gem in `curriculum/vocabulary.json`.
- **Numbers** in lines are placeholders such as `{n}`, `{a}` or `{b}`, filled in at runtime. From Phase 3, the narration manager speaks them by splicing pre-generated number clips. Never bake a specific number into a line.
- **Every line has a stable ID:**
  - Format: `zone.context.purpose`, e.g. `z1.dig.prompt_build_number`.
  - Never reuse or rename an ID. Deprecate it and add a new one.
  - From Phase 3, changing a line's text marks it for audio regeneration.

---

## Tech stack and versions

| Area | Choice |
|---|---|
| Engine | Godot **4.7.x**, standard build (not .NET). The pinned version is in `.godot-version`. Don't upgrade without asking. |
| Language | **GDScript, statically typed** |
| Handwriting recognition | A small network trained offline with PyTorch (`tools/handwriting/`) and run **in GDScript** (`scripts/input/`, weights in `assets/handwriting/digit_net.json`). No Android plugin, no LiteRT, no ML Kit (`docs/decisions.md`, Sprint 13). |
| Android | Target SDK **36**, ABIs **arm64-v8a + x86_64**, landscape only, AAB for Play, APK for local testing |
| Java | JDK 17 (Temurin) |
| Tests | GdUnit4 (Godot), pytest (Python tools) |
| Offline tools | Python 3.12 in `tools/` (voice pipeline, cross-checker, BKT fitting, handwriting model training with PyTorch and numpy, which are build-time only and listed in `docs/sdk-audit.md`) |
| Dev machine | Windows. Use forward slashes in scripts, and keep shell commands working in Git Bash. |

### Godot 4 syntax only

LLM training data mixes Godot 3 and 4. Use Godot 4 forms exclusively:

| Use (Godot 4) | Never (Godot 3) |
|---|---|
| `@export var x: int` | `export var x` |
| `@onready var n := $Node` | `onready var n = $Node` |
| `await get_tree().create_timer(1.0).timeout` | `yield(...)` |
| `signal gem_collected(gem: Gem)` + `gem_collected.emit(gem)` | `emit_signal("gem_collected", gem)` |
| `btn.pressed.connect(_on_pressed)` | `connect("pressed", self, "_on_pressed")` |
| `Array[int]`, `Dictionary[String, int]` | untyped containers where a type is known |
| `super()` | `.method()` for parent calls |
| `FileAccess.open(...)`, `DirAccess` | `File.new()`, `Directory.new()` |
| `instantiate()` | `instance()` |
| `Tween` via `create_tween()` | `Tween` node |

If unsure whether an API exists in 4.7, check the Godot docs instead of guessing.

---

## Repository layout

```
project.godot
.godot-version
autoload/            # Singletons: Text, SaveSystem, Adaptive, Rewards, InputRouter, UI (Narration and Profiles arrive in Phase 3)
scenes/
  shell/             # title, hub, pause, settings, parent_area/
  mine/              # mine, rock wall, rock, cart, Bolt, gem art, visual model, answer panel
  input/             # NumberPad, BuildBoard, DragTarget, DragItem, ChoiceButtons, ChalkSlate (Phase 2)
  workshop/          # crafting/, builds/, museum/ (badges, Word Gems), garage, museum
  zones/common/ (Challenge Door), z05_prime_caverns/ (sieve, factor tree) … z12_infinite_core/
scripts/
  generators/        # one file per skill family; pure logic, no nodes
  adaptive/          # bkt.gd, scheduler.gd, placement.gd, hint_ladder.gd
  save/              # schema, migrator, store, migrations/
  core/              # Problem, Skill, SkillCatalog, Attempt, DigFlow, GameClock, RewardsRules, MotivationRules, ProgressReport, JsonUtil, SfxBank, ...
  workshop/          # Recipe, BuildProject, WorkshopRules (Sprint 16)
  ui/                # ExplorerTheme (theme built in code)
curriculum/
  skills/zNN_*.json  # skill graph: id, prereqs, generator, params, representations, terms
  vocabulary.json  misconceptions.json  bkt_defaults.json  recipes.json  builds.json  badges.json  rare_numbers.json
text/
  lines.csv          # id, text, context, voice_version (voice_version used from Phase 3)
narration/
  audio/             # Phase 3. GENERATED. Never hand-edit.
assets/              # art, fonts (Andika), sfx, music. Every file needs a LICENSE entry in assets/CREDITS.md.
addons/              # gdUnit4
android/plugins/digit_ink/   # EMPTY placeholder: recognition runs in GDScript, not in a plugin (README explains)
tests/               # GdUnit4 tests mirroring autoload/, scripts/ and scenes/; helpers/ has InputSim and TestWindow
tools/
  voice/  crosscheck/  bkt/  handwriting/  ci/  sfx/  music/  qa/
docs/                # development-plan.md, gdd.md, decisions.md, sdk-audit.md, phases/, art/, qa/ (release checklist, screenshots), reviews/
private/             # GITIGNORED: Charlie's exported logs and handwriting samples. Never commit or upload.
```

**Commit:** `*.uid` files (Godot 4.4+) and `export_presets.cfg` without secrets.
**Never commit:** `.godot/`, `build/`, `private/`, keystores, or API keys. Keys live in environment variables (`ELEVENLABS_API_KEY`, etc.).

---

## Commands

Set `GODOT` to the pinned Godot 4.7 executable (e.g., `export GODOT="/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"`).

```bash
# Import assets (needed after a fresh clone or a new asset, before headless tests)
"$GODOT" --headless --path . --import

# Run all Godot tests (GdUnit4). CI and other headless runs add: --headless --ignoreHeadlessMode
# -c continues after a failure (otherwise a suite stops at its first failing test)
GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh -c -a res://tests        # Git Bash
# Windows cmd alternative: set GODOT_BIN=... && addons\gdUnit4\runtest.cmd -c -a res://tests

# Run one test suite
GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh -a res://tests/generators/test_place_value.gd

# Python tools tests and the independent math cross-check (10,000 problems per generator;
# the cross-check needs GODOT set and the project imported once)
python -m pytest tools
python tools/crosscheck/run.py --all --n 10000

# Narration (Phase 3+): list lines missing audio / regenerate changed lines (calls a paid API; ask first)
python tools/voice/generate.py --dry-run
python tools/voice/generate.py --changed

# Lint: fails on hard-coded child-facing strings, LineEdit in child scenes, banned content keywords, network code
python tools/ci/lint_content.py

# Static performance check: no allocations in _process, OGG audio, exported-size budget
python tools/ci/perf_check.py

# Handwriting network (build time only; needs `pip install -r tools/handwriting/requirements.txt`)
python tools/handwriting/train.py                # writes assets/handwriting/digit_net.json
python tools/handwriting/evaluate.py             # accuracy per test set and the confidence sweep
python tools/handwriting/make_fixtures.py        # regenerate the GDScript parity fixtures after retraining

# Fit BKT parameters from a parent-exported bundle; the decision-gate numbers from the same bundle
python tools/bkt/fit.py path/to/bundle.json
python tools/bkt/gate_report.py path/to/bundle.json --since 2027-01-29

# QA tools (not exported): screenshots at every aspect ratio plus draw calls (needs a renderer),
# and the math reviewer's packet (headless)
xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 res://tools/qa/capture_screens.tscn
"$GODOT" --headless --path . res://tools/qa/math_review_packet.tscn

# Debug APK for local install / release AAB for Play (release needs keystore env vars)
"$GODOT" --headless --path . --export-debug "Android" build/gem-mines-debug.apk
"$GODOT" --headless --path . --export-release "Android AAB" build/gem-mines.aab
adb install -r build/gem-mines-debug.apk
```

**Before saying a task is done, run:**
1. The relevant GdUnit4 suites.
2. `python tools/crosscheck/run.py` for any generator you touched.
3. `python tools/ci/lint_content.py`.

Report results honestly. If something fails or couldn't be run, say so.

---

## Architecture essentials

### Autoloads (singletons)

| Autoload | Responsibility |
|---|---|
| `Text` | Looks up line IDs, fills number placeholders, returns display text for speech bubbles and prompts |
| `Narration` (Phase 3) | Plays line IDs with params; splices number clips; emits `word_spoken(index)` for highlighting; replay button; respects the profile's read-aloud setting |
| `SaveSystem` | Atomic JSON saves to `user://` (write `.tmp`, then rename; keep `.bak`); `schema_version`; migrations |
| `Profiles` | Active child profile (up to 4 per device, from Phase 3) |
| `Adaptive` | BKT state per skill, next-problem selection, spaced review, hint ladder, placement |
| `Rewards` | Coins, gems, inventory, badges, lantern streak, family reward points |
| `InputRouter` | Maps touch, pen, mouse and keyboard to the same game actions; handles palm rejection during pen strokes |
| `UI` | DPI-aware sizing (`min_target_px()`), theme, posture/aspect handling |

Scenes talk to autoloads through **signals and methods**, never by reaching into each other's nodes. Keep game logic out of scene scripts where possible: scene scripts handle presentation, and `scripts/` holds testable logic.

### Problem generators (`scripts/generators/`)

- **Pure functions with no nodes or globals:**
  ```gdscript
  static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
  ```
- **Always use the passed-in `rng`.** Never call global `randi()`, so tests are reproducible by seed.
- **A `Problem` contains:** `skill_id`, `prompt_line_id`, `prompt_params`, `answer` (a canonical value), `answer_modes`, `distractors`, `representation` (concrete/pictorial/abstract) and `hint_steps`.
- **Distractors** come from named misconceptions, such as `digit_swap` (34 → 43) or `forgot_regroup`. They must never equal the answer, and there are no duplicates.
- **New generator checklist:**
  1. Write a GdUnit4 test with fixed seeds and edge cases.
  2. Write a separate Python checker in `tools/crosscheck/` that recomputes answers from the exported problem JSON.
  3. Add the skill entry in `curriculum/skills/`.
  4. Add text lines.

### Curriculum (`curriculum/skills/*.json`)

- **Skill IDs** use the format `topic.subtopic.action`, e.g. `pv.tens_ones.build`.
- **Prerequisites must form a directed acyclic graph** (no cycles); a test enforces this.
- **Changing prerequisites or removing skills needs Spiro's sign-off** (the math reviewer checks the curriculum). Note it in `docs/decisions.md`.

### Adaptive engine (`scripts/adaptive/`)

- **Bayesian Knowledge Tracing per skill:** prior, learn, guess, slip. Defaults by skill type are in `curriculum/bkt_defaults.json`. Fitted values come from `tools/bkt/fit.py`, run offline only.
- **Mastery:** P(L) ≥ 0.95 **and** correct answers on 2 or more distinct days. Math-fact skills also have a median-latency fluency check, which is never shown to the child.
- **Evidence rules:**
  - Hint-assisted answers count as partial evidence.
  - A handwriting answer recognized with low confidence that the child rejects ("No, try again") is **not** an incorrect attempt.
- **Selection:** only frontier skills (all prerequisites mastered); about 70% new practice and 30% spaced review (intervals of 1, 3, 7, 21 and 60 days); interleave 2–3 skills.
- **Don't change mastery thresholds or defaults without asking.** Simulated-learner tests in `tests/adaptive/` must keep passing:
  - A random guesser never masters anything.
  - A fast learner can test out of a skill via the Challenge Door.

### Handwriting (`scenes/input/chalk_slate/`, `scripts/input/`)

- **One digit per box**, as many boxes as the answer has digits. A `Recognizer` returns `{digit, confidence, mirrored, mirrored_confidence}` per box (`digit` -1 means nothing to read).
- **Confidence below the slate's threshold (0.9):** Bolt confirms ("Did you write 47?"). "Try again" is logged as `low_confidence_rejected` and is **never** an incorrect attempt: `Adaptive.record` returns before BKT.
- **Recognition runs in GDScript** (`StrokeRaster` makes the 28x28 picture, `DigitNet` reads it). `tools/handwriting/raster.py` and `stroke_raster.gd` must stay identical in behavior; the fixtures in `tests/handwriting/fixtures/` check it. Retrain with `tools/handwriting/train.py`, then rerun `make_fixtures.py`.
- **Unavailable** (no touch screen, weights missing, or switched off in the parent area): `AnswerPanel` shows the `NumberPad` instead, silently. `FakeRecognizer` is the stub for tests.
- **Strokes** live in memory only while the child can see them and are discarded on submit or erase. Nothing saves a stroke except the debug-build capture screen (parent area, `StrokeCapture`), which writes stroke JSON to `user://capture/` for measuring the network.
- **Palm rejection** lives only in `InputRouter` (`stroke_*` signals, `pen_stroke_active`).

### Save system

- Every save includes `schema_version`.
- Any change to the saved structure needs a migration in `scripts/save/migrations/` plus a test that loads a fixture from every previous version (`tests/save/fixtures/`).
- **Never break an existing save.**
- **Save points:** after every rock, on posture change, and on `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_WM_CLOSE_REQUEST`; also after every crafted recipe and finished build step.
- **Cross-device:** a parent exports and imports a progress file. `SaveMerge.choose` is the rule (newer wins; older asks; same moment keeps ours); an import that replaces the save writes `backups/` first (newest 5). Exports carry a checksum. Device-only state (the device id, volumes, the import/export log) stays outside the child's save.

---

## Device and input requirements

- **Primary devices:**
  - **ARM 2-in-1 Chromebook** in laptop (trackpad and keyboard), tent (touch) and tablet (touch and stylus) postures, switching mid-session.
  - **Android tablet:** touch, maybe a stylus.
- **Also supported (public release):** Intel/AMD Chromebooks, **mouse-only Chromebooks** (every interaction must work with click and drag), smaller tablets.
- **Layout:**
  - Landscape only. Design for 16:9, 16:10, 3:2 and 4:3.
  - Use anchors and containers, not absolute positions.
  - Test window resize.
- **No multi-finger gestures.** Drag-and-drop must work identically with finger, pen and mouse (through `InputRouter`).
- **Performance:**
  - 60 fps on mid-range hardware.
  - No allocations in `_process` hot paths; use texture atlases; OGG audio.
  - Download under 150 MB.

---

## Workflow

- **Read first:** before a non-trivial change, read the relevant section of `docs/development-plan.md` and `docs/decisions.md`.
- **Small, reviewable changes.** One backlog item per branch: `feat/z1-regrouping-generator`, `fix/slate-palm-rejection`.
- **Commit messages:** `type(scope): summary`. Types are feat, fix, test, refactor, content, docs, chore. Example: `feat(generators): add regrouping within 100`.
- **Test-first** for generators, the adaptive engine and save migrations.
- **Hand-editing `.tscn` and `.tres` files:**
  - Keep `ext_resource` and `sub_resource` IDs consistent, and never invent or alter `uid://` values.
  - Prefer building complex UI in code or small focused scenes.
  - After editing, run `--import` and the tests to confirm the scene loads.
- **Record decisions:** any architectural choice goes in `docs/decisions.md` as date, decision, why, alternatives.
- **Ask Spiro before:**
  - Adding dependencies or plugins.
  - Changing the save schema, BKT thresholds or curriculum prerequisites.
  - Running paid API calls (voice generation).
  - Upgrading Godot.
  - Changing export or permission settings.
  - Anything touching `private/`.
- **Definition of done:**
  1. Works on the 2-in-1 (all postures) and the tablet with touch and stylus, and with mouse/keyboard where relevant.
  2. All child-facing text comes from the text table (and, from Phase 3, is narrated).
  3. Generators pass the tests and the cross-check.
  4. Saves survive app close and update.
  5. Lint passes.
  6. Tests pass.

## Current phase

**Phase 2 (Version 1.0) is built in code; Phase 3 (public release readiness, Sprints 22-28, Apr 12 - May 28, 2027; `docs/phases/phase-3-public-release-readiness.md`) is next.** Phase 2 status per sprint: `docs/phases/phase-2-version-1-0.md` ("Status"); retrospective: `docs/phases/phase-2-retrospective.md`.

Built in Phase 2 (Sprints 12-21), on top of the MVP:

- **Handwriting:** the digit network in GDScript, `ChalkSlate`, palm rejection, "Did you write 47?" (logged as `confirmed`), numeral coaching.
- **Zones 4 and 5:** 27 skills (72 in all), every generator cross-checked; `BoulderSplit`, `SieveGrid`, `FactorTree`; rare gems from rare numbers.
- **Workshop (Sprint 16):** crafting bench (`curriculum/recipes.json`), build site and build runner (`curriculum/builds.json`); the balance elevator opens Zone 4 (`Scheduler.locked_zones`).
- **Cross-device (Sprint 17):** save schema **v2** (one migration for every Phase 2 record), `SaveMerge` newest-wins with backups, a checksum, a random device id and an import/export log. Parent-managed files only; no accounts.
- **Motivation (Sprint 19):** badges (`curriculum/badges.json`), the Word Gems glossary (lint rule 11), the weekly Deep Dig, the Challenge Door, family reward points (`MotivationRules`).
- **Art and sound (Sprint 20):** no artist (Spiro's decision): Kenney CC0 packs plus code-drawn art (`docs/art/asset-inventory.md`), Bolt's six poses (`Bolt.set_pose`), synthesized music per zone group with a cross-fade.
- **Parent area (Sprint 21):** dashboard v2 (skill map, weekly summary), family rewards, the import/export log.

Left for Spiro, the devices and the math reviewer before the `v1.0.0` tag: `docs/qa/release-1.0.md` (device matrices, airplane mode, the release AAB, the Android version code and name) and `docs/reviews/2027-04-math-review.md` (human sign-off on Zones 1-5), plus the Phase 2 items marked "Needs Spiro" in `docs/decisions.md` (Charlie's logs and the decision gate, his digits, the Zone 4 and 5 prerequisites, the MNIST licence).

**Next:** Sprint 22 (AI-voice narration; paid API calls need Spiro's go-ahead), then profiles and read-aloud, compliance, broad devices, the store listing and the closed test. The Phase 3 profiles change is a v2-to-v3 save migration. Zones 6-12 and Scholar mode stay out of scope until Phase 4. Don't build ahead of the current sprint; add ideas to the backlog instead.

Update this section at the start of each phase.
