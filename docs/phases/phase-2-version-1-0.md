# Phase 2: Version 1.0 (Sprints 12–21)

This document expands section 8.3 of the master plan (`docs/development-plan.md`) into an implementable plan. It assumes Phase 1 (`docs/phases/phase-1-ramp-up-to-mvp.md`) is complete and the MVP is installed on both of Charlie's devices. Phase 3 is described in `docs/phases/phase-3-public-release-readiness.md`.

Everything in this document is subordinate to `CLAUDE.md`. If a task here seems to require breaking a non-negotiable rule, stop and ask Spiro.

## Overview

| Item | Value |
|---|---|
| Phase | 2 of 5: Version 1.0 |
| Sprints | 12–21 (ten one-week sprints; Sprint 14 is 4 days for Presidents' Day) |
| Dates | Monday Feb 1, 2027 – Friday Apr 9, 2027 |
| Status | **Provisional.** Sprints 12–14 run regardless. Sprints 15–21 are confirmed at the decision gate. |
| Entry gate | MVP milestone (end of Sprint 11, Jan 29, 2027) |
| Decision gate | End of Sprint 14 (Friday Feb 19, 2027): continue / adjust / pause / stop |
| Milestone | **Version 1.0 (private)** on the Google Play internal testing track, end of Sprint 21 |

**Outcome.** At the end of Phase 2 Charlie can answer by writing digits with the stylus or a finger, dig through Zones 4 and 5 (multiplication and division facts, factors, multiples, prime and composite numbers, the Sieve of Eratosthenes, prime factorization, divisibility rules), craft tools and build mine-engineering projects between zones, move his progress between the 2-in-1 and the tablet, and earn his first mathematician badges and Word Gems. The MVP's placeholder art is replaced with commissioned art for Bolt and key screens. The game still contains no narration, profiles or public-release work: those are Phase 3.

**Out of scope for Phase 2** (do not build ahead; add ideas to the backlog):

- AI-voice narration and the voice pipeline (Phase 3, Sprint 22). Keep writing every line into `text/lines.csv` so narration is cheap later.
- Child profiles (Phase 3). The save file still holds exactly one child.
- Families Policy compliance work, privacy policy, store listing, closed test (Phase 3).
- Zones 6–12, Scholar mode, web export.
- Any live network feature. The Android export preset still does not request `INTERNET`.

## Status (2026-10-17)

Sprints 12 to 21 are **built in code** on the Phase 2 branch; what is left needs Charlie, the devices or a person (the math reviewer). Details and every deviation from this plan are in `docs/decisions.md` (one entry per sprint).

| Sprint | In code | Left for Spiro, the devices or a reviewer |
|---|---|---|
| 12-15 | BKT fit, handwriting, Zone 4, rare gems | Charlie's logs, his digits, the decision gate, Zone 4 sign-off |
| 16 | Crafting bench (4 recipes), build site, cart track, balance elevator (opens Zone 4), hub doors and machines | Weekend playtest of the elevator |
| 17 | Save schema v2, newest-wins import with backups and a checksum, device id, import/export log | The round trip on the real devices; the native picker on ChromeOS |
| 18 | Zone 5: 11 skills, 4 generators and checkers, sieve grid, factor tree, rare-gem museum cases | Zone 5 prerequisite sign-off; the sieve playtest |
| 19 | 4 badges, Word Gems glossary and lint rule, weekly Deep Dig, Challenge Door, family points | The first badge story with Charlie |
| 20 | No artist (Spiro): Bolt's poses from CC0 frames and tweens, zone art, synthesized music per zone, cross-fade, new sounds, aspect-ratio captures | Frame times on both devices (`docs/qa/perf-1.0.md`) |
| 21 | Dashboard v2, math review packet and AI pre-review, release checklist | Human math review, device matrices, the release AAB, the `v1.0.0` tag (`docs/qa/release-1.0.md`) |

Decisions made for this stretch (Spiro): one save migration (v1 to v2) for all Phase 2 records; no commissioned art; synthesized music; export/import only for cross-device; the Challenge Door's mastery path approved; Zone 5 prerequisites written provisionally.

## Entry criteria

Phase 2 starts only when the MVP acceptance criteria from the master plan hold:

1. Charlie can start and finish a 20-minute session on either device with no adult help.
2. Zero crashes across 5 consecutive playtest sessions.
3. Every Zone 1–3 generator passes its GdUnit4 suite and the Python cross-check (`python tools/crosscheck/run.py --all --n 10000`).
4. Progress survives closing the app, switching posture, restarting the device and installing an update over the previous build.
5. The parent dashboard's mastered-skill list matches an adult observer's judgment.

Also in place from Phase 1 and relied on here:

- Autoloads `Text`, `SaveSystem`, `Adaptive`, `Rewards`, `InputRouter`, `UI`.
- `scripts/core/` resource classes `Problem`, `Skill`, `Attempt`; the generator contract `static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem`.
- `scenes/input/NumberPad` and drag targets, routed through `InputRouter`.
- Save schema version 1 with the migration framework in `scripts/save/migrations/` and fixtures in `tests/save/fixtures/`.
- CI running `--import`, GdUnit4, pytest and `tools/ci/lint_content.py` on every merge.
- Parent-gated export of play logs (used in Sprint 12 for the first BKT fit and in Sprint 13 for the digit samples).

Decision-gate inputs gathered during Sprints 12–14 (from exported logs and the weekend playtests, never from the shipped app phoning home): days played per week, whether Charlie asks to play, mastered-skill count over time, and Spiro's own read on pace.

## Architecture and design

### A. Handwriting: chalk slate and digit recognition (Sprints 13–14)

**Design, from master plan 3.6 and 5.5.** One digit per box. The child writes each digit of the answer in its own box on a large chalk slate (tens box, ones box, and so on), which turns recognition into a 10-class problem and reinforces place value. Strokes are captured in Godot, recognized on the device, and discarded immediately after recognition. Handwriting images are never stored (CLAUDE.md rule 2).

**Components and paths.**

| Component | Path | Responsibility |
|---|---|---|
| Kotlin plugin | `android/plugins/digit_ink/` (Gradle project) | Runs the LiteRT digit model; exposes `recognize(strokes: Array, box_w: int, box_h: int) -> Dictionary`. Built to an AAR by `./gradlew assembleRelease`; copied by `python tools/ci/copy_plugin.py` into `addons/digit_ink/bin/`. |
| GDScript bridge | `addons/digit_ink/digit_ink.gd`, `addons/digit_ink/plugin.cfg`, `addons/digit_ink/bin/` | `class_name DigitInk`. Wraps `Engine.get_singleton("DigitInk")` when the Android plugin is present. Falls back to `FakeRecognizer` otherwise. |
| Recognizer interface | `scripts/input/recognizer.gd` | `class_name Recognizer`. Abstract base: `func recognize(strokes: Array[PackedVector2Array], box_size: Vector2i) -> Dictionary` returning `{"digit": int, "confidence": float}` (digit `-1` means nothing recognizable). Pure logic, no nodes. |
| Fake recognizer | `scripts/input/fake_recognizer.gd` | `class_name FakeRecognizer extends Recognizer`. Deterministic stub for the Windows editor and tests: returns a digit chosen by a debug setting or from stroke bounding-box heuristics, with a configurable confidence. |
| Chalk slate scene | `scenes/input/chalk_slate/chalk_slate.tscn` + `chalk_slate.gd` | Presentation only. One `DigitBox` child per digit of the expected answer. Emits `answer_submitted(value: int)` and `answer_rejected()`. |
| Digit box scene | `scenes/input/chalk_slate/digit_box.tscn` + `digit_box.gd` | Captures strokes inside its rect, draws them with `_draw()` (chalk look), emits `strokes_changed`. |
| Confirmation bubble | `scenes/input/chalk_slate/confirm_bubble.tscn` | Bolt asks "Did you write {n}?" with Yes / Try again targets (both at least `UI.min_target_px()`). |
| Model training | `tools/handwriting/` (Python 3.12) | `train.py`, `augment.py`, `export_litert.py`, `evaluate.py`. Trains the Option B model on MNIST/EMNIST digits with child-writing augmentation. |

**Scene tree for `chalk_slate.tscn`.**

```
ChalkSlate (Control)                       # chalk_slate.gd
├── Background (NinePatchRect)
├── Boxes (HBoxContainer)                  # one DigitBox per expected digit, built in code
│   ├── DigitBox (Control)                 # digit_box.gd, tens
│   └── DigitBox (Control)                 # ones
├── Guides (Control)                       # drawn baseline / midline per box
├── Buttons (HBoxContainer)
│   ├── ClearButton (TextureButton)
│   └── DoneButton (TextureButton)
└── ConfirmBubble (instance of confirm_bubble.tscn, hidden until needed)
```

The number of boxes comes from the problem: `Problem.answer_digits: int` (add to the `Problem` resource in Sprint 14; it is a derived field, not a save-schema change). Leading digits are never pre-filled.

**Signals and API (Godot 4 syntax, statically typed).**

```gdscript
# scenes/input/chalk_slate/chalk_slate.gd
class_name ChalkSlate
extends Control

signal answer_submitted(value: int)
signal answer_rejected()                # child tapped "Try again" on a confirmation
signal fell_back_to_number_pad()        # recognizer unavailable

@export var confidence_threshold: float = 0.85   # confirm below this; tune in Sprint 14

var _recognizer: Recognizer

func setup(answer_digits: int, recognizer: Recognizer) -> void
func clear() -> void
func _on_done_pressed() -> void         # recognizes every box, then confirms or submits
```

`InputRouter` gains pen awareness (Sprint 14):

```gdscript
# autoload/input_router.gd (additions)
signal stroke_started(pos: Vector2, pressure: float, is_pen: bool)
signal stroke_moved(pos: Vector2, pressure: float)
signal stroke_ended()

var pen_stroke_active: bool = false     # while true, ignore other touch indices (palm rejection)
```

Palm rejection: when a stroke starts from a pen event, `InputRouter` records the pen's touch index and drops `InputEventScreenTouch` / `InputEventScreenDrag` events from other indices until the stroke ends. Godot 4 reports pen pressure on `InputEventMouseMotion.pressure` and pen tilt on `InputEventMouseMotion.tilt`; whether ChromeOS delivers pen input as mouse-with-pressure or as touch was measured in Sprint 1 and recorded in `docs/decisions.md`. Read that entry before implementing. Verify in Godot docs: `InputEventMouseMotion.pen_inverted` and `pressure` exist in 4.7.

**Confidence handling.** If every box's confidence is at or above the threshold, the slate submits. If any box is below it, the confirmation bubble shows the recognized number. "Yes" submits; "Try again" clears only the low-confidence boxes and emits `answer_rejected`. A rejected recognition is **not** an incorrect attempt (CLAUDE.md, adaptive evidence rules): `Attempt.outcome` gets a new enum value `REJECTED_RECOGNITION` that `Adaptive` ignores for BKT updates and logs for the dashboard.

**Fallback.** `DigitInk.is_available() -> bool` returns false in the editor, on desktop, on mouse-only devices (no touch screen reported by `DisplayServer.is_touchscreen_available()`, verify in Godot docs) and if the plugin singleton is missing. The dig screen then shows `NumberPad` instead of the slate with no message to the child.

**Numeral-formation coaching (optional, parent setting, default off).** The plugin reports whether a digit matched better after horizontal mirroring (`"mirrored": bool`). If the same digit is mirrored 3 times in a session, Bolt shows a stroke-order animation (`scenes/input/chalk_slate/stroke_demo.tscn`, one `AnimatedSprite2D` per digit) once, never as a penalty.

**Option A vs Option B benchmark (Sprint 13).** Build the benchmark harness first, then the candidates.

| Item | Detail |
|---|---|
| Test set | MNIST test split (10,000) plus about 200 of Charlie's digits captured on the 2-in-1 with the stylus and about 100 with a finger, exported as stroke JSON from a parent-gated debug capture screen that exists only in debug builds. Stored in `private/handwriting/` (gitignored), never committed, never uploaded. |
| Rendering | Strokes are rasterized to 28×28 grayscale in `tools/handwriting/rasterize.py` identically for both options' evaluation and for the production path, so training and inference match. |
| Metrics | Top-1 accuracy overall and on Charlie's subset; false-wrong rate (recognizer confident and wrong); confirmation rate at the chosen threshold; latency on the tablet. |
| Target | At least **97% top-1** on the combined set including Charlie's digits, with low-confidence confirmation on. |
| Option A | ML Kit Digital Ink Recognition in a throwaway branch of the Kotlin plugin, for the benchmark only. It needs a one-time ~20 MB model download, meaning an `INTERNET` permission, and a third-party SDK to disclose: both are reasons it is the benchmark, not the default. |
| Option B (recommended) | A small CNN (two conv layers, about 100k parameters, under 1 MB as a LiteRT `.tflite`) trained in `tools/handwriting/train.py` with augmentation for wobbly strokes, rotation ±15°, scale and thickness variation, and mirrored digits labeled as their own class so the plugin can report `mirrored`. |

Adding LiteRT to the Kotlin plugin is a **new dependency**: ask Spiro before adding it, then record it in `docs/sdk-audit.md` with the version, data flow ("none; runs on device, no network") and license.

### B. Zone 4 (Factor Workshop) and Zone 5 (Prime Caverns) generators

Generators live in `scripts/generators/`, one file per skill family, as pure static functions using only the passed-in `rng`. Each skill is a JSON record in `curriculum/skills/z04_factor_workshop.json` and `curriculum/skills/z05_prime_caverns.json`, with IDs in the form `topic.subtopic.action`. The Phase 1 math reviewer checks both zones in Sprint 21.

**Zone 4 skill families and generators (Sprint 15).**

| Generator file | Skills (IDs) | Problem shape | Answer modes | Distractor misconceptions |
|---|---|---|---|---|
| `mult_facts.gd` | `mult.facts.0_5`, `mult.facts.6_10`, `mult.facts.mixed` | `{a} × {b} = ?` with an array picture in the concrete representation | tap (choices), number pad, handwriting | `off_by_one_group` (a×(b±1)), `added_instead` (a+b), `digit_swap` |
| `div_facts.gd` | `div.facts.by_2_5`, `div.facts.by_6_10`, `div.sharing.equal_shares` | `{n} ÷ {b} = ?` as sharing gems into equal carts | tap, number pad, handwriting | `multiplied_instead`, `off_by_one`, `remainder_ignored` (for later skills only) |
| `factors.gd` | `fac.list.find_all`, `fac.pairs.rectangles`, `fac.check.is_factor` | "Which numbers are factors of {n}?" (tap all), "Build every rectangle with {n} blocks" (drag) | tap-multi, drag | `multiple_not_factor`, `missing_one_and_n`, `skip_middle_pair` |
| `multiples.gd` | `mul.list.first_k`, `mul.check.is_multiple`, `mul.common.first` | "Load the cart with the next 3 multiples of {b}" | drag, tap | `off_by_b`, `factor_not_multiple` |
| `prime_composite.gd` | `prime.classify.single`, `prime.classify.set`, `prime.explain.factor_pairs` | "Is {n} unbreakable?" (prime) or "Which of these rocks are unbreakable?" | tap, tap-multi | `odd_means_prime`, `one_is_prime`, `two_is_not_prime`, `square_is_prime` |

**"Split the boulder" mechanic (Sprint 15).** A composite rock shows its value. The child drags the pickaxe to a split point on a factor rail (`scenes/mine/boulder_split/boulder_split.tscn`), choosing a factor pair; the boulder cracks into two rocks that can be split again. A prime rock cannot be split: the pickaxe bounces, Bolt says "{n} is a prime. It won't break!" (line ID `z4.split.prime_bounce`) and the rock becomes a gem. This scene is the first piece of Zone 5's factor trees, so build it as a reusable `BoulderSplit` node with:

```gdscript
class_name BoulderSplit
extends Control

signal split_chosen(value: int, factor_a: int, factor_b: int)
signal prime_declared(value: int)

func setup(value: int, allowed_factors: Array[int]) -> void
```

**Zone 5 skill families and generators (Sprint 18).**

| Generator file | Skills (IDs) | Problem shape | Answer modes | Distractor misconceptions |
|---|---|---|---|---|
| `sieve.gd` | `sieve.mark.multiples_of`, `sieve.find.primes_to_50`, `sieve.find.primes_to_100` | Interactive grid (`scenes/zones/z05_prime_caverns/sieve_grid.tscn`): "Cross out every multiple of {p}" | tap-multi | `crossed_p_itself`, `missed_p_squared_start` |
| `factor_tree.gd` | `pf.tree.build`, `pf.list.write`, `pf.check.equal_products` | Build the factor tree of {n} by splitting until every leaf is prime; write the factorization | drag (reuses `BoulderSplit`), tap | `stopped_at_composite`, `missing_repeated_factor` |
| `divisibility.gd` | `div.rule.2_5_10`, `div.rule.3_9`, `div.rule.4_6`, `div.rule.mixed` | "Can {n} be shared evenly by {d}?" with a digit-sum picture for 3 and 9 | tap (yes/no), tap-multi | `last_digit_only_for_3`, `even_means_div_by_4` |
| `fta.gd` | `pf.fta.unique` | "Two miners factored {n}. Who is right?" (both trees shown; the one with all-prime leaves and matching product) | tap | `tree_with_composite_leaf`, `product_mismatch` |

**Rare gems from rare numbers (deterministic, CLAUDE.md rule 9).** `Rewards.gem_for_value(value: int) -> StringName` is pure and seedless:

| Number property | Gem | How to check |
|---|---|---|
| Composite | common gem by zone | not prime |
| Prime | `prime_gem` | `MathUtil.is_prime(n)` |
| Member of a twin-prime pair (p, p+2 both prime) | `twin_gem` (drops as a linked pair) | `is_prime(n) and (is_prime(n - 2) or is_prime(n + 2))` |
| Mersenne prime (3, 7, 31, 127, 8191) | `mersenne_gem` (legendary) | lookup table in `curriculum/rare_numbers.json` |
| Perfect square | `square_gem` | `int(sqrt(n))^2 == n` |

`scripts/core/math_util.gd` (`class_name MathUtil`) holds `is_prime`, `factors`, `prime_factorization`, `gcd` and `lcm` as static functions. The Python cross-checker must **not** import or port this file; it uses `sympy`-free, hand-written checks in `tools/crosscheck/zone4.py` and `tools/crosscheck/zone5.py`.

### C. Crafting and mine-engineering projects (Sprint 16)

**Paths.** `scenes/workshop/crafting/crafting.tscn`, `scenes/workshop/builds/build_screen.tscn` (framework), `scenes/workshop/builds/cart_track.tscn`, `scenes/workshop/builds/balance_elevator.tscn`, `curriculum/recipes.json`, `curriculum/builds.json`, `scripts/workshop/recipe.gd` (`class_name Recipe`), `scripts/workshop/build_project.gd` (`class_name BuildProject`).

**Recipe JSON schema** (`curriculum/recipes.json`):

```json
{
  "schema_version": 1,
  "recipes": [
    {
      "id": "tool.pickaxe.tier2",
      "name_line_id": "ws.recipe.pickaxe_tier2.name",
      "inputs": [{"gem": "garnet", "count": 12}],
      "math": {"skill_id": "mult.facts.0_5", "template_line_id": "ws.recipe.math.groups", "params": {"a": 3, "b": 4}},
      "output": {"type": "tool", "id": "pickaxe_tier2"},
      "unlock_after_skill": "mult.facts.0_5"
    }
  ]
}
```

A recipe is crafted only when the child answers its math line correctly ("3 garnets × 4 = enough for a lantern upgrade"). The math is a real problem from the named skill with fixed params, so it goes through `Adaptive` as evidence like any other attempt. Wrong answers cost nothing: the gems stay, Bolt starts the hint ladder.

**Build project JSON** (`curriculum/builds.json`): `id`, `zone_unlocks` (the zone this build opens), `steps[]` where each step is `{step_id, scene, problem: {skill_id, params}}`, `reward_line_id`. The build-screen framework (`build_screen.gd`) loads a `BuildProject`, instantiates each step scene in order, feeds it a `Problem`, and marks progress in the save. Completed machines stay visible in the hub and animate (electric motors and lanterns only, no steam or smoke).

**Hub changes.** `scenes/shell/hub.tscn` gets a Workshop door and a Build Site door. The zone map shows a locked zone with its build project's icon; completing the build unlocks the zone's first tunnel.

### D. Cross-device progress (Sprint 17)

Charlie plays on two devices. The MVP already has parent-gated export and import of a progress file. Phase 2 makes the round trip safe and easy.

**Approach to build: parent-managed export/import with "newest wins plus backup."**

- Export writes `gem-mines-progress-<device_id>-<iso_timestamp>.json` through the Android share sheet (Godot `OS.share` is not an API; verify in Godot docs whether 4.7 exposes a share intent, otherwise the Kotlin plugin exposes `share_file(path)`). Saving to a parent's Google Drive folder is the parent's choice in the share sheet; the game never calls a network API.
- Import reads a file picked with the system file picker (`DisplayServer.file_dialog_show`, verify in Godot docs for Android support in 4.7; otherwise add a `pick_file()` call to the Kotlin plugin).
- Merge rule: compare `saved_at` and `device_id`. If the imported save is newer, replace the local save after writing `user://save/backups/<timestamp>.json`. If it is older, offer "Keep this device's progress" (default) or "Use the imported file anyway." Never merge per skill; a partial merge is a decision for Spiro if the simple rule proves annoying.
- Every import and export is logged in the parent area.

**Decision for Spiro:** Google Play Games cloud saves would remove the manual step but is a Google SDK with an account sign-in, which conflicts with "no accounts" in CLAUDE.md rule 1 and complicates the Families Policy review. Recommendation: parent-managed export/import for 1.0; revisit in Phase 3 only if testers ask.

**Save schema change.** Adding `device_id`, `saved_at` and the import log is a schema change (version 2): ask Spiro first, add `scripts/save/migrations/v1_to_v2.gd`, and add the fixture `tests/save/fixtures/v1_full.json` plus a test that migrates every prior fixture.

### E. Long-term motivation (Sprint 19)

| Feature | Data | Scene | Rule |
|---|---|---|---|
| Mathematician badges | `curriculum/badges.json`: `id`, `name_line_id`, `story_line_ids[]` (a 30-second story in 4–6 lines, narrated from Phase 3), `portrait`, `unlock: {skills_mastered: [...]}` | `scenes/workshop/museum/badge_case.tscn` | First four: Eratosthenes (Zone 5 sieve), Euclid (Zone 4 factors), Gauss (Zone 2 sums), Sophie Germain (Zone 5 primes). Earned by mastery, never by chance. |
| Word Gems glossary | `curriculum/vocabulary.json`: `term`, `definition_line_id`, `picture`, `first_skill_id` | `scenes/workshop/museum/word_gems.tscn`; tappable terms already exist from Sprint 7 | A Word Gem is collected the first time its term appears in a mastered skill. |
| Weekly Deep Dig | `Adaptive.build_deep_dig(rng) -> Array[Problem]`: 10 problems sampled across all mastered skills, available once per calendar week | `scenes/mine/deep_dig/deep_dig.tscn` | Ends with one special gem. No timer. Missing a week does nothing. |
| Challenge Door | `Adaptive.challenge(skill_id) -> Array[Problem]` returns 3 problems at the skill's hardest params; 3 of 3 correct marks mastery with `evidence = "challenge"` | `scenes/zones/common/challenge_door.tscn` | Offered on frontier skills only. A miss is not recorded as a wrong attempt; the door closes until tomorrow. |
| Family reward points | `Rewards.family_points: int`, parent-defined goals in `curriculum`-free save data: `{goal_text, points_needed, claimed}` | parent area screen `scenes/shell/parent_area/family_rewards.tscn` | Points come from mastery and sessions completed, never from speed. Goal text is parent-typed, so a `LineEdit` is allowed here (parent area only). |

The Challenge Door's "3 of 3 marks mastery" interacts with BKT thresholds; it must keep the simulated-learner tests passing (a random guesser must not pass the door more than chance predicts across many runs, and the engine must still require 2 distinct days for ordinary mastery). Changing BKT thresholds themselves needs Spiro's approval.

### F. Art pipeline and polish (Sprints 15 brief, 20 integration)

- **No commission (Spiro, Sprint 20):** the CC0 placeholders (Kenney.nl) and code-drawn art are the Version 1.0 art. Every asset file has an entry in `assets/CREDITS.md` with source, license and URL; `tools/ci/lint_content.py` fails on an asset without one (add this check in Sprint 15).
- **Commission** (Sprint 15 brief): Bolt in 6 poses (idle, point, cheer, think, "not quite", wave), headlamp as a separate layer for color customization, hub key art, zone banners for Zones 1–5, the gem set (gems differ by shape as well as color). Deliverables as layered source plus PNG at 2× and 1×, packed into atlases by Godot's import (`AtlasTexture` via the editor's texture-atlas import, verify current 4.7 workflow in docs).
- **Integration** (Sprint 20): swap sprites behind the same scene node names so no scripts change; animation polish with `create_tween()` (squash and stretch on rock crack, gem arc into the cart); `GPUParticles2D` for sparkle, kept to one emitter per event; music via two `AudioStreamPlayer` nodes cross-fading, OGG only.
- **Accessibility pass** (Sprint 20): every interactive control at least `UI.min_target_px()`; color never the only clue; contrast of text on chalk and rock backgrounds checked; all four aspect ratios (16:9, 16:10, 3:2, 4:3) screenshot-tested.

### G. Parent dashboard v2 (Sprint 21)

`scenes/shell/parent_area/dashboard_v2.tscn`: a visual skill map (zones as rows, skills as nodes colored by BKT state: not started, practicing, mastered, needs review), a weekly summary (minutes, sessions, skills mastered, skills struggling, handwriting confirmation rate), and the import/export log. All values come from `Adaptive` and `Rewards` query methods added for this purpose; the dashboard never computes mastery itself.

## Sprint plan

### Sprint 12 (Feb 1–5): MVP feedback and tuning

**Goal.** Fix what the first weeks of real play showed, and fit BKT parameters from Charlie's exported logs for the first time.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S12-01 | `fix/mvp-playtest-batch-1` | Triage and fix the playtest issues logged over the holiday break and Sprints 10–11 | Every issue is closed or in the backlog with a sprint; no open crash |
| P2-S12-02 | `feat/bkt-fit-pipeline` | `tools/bkt/fit.py`: expectation-maximization fit of prior/learn/guess/slip per skill from an exported log; writes `curriculum/bkt_fitted.json` with per-skill sample counts | `pytest tools/bkt` passes on synthetic logs with known parameters (recovered within ±0.05); report printed for the real log |
| P2-S12-03 | `feat/adaptive-load-fitted` | `Adaptive` prefers `bkt_fitted.json` values when the skill's sample count is at least 30, else defaults | Unit test covers both branches; simulated-learner suite still passes |
| P2-S12-04 | `content/zone1-3-difficulty-tuning` | Adjust generator params ranges where the logs show ceiling or floor effects | Math reviewer not needed; cross-check re-run on touched generators |
| P2-S12-05 | `chore/debug-capture-screen` | Parent-gated, debug-build-only stroke capture screen writing stroke JSON to `user://capture/` for Sprint 13 | Capture works on the 2-in-1 with the stylus; file never leaves the device unless exported; stripped from release builds via a feature flag |

Implementation notes for the agent:

- Fitting runs offline only. The app never fits; it only loads `curriculum/bkt_fitted.json` at startup.
- Any change to mastery thresholds while tuning needs Spiro's approval; parameter *values* from the fit do not, but the fitted file is committed with the fit date in `docs/decisions.md`.
- Keep the capture screen behind `OS.is_debug_build()` and a project setting `gem_mines/debug/capture_enabled`.

Tests: `tests/adaptive/test_bkt_fit_loading.gd`; `tools/bkt/tests/test_fit.py` with synthetic learners; re-run `tools/crosscheck/run.py` for every generator whose params changed.

Weekend playtest: watch for the moment Charlie disengages; log the skill and representation on screen.

### Sprint 13 (Feb 8–12): Handwriting spike

**Goal.** Choose the recognizer (Option A vs B) using measurements, and have the Kotlin plugin skeleton building and loading in a debug APK.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S13-01 | `feat/digit-ink-plugin-skeleton` | Kotlin plugin `android/plugins/digit_ink/` exposing `is_available()` and `recognize()`; `addons/digit_ink/` bridge; `tools/ci/copy_plugin.py` | Debug APK on the tablet logs `DigitInk available: true`; editor logs `false` and uses `FakeRecognizer` |
| P2-S13-02 | `feat/handwriting-dataset` | `tools/handwriting/rasterize.py` and `dataset.py`: MNIST/EMNIST download at build time, plus the `private/handwriting/` loader for Charlie's ~200 stylus and ~100 finger digits | `pytest tools/handwriting` passes; the private loader is skipped when the directory is absent |
| P2-S13-03 | `feat/handwriting-model-b` | `train.py`, `augment.py`, `export_litert.py`: train the small CNN, export `.tflite` under 1 MB | `evaluate.py` reports top-1 on MNIST test and on Charlie's subset; the model loads in the plugin |
| P2-S13-04 | `spike/mlkit-benchmark` | Throwaway branch: ML Kit Digital Ink evaluated on the same rasterized set via the same harness | Numbers recorded in `docs/decisions.md`; branch deleted after the decision |
| P2-S13-05 | `docs/handwriting-decision` | Decision entry: chosen option, metrics, threshold, SDK audit entry | `docs/decisions.md` and `docs/sdk-audit.md` updated; Spiro approved the dependency |

Implementation notes for the agent:

- Ask Spiro before adding LiteRT (and ML Kit for the benchmark) to the Gradle project. Both are new dependencies.
- The plugin's `recognize()` takes strokes as normalized coordinates in the box (0–1) so the GDScript side owns no rasterization logic twice; the plugin rasterizes with the same algorithm as `rasterize.py` and a unit test in `android/plugins/digit_ink/src/test/` compares against fixtures generated by the Python script.
- The Godot Android plugin API in 4.x uses the v2 plugin format (a `GodotPlugin` subclass registered via `plugin.cfg` in `addons/`); verify the exact 4.7 packaging in the Godot docs before writing the Gradle config.
- Nothing from `private/` is ever read by CI. CI trains on MNIST only and asserts a lower accuracy bar (95%) so the pipeline stays tested.

Tests: Kotlin unit test for rasterization parity; `pytest tools/handwriting`; a GdUnit4 test that `DigitInk.is_available()` is false in headless mode and the fallback is `FakeRecognizer`.

Weekend playtest: Charlie writes 20 numbers on the capture screen with the stylus and 10 with a finger; no game change this weekend.

### Sprint 14 (Feb 15–19, 4 days): Handwriting feature and the decision gate

**Goal.** Ship the chalk slate as an answer mode for every skill whose record allows `handwriting`. Hold the decision gate on Friday.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S14-01 | `feat/chalk-slate-scene` | `ChalkSlate`, `DigitBox`, guide lines, chalk stroke rendering, Clear and Done | Works with finger and stylus on both devices; boxes at least 2 × `UI.min_target_px()` |
| P2-S14-02 | `fix/slate-palm-rejection` | `InputRouter` pen stroke tracking and palm rejection | Resting a palm while writing with the pen adds no strokes (manual test on the 2-in-1, logged) |
| P2-S14-03 | `feat/slate-confirmation` | Confidence threshold, "Did you write {n}?" bubble, `REJECTED_RECOGNITION` outcome ignored by BKT | GdUnit4 test: a rejected recognition leaves `P(L)` unchanged |
| P2-S14-04 | `feat/slate-dig-integration` | Dig screen chooses slate vs number pad from `Problem.answer_modes`, device capability and the parent setting | Mouse-only run of Zones 1–3 never shows the slate |
| P2-S14-05 | `feat/numeral-coaching` | Optional stroke-order demo on repeated mirrored digits (parent setting, default off) | Demo plays at most once per digit per session; never blocks submitting |
| P2-S14-06 | `content/slate-lines` | All slate and confirmation lines in `text/lines.csv` (`input.slate.*`) | `lint_content.py` passes; no hard-coded strings |
| P2-S14-07 | `docs/decision-gate-2027-02-19` | Decision-gate memo in `docs/decisions.md`: the four questions from the master plan with data | Spiro records continue / adjust / pause / stop |

Implementation notes for the agent:

- Chalk rendering uses `_draw()` with `draw_polyline` per stroke; cap stored points per stroke (about 256) by distance thresholding so `_process` never allocates in the hot path.
- Strokes are cleared from memory as soon as `recognize()` returns. No screenshot, texture or stroke list is saved anywhere (CLAUDE.md rule 2).
- Add `handwriting` to `answer_modes` in Zone 1–3 skill records only where the answer is a whole number of 1–3 digits. This is a curriculum data change that does not touch prerequisites, so it needs no sign-off, but note it in `docs/decisions.md`.

Tests: `tests/input/test_chalk_slate.gd` (box count from `answer_digits`, submit path, reject path, fallback path, all with `FakeRecognizer`); `tests/input/test_input_router_pen.gd` (synthetic pen plus touch events, palm events dropped); posture switch mid-stroke does not crash.

Weekend playtest (Friday is the gate; the playtest is the weekend before): Charlie answers 10 rocks by handwriting. Log confirmation count, misreads, and whether he prefers the pen or the pad.

### Sprint 15 (Feb 22–26): Zone 4, Factor Workshop

**Goal.** Zone 4 generators with cross-checks, the "split the boulder" mechanic, and the artist brief.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S15-01 | `content/z4-skill-map` | `curriculum/skills/z04_factor_workshop.json` (about 15 skills) with prerequisites into Zone 3 | DAG test passes; Spiro signs off on prerequisites |
| P2-S15-02 | `feat/generators-mult-div-facts` | `mult_facts.gd`, `div_facts.gd` with tests and `tools/crosscheck/zone4.py` | 10,000-problem cross-check passes per skill; distractors never equal the answer |
| P2-S15-03 | `feat/generators-factors-multiples` | `factors.gd`, `multiples.gd`, `MathUtil` | Same bar; `MathUtil` has its own unit tests up to 1,000 |
| P2-S15-04 | `feat/generators-prime-composite` | `prime_composite.gd` with the four named misconceptions | Same bar |
| P2-S15-05 | `feat/boulder-split-mechanic` | `BoulderSplit` scene and the factor-rail drag; prime bounce | Works with finger, pen and mouse drag through `InputRouter` |
| P2-S15-06 | `feat/rare-gems` | `Rewards.gem_for_value`, `curriculum/rare_numbers.json`, twin and Mersenne gem art placeholders differing by shape | Unit test over 1–10,000 against an independent Python list in `tools/crosscheck/rare_numbers.py` |
| P2-S15-07 | `content/z4-lines` | About 60 lines (`z4.*`) at Explorer reading level; new Word Gems: factor, multiple, prime, composite, array | Lint passes; Charlie reads 5 sample lines without help |
| P2-S15-08 | `docs/artist-brief` | `docs/art/bolt-brief.md` with poses, layers, formats, content rules copied from CLAUDE.md | Sent to the artist; quote recorded |
| P2-S15-09 | `chore/lint-asset-credits` | `lint_content.py` fails on an asset missing from `assets/CREDITS.md` | CI red on a test asset without a credit, green after |

Implementation notes for the agent:

- Multiplication is introduced through arrays and equal groups (Zone 3 already did equal groups), so the concrete representation for `mult.facts.*` renders an array of gems; the pictorial representation shows a skip-count number line; the abstract one shows the equation only.
- `prime.classify.*` ranges: start at 2–30, extend to 2–100 at the hardest params. Never present 1 as a candidate until `prime.explain.factor_pairs`, where "1 is not prime" is taught explicitly with a line and a Word Gem.

Tests: generator suites with fixed seeds and edge cases (n = 2, squares, 1 excluded); `tests/mine/test_boulder_split.gd`; `tests/rewards/test_rare_gems.gd`.

Weekend playtest: "split the boulder" with gray-box art. Is splitting fun? Does Charlie understand why a prime bounces?

### Sprint 16 (Mar 1–5): Crafting and engineering projects

**Goal.** The workshop crafts tools with math recipes, and the first two build projects unlock zones.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S16-01 | `feat/recipe-data` | `Recipe` resource, `curriculum/recipes.json` loader and validator (inputs exist, skill IDs exist) | Validator test fails on a bad recipe fixture |
| P2-S16-02 | `feat/crafting-screen` | `scenes/workshop/crafting/crafting.tscn`: recipe list, gem counts, math step through the dig problem panel, result animation | Crafting pickaxe tier 2 from 12 garnets works end to end; wrong answer keeps the gems |
| P2-S16-03 | `feat/build-framework` | `BuildProject`, `curriculum/builds.json`, `build_screen.tscn` step runner, progress saved per step | Resuming mid-build after app close returns to the same step |
| P2-S16-04 | `feat/build-cart-track` | Cart track build (Zone 1 → 2 gate retrofit, optional for Charlie since Zone 2 is open): lay track segments whose lengths add to the gap | Completed track animates carts in the hub |
| P2-S16-05 | `feat/build-balance-elevator` | Balance-scale elevator (Zone 3 → 4 gate): balance counterweights using equal groups | Completing it unlocks Zone 4's first tunnel |
| P2-S16-06 | `content/workshop-lines` | `ws.*` lines, Word Gem "recipe" | Lint passes |

Implementation notes for the agent:

- Build progress and crafted tools extend the save. Combine with Sprint 17's schema change into a single version-2 migration if both land in the same release; otherwise version 2 now and version 3 next sprint. Ask Spiro either way.
- Machines in the hub are `AnimatedSprite2D` or tween loops started only when the hub is visible; stop them on `NOTIFICATION_APPLICATION_PAUSED` to save battery.
- The build-screen framework must not know specific builds: each step scene implements `func setup(problem: Problem) -> void` and emits `step_completed()`.

Tests: `tests/workshop/test_recipe_validation.gd`, `tests/workshop/test_build_progress.gd` (save and resume between steps), crafting wrong-answer test (inventory unchanged).

Weekend playtest: the balance elevator. Does Charlie connect "equal groups" to balance?

### Sprint 17 (Mar 8–12): Cross-device progress

**Goal.** Charlie's progress moves between the 2-in-1 and the tablet through a parent-managed file with newest-wins and a backup.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S17-01 | `feat/save-schema-v2` | `device_id`, `saved_at`, `import_log[]`; migration and fixtures | Every fixture in `tests/save/fixtures/` migrates and loads |
| P2-S17-02 | `feat/progress-export-share` | Export through the Android share sheet (plugin call if Godot lacks one), filename with device and timestamp | File appears in the parent's chosen app; nothing sent by the game itself |
| P2-S17-03 | `feat/progress-import-picker` | System file picker, validation (schema, checksum), newest-wins with backup, "keep this device's progress" choice | Import of a corrupted file is refused with a parent-facing message and no state change |
| P2-S17-04 | `feat/import-log-dashboard` | Parent area shows the import/export log | Visible after one round trip |
| P2-S17-05 | `docs/cross-device-decision` | Record the export/import vs Play Games decision | `docs/decisions.md` entry with alternatives |

Implementation notes for the agent:

- Write the merge rule as a pure function `SaveMerge.choose(local: Dictionary, imported: Dictionary) -> Dictionary` in `scripts/save/save_merge.gd` so it is testable without devices.
- Keep `device_id` as a random UUID generated on first run and stored in the save; it is not a hardware identifier (no advertising ID, no serial).
- Backups: keep the last 5 in `user://save/backups/`, prune older ones.

Tests: `tests/save/test_migrations.gd` (all fixtures), `tests/save/test_save_merge.gd` (newer wins, older prompts, equal timestamps keep local, missing fields refused), device round trip (manual, logged on Friday).

Weekend playtest: none required; Charlie plays Zone 4 on the tablet after an import from the 2-in-1.

### Sprint 18 (Mar 15–19): Zone 5, Prime Caverns

**Goal.** Zone 5 generators, the interactive sieve, factor trees built on `BoulderSplit`, divisibility rules, and rare-gem drops in play.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S18-01 | `content/z5-skill-map` | `curriculum/skills/z05_prime_caverns.json` (about 12 skills) | DAG test passes; Spiro signs off |
| P2-S18-02 | `feat/generators-sieve` | `sieve.gd` and `tools/crosscheck/zone5.py` sieve section | Cross-check passes for every `p` up to 10 and grids to 100 |
| P2-S18-03 | `feat/sieve-grid-scene` | `sieve_grid.tscn`: tap to cross out, with the already-crossed state remembered within a tunnel | Each cell at least `UI.min_target_px()` on a 10×10 grid at 4:3 |
| P2-S18-04 | `feat/generators-factor-tree` | `factor_tree.gd`, tree validation (all leaves prime, product equals n) | Cross-check recomputes factorizations independently |
| P2-S18-05 | `feat/factor-tree-scene` | Tree built with repeated `BoulderSplit` nodes; leaves become gems | Trees for n ≤ 100 fit on screen at every aspect ratio |
| P2-S18-06 | `feat/generators-divisibility` | `divisibility.gd` with digit-sum pictures | Cross-check passes |
| P2-S18-07 | `feat/generators-fta` | `fta.gd` "who is right?" problems | Cross-check passes |
| P2-S18-08 | `feat/rare-gem-drops` | Twin and Mersenne gems drop in Zone 5 tunnels; museum cases for them with fun facts | Charlie can earn 127 as a legendary gem by factoring or classifying it |
| P2-S18-09 | `content/z5-lines` | `z5.*` lines; Word Gems: sieve, prime factorization, divisible | Lint passes |

Implementation notes for the agent:

- Sieve grid cells update a `PackedByteArray` state and redraw only changed cells; no per-frame allocation.
- Factor-tree problems choose `n` with at most 4 prime factors at the hardest params so trees stay shallow for a 6–7-year-old.
- The Fundamental Theorem of Arithmetic is named in a line ("Every number has exactly one prime recipe. That's the Fundamental Theorem of Arithmetic.") and added as a Word Gem.

Tests: generator suites; `tests/zones/test_sieve_grid.gd`; `tests/zones/test_factor_tree_scene.gd` (tree completion signal fires only when all leaves are prime).

Weekend playtest: the sieve. Does crossing out feel like digging or like homework? Adjust sounds and particles before Sprint 20 if it feels flat.

### Sprint 19 (Mar 22–26): Long-term motivation

**Goal.** Badges, Word Gems glossary, weekly Deep Dig, Challenge Door, family reward points.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S19-01 | `feat/badges` | `curriculum/badges.json`, unlock evaluation in `Rewards`, badge case scene, 4 stories as lines | Each badge unlocks from mastery only; stories pass the lint |
| P2-S19-02 | `feat/word-gems-glossary` | Glossary scene reading `curriculum/vocabulary.json`; collection on first mastered use | Every term used in Zones 1–5 lines exists in the vocabulary file (lint check) |
| P2-S19-03 | `feat/deep-dig` | `Adaptive.build_deep_dig`, weekly availability, special gem | Deterministic given seed and mastered set; unavailable twice in one week |
| P2-S19-04 | `feat/challenge-door` | `Adaptive.challenge`, door scene, mastery with `evidence = "challenge"` | Simulated-learner tests pass with the door enabled |
| P2-S19-05 | `feat/family-reward-points` | Points accrual, parent goals screen (parent area), claim flow | Points never increase from speed; claiming is parent-gated |
| P2-S19-06 | `content/motivation-lines` | `badge.*`, `glossary.*`, `deepdig.*`, `door.*`, `family.*` lines | Lint passes |

Implementation notes for the agent:

- Badges, points and door results extend the save: fold into one migration (version 3) with Spiro's approval.
- The Deep Dig's weekly key is the ISO week of the device clock; a clock set backwards cannot grant a second Deep Dig (store the last completed week key).
- The Challenge Door never shows a countdown; the three problems are presented like any rocks.

Tests: `tests/adaptive/test_challenge_door.gd` (random guesser pass rate over 10,000 simulated doors stays under 2%, which is roughly chance for 3 problems with 4 choices; a fast learner passes within 2 doors), `tests/adaptive/test_deep_dig.gd`, `tests/rewards/test_badges.gd`, vocabulary lint test.

Weekend playtest: the first badge story. Does Charlie listen or read it to the end? (It is text in Phase 2; the length check matters for narration in Phase 3.)

### Sprint 20 (Mar 29–Apr 2): Art and polish

**Goal.** Bolt's poses and key art (from CC0 packs and code: no commission, Spiro's decision), art pass on Zones 1–5, music, animation and particle polish, accessibility pass.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S20-01 | `content/art-bolt` | Bolt poses and headlamp layer replace placeholders; customization recolors the layer | No script changes; customization still works |
| P2-S20-02 | `content/art-zones-1-5` | Zone banners, rock and gem sprites, hub key art; atlases | Draw calls per screen measured and recorded; 60 fps on both devices |
| P2-S20-03 | `content/music-sfx` | Licensed music per zone group, SFX for crack, gem, split, sieve; cross-fade | Licenses in `assets/CREDITS.md`; OGG only; loudness normalized with ffmpeg |
| P2-S20-04 | `feat/animation-polish` | Squash and stretch, gem arc, cart bounce, Bolt reactions via tweens | No new `_process` allocations (profiler check) |
| P2-S20-05 | `feat/accessibility-pass` | Target sizes, contrast, shape-coded gems, four aspect ratios | Screenshot set per ratio committed under `docs/qa/screens-1.0/` |
| P2-S20-06 | `fix/polish-batch` | Feel issues from Sprints 15–19 playtests | Backlog empty of "feel" items tagged 1.0 |

Implementation notes for the agent:

- Keep the scene node names stable so art swaps are data changes.
- Particles: one `GPUParticles2D` per effect type, pooled and reused; check that the GL Compatibility renderer path handles them on the ARM Chromebook.
- Explain tweens in the summary for Spiro if this is the first sprint using them heavily (a tween animates a property from A to B over time without a per-frame script).

Tests: performance capture on both devices (frame time graph from the Godot profiler, recorded in `docs/qa/perf-1.0.md`); existing suites stay green.

Weekend playtest: the full loop with real art. Watch Charlie's reaction to Bolt.

### Sprint 21 (Apr 5–9): Version 1.0 hardening

**Goal.** Parent dashboard v2, math-reviewer sign-off on Zones 1–5, performance and migration tests, Version 1.0 on internal testing.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P2-S21-01 | `feat/dashboard-v2` | Visual skill map, weekly summary, import/export log | Matches `Adaptive` state in a seeded fixture test |
| P2-S21-02 | `docs/math-review-z1-5` | Reviewer session on Zones 1–5 wording and samples; fixes applied | Reviewer's notes in `docs/reviews/2027-04-math-review.md`; all blocking notes fixed |
| P2-S21-03 | `test/save-migration-matrix` | Install the MVP build, play, update to 1.0, verify; repeat from every tagged release | Checklist in `docs/qa/release-1.0.md` completed on both devices |
| P2-S21-04 | `test/posture-and-input-matrix` | Every screen with touch only, stylus only, mouse and keyboard; all three postures | Checklist completed; defects fixed or deferred with Spiro's okay |
| P2-S21-05 | `chore/release-1.0-internal` | Release-signed AAB to internal testing; installed on both devices; tag `v1.0.0` | Charlie plays a full session on his own on each device |
| P2-S21-06 | `docs/phase-2-retrospective` | Retrospective and the updated "Current phase" section of `CLAUDE.md` for Phase 3 | Merged |

Implementation notes for the agent:

- Do not change export or permission settings for the release without Spiro; the preset still has no `INTERNET`.
- Run the full checklist from `CLAUDE.md` "Before saying a task is done" on the release commit and paste the output into the release notes.

Tests: everything; plus airplane-mode full session on both devices.

Weekend playtest: Version 1.0 free play, observed by the second adult.

## Testing and quality

| Area | Phase 2 tests |
|---|---|
| Handwriting accuracy | `tools/handwriting/evaluate.py` reports top-1, per-digit confusion, false-wrong rate and confirmation rate on MNIST test plus Charlie's private set (skipped in CI). Gate: ≥ 97% combined, false-wrong ≤ 1% at the chosen threshold. Re-run whenever the model or rasterizer changes. |
| Handwriting behavior | GdUnit4 with `FakeRecognizer`: box count, submit, confirm, reject (no BKT change), fallback on unavailable plugin, palm rejection with synthetic events. Manual: stylus and finger on both devices every Friday. |
| Generators Zones 4–5 | Fixed-seed GdUnit4 suites with edge cases; `tools/crosscheck/zone4.py` and `zone5.py` recompute every answer from exported JSON for 10,000 problems per generator; distractor uniqueness and inequality asserted. Checkers share no code with `MathUtil`. |
| Rare numbers | Independent prime, twin-prime and Mersenne lists in `tools/crosscheck/rare_numbers.py` compared to `Rewards.gem_for_value` for 1–10,000. |
| Adaptive engine | Simulated learners (fast, average, slow, random guesser, forgetter) with the Challenge Door and Deep Dig enabled; fitted-parameter loading branches. |
| Save system | Fixture per schema version (v1, v2, v3) migrated in tests; merge-rule unit tests; manual update-over-old-build on both devices; mid-build and mid-dig close and resume. |
| Cross-device | Round trip 2-in-1 → tablet → 2-in-1 with a backup verified; corrupted and older files refused or prompted. |
| Devices and posture | Laptop, tent and tablet postures; mid-session switching during a slate stroke, a drag and a build step; tablet with and without stylus; mouse-only run of every new screen (slate never appears). |
| Performance | 60 fps on both devices with real art; no `_process` allocations in the dig, sieve and slate scenes (profiler); download under 150 MB after art and music. |
| Content | `lint_content.py` with the new asset-credit and vocabulary checks; reading-level spot check of every new line with Charlie. |

## Exit criteria

Version 1.0 (private) is accepted when all of the following hold:

1. Charlie can answer by handwriting on both devices; misreads trigger confirmation; a rejected recognition never counts against him; the number pad appears automatically where handwriting is unavailable.
2. Zones 4 and 5 are playable end to end; every generator passes its GdUnit4 suite and the independent cross-check; the math reviewer has signed off on Zones 1–5.
3. Crafting and both build projects work, persist across app close, and unlock zones as designed.
4. Progress round-trips between the two devices with newest-wins and a verified backup.
5. Badges, Word Gems, Deep Dig, Challenge Door and family reward points are live and earned from mastery and effort only.
6. Bolt's six poses and the key art are integrated (CC0 and code-drawn; no commission); 60 fps on both devices; download under 150 MB.
7. Every save from every tagged release migrates to 1.0 in automated tests and on a real device.
8. Zero crashes across 5 consecutive playtest sessions on the 1.0 build; airplane-mode session passes.
9. Every child-facing string comes from `text/lines.csv`; lint and all test suites pass on the release commit.
10. The Android preset still requests no `INTERNET` permission and no new SDK exists without an entry in `docs/sdk-audit.md`.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Recognizer below 97% on Charlie's digits | Medium | High: handwriting frustrates him | Per-digit boxes; augmentation for child writing; confirmation prompt; the number pad always available; a second training round in Sprint 14 with the Sprint 13 weekend samples |
| ChromeOS delivers pen events in an unexpected way (as touch, no pressure) | Medium | Medium | Sprint 1 findings in `docs/decisions.md`; palm rejection tested on the real 2-in-1 before the gate; worst case, pen is treated as a finger |
| Decision gate says "adjust" mid-phase | Medium | Medium | Sprints 15–21 are each one backlog theme; reorder or drop without rework because generators, builds and rewards are data-driven |
| ~~Commissioned art is late~~ | n/a | n/a | No commission (Spiro, Sprint 20): CC0 packs and code-drawn art |
| Save migrations break an old device | Low | High | Fixture per version; manual update-over-old-build on both devices every release; backups before import |
| Two devices diverge and newest-wins loses work | Medium | Medium | Backup before replace; "keep this device" choice; import log in the parent area |
| Zone 4–5 math too abstract for age 6–7 | Medium | Medium | Concrete representations first (arrays, rectangles, boulder splitting); BKT gates depth; Challenge Door lets him skip only by proving it |
| Scope creep from fun ideas (more machines, more gems) | High | Medium | Backlog, not sprint; machines and gems are data entries for later |
| Google Android plugin packaging changes between Godot minor versions | Low | Medium | Pinned Godot 4.7.2 in `.godot-version`; verify plugin format against the docs for that version |

## Decisions for Spiro

1. **Recognizer:** Option B (own LiteRT digit model, bundled, offline, under 1 MB) vs Option A (ML Kit). Recommendation: Option B unless it misses 97% on Charlie's digits after the Sprint 14 retrain; ML Kit's one-time download would require `INTERNET` and an SDK disclosure.
2. **LiteRT dependency** in the Kotlin plugin (and ML Kit for the benchmark branch only). Recommendation: approve LiteRT; approve ML Kit for the spike branch and delete the branch afterward.
3. **Cross-device approach:** parent-managed export/import vs Google Play Games cloud saves. Recommendation: export/import for 1.0; cloud saves conflict with the no-accounts rule.
4. **Save schema versions:** one migration per sprint (v2 in Sprint 17, v3 in Sprint 19) or fewer, larger migrations. Recommendation: one per sprint; each is small and fixture-tested.
5. **Curriculum prerequisites** for Zones 4 and 5 (sign-off in Sprints 15 and 18).
6. **Challenge Door mastery evidence** (3 of 3 at hardest params counts as mastery without the 2-distinct-days rule). Recommendation: approve, since the simulated random guesser stays under chance and the master plan calls for it.
7. ~~**Artist commission** scope and budget (Sprint 15 brief).~~ Decided: no commission.
8. **Music and SFX pack licenses** (Sprint 20) confirmed for distributed-app use.
9. **Decision gate outcome** on Feb 19, 2027.

## Hand-off to Phase 3

Phase 3 (narration, profiles, compliance, broad devices, store listing, closed test, launch) needs the following in place at the end of Sprint 21:

- **Every line** for Zones 1–5, the workshop, builds, badges, glossary, Deep Dig, Challenge Door and the slate in `text/lines.csv` with stable IDs and `{n}`-style placeholders, so Sprint 22 can generate audio for all of it in one batch. Badge stories kept to 4–6 short lines each.
- **Numbers in lines are always placeholders**, never baked in, so number-clip splicing works.
- **Save schema** at version 3 with migrations and fixtures, ready for a version-4 profiles migration in Sprint 23 (profiles will wrap the current single-child state; design the v3 structure so the child state is one sub-dictionary).
- **SDK audit** current: LiteRT entry (and nothing else new), no `INTERNET` permission, data flows documented for the Families Policy work in Sprint 24.
- **Input abstraction** complete: every screen works with touch, pen, and mouse-plus-keyboard through `InputRouter`, with the slate automatically hidden on mouse-only devices, so Sprint 25's mouse-only Chromebook path is verification rather than new work.
- **Art and credits** complete for Zones 1–5 with `assets/CREDITS.md` entries, so the Sprint 26 store listing can use real screenshots.
- **Parent dashboard v2** and the parent area ready to gain profile switching and the read-aloud setting.
- **`CLAUDE.md` "Current phase"** updated to Phase 3 with its scope and out-of-scope list; `docs/decisions.md` carries the handwriting, cross-device, schema and Challenge Door decisions.
