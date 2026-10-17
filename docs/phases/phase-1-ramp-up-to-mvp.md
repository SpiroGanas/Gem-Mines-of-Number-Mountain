# Phase 1: Ramp-up to MVP

Master plan: `docs/development-plan.md` (sections 8.2, 3, 5, 6, 9). Conventions and rules: `CLAUDE.md`. Next phase: `docs/phases/phase-2-version-1-0.md`.

## Overview

| Item | Value |
|---|---|
| Phase | 1 of 5 |
| Sprints | 1–11 (one week each; Sprint 4 is 3 days, Sprint 10 is 4 days) |
| Dates | Mon Nov 2, 2026 – Fri Jan 29, 2027, with a holiday break Dec 21 – Jan 1 |
| Status | **Committed** |
| Milestone | **MVP** at the end of Sprint 11 (Friday, January 29, 2027) |
| Entry gate | Decisions 1–4 in section 12 of the master plan (account type, devices, Charlie's Family Link account, default session length and family rewards) |
| Exit gate | MVP acceptance criteria below, then 3 weeks of real play feeding the decision gate on Feb 19, 2027 (Sprint 14) |

**Outcome.** Charlie can play an adaptive, text-based, fully offline game on his 2-in-1 Chromebook (laptop, tent and tablet postures) and his Android tablet, installed from Google Play internal testing. The MVP covers Zones 1–3 (about 45 skills: counting, comparing, place value, regrouping, addition and subtraction within 100, fact families, skip counting, even/odd, arrays, early multiplication), the full dig → collect → surface loop, the workshop hub with Gem Museum, tools and Bolt customization, the lantern streak, the BKT adaptive engine with placement, mastery, spaced review and the hint ladder, kid-friendly on-screen text from one text table, tap/drag/number-pad input, and a parent dashboard with time limit and progress export.

**Out of scope (do not build ahead; add ideas to the backlog):** AI-voice narration and the voice pipeline (Phase 3), handwriting and the Kotlin plugin (Phase 2), crafting and engineering projects, Zones 4–12, cross-device progress beyond manual export/import, badges, Deep Dig, family reward points, Scholar mode, child profiles, commissioned art, public release.

## Entry criteria

Before Sprint 1 starts on Nov 2:

1. **Developer account type chosen** (organization recommended). If organization: LLC filing and D-U-N-S request started in Sprint 1 so the paperwork runs in the background.
2. **Devices ordered:** the ARM 2-in-1 Chromebook with stylus and the Android tablet, both needed in hand by Sprint 3 (Nov 16). The emulator covers Sprints 1–2 if either is late.
3. **Charlie's Google account (Family Link)** ready to add as an internal tester.
4. **Defaults agreed:** session length (suggested 20 minutes) and what the family reward points will eventually buy (the points feature itself is Phase 2).
5. **Repository state:** this scaffold merged (`project.godot` pinned to 4.7.2, directory layout, GdUnit4 in CI, Android export presets, `docs/` files, `text/lines.csv` header).

## Architecture and design

Everything below follows the repository layout and autoload table in `CLAUDE.md`. Scene scripts do presentation only; testable logic lives in `scripts/`. Scenes talk to autoloads through signals and methods, never by reaching into each other's nodes.

### Scene flow and game shell (`scenes/shell/`)

The placeholder `scenes/shell/title.tscn` is replaced in Sprint 3 by a persistent root scene that hosts one screen at a time plus overlays.

```
Shell (Control)                      scenes/shell/shell.tscn  ← becomes run/main_scene in Sprint 3
├── ScreenHost (Control)             one child at a time: Title, Hub, Mine, Museum, Settings, ParentArea
├── Overlays (CanvasLayer)
│   ├── PauseMenu (Control)          scenes/shell/pause_menu.tscn, hidden by default
│   ├── WindDown (Control)           "time to head up to the surface" recap
│   └── Transition (ColorRect)       fade in/out between screens
└── DebugOverlay (Control)           fps, posture, device kind; only in debug builds
```

- `Shell.change_screen(screen_id: StringName, args: Dictionary = {}) -> void` frees the current screen, instantiates the next from a `Dictionary[StringName, PackedScene]`, fades with a `Tween` (a Tween animates a property over time; created with `create_tween()`), and emits `screen_changed(screen_id)`.
- Screens never call `get_tree().change_scene_to_file()`. They emit requests (`request_screen(id, args)`) that Shell handles, so the pause overlay and wind-down survive screen changes.
- `Shell` listens for `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_WM_CLOSE_REQUEST` and calls `SaveSystem.save_now()` (CLAUDE.md save points).
- Fullscreen and landscape: the project is already landscape-only with `canvas_items` stretch and `expand` aspect (see `docs/decisions.md`). Sprint 1 verifies this on the real devices; Sprint 3 handles window resizes (posture changes) by re-laying out containers only. No absolute positions.

### Text system (`autoload/text.gd`, `text/lines.csv`)

CSV columns: `id,text,context,voice_version`. `voice_version` stays `0` until Phase 3.

```gdscript
# autoload/text.gd  (registered as "Text")
extends Node
signal missing_line(id: StringName)          # editor/debug only: lets the lint and the dev overlay show gaps

func get_line(id: StringName, params: Dictionary = {}) -> String
func has_line(id: StringName) -> bool
func term_definition(term_id: StringName) -> Dictionary   # {text: String, picture: Texture2D} from curriculum/vocabulary.json
```

- Placeholders `{n}`, `{a}`, `{b}`, `{answer}` are filled with `String.format(params)`; a missing param in a debug build pushes an error. Never bake a number into a line.
- Line ID format `zone.context.purpose`, lowercase, e.g. `z1.dig.prompt_build_number`, `hub.museum.quartz_fact`, `bolt.hint.look_again`, `ui.pause.resume`. Never reuse or rename an ID; deprecate (`context = deprecated`) and add a new one.
- Explorer-mode writing rules: 12 words or fewer per sentence, one instruction per line, first-grade vocabulary, real math terms introduced with a kid explanation. Feedback never says "Wrong!"; the stock line is `bolt.feedback.not_quite` = "Not quite. Let's look again."
- The CSV is read at runtime with `FileAccess` (its `.import` is `importer="keep"`), so the math reviewer can edit it in a spreadsheet.

### Input (`autoload/input_router.gd`, `autoload/ui.gd`)

```gdscript
# autoload/input_router.gd  (registered as "InputRouter")
enum DeviceKind { TOUCH, PEN, MOUSE, KEYBOARD }
signal pointer_down(pos: Vector2, kind: DeviceKind, index: int)
signal pointer_move(pos: Vector2, kind: DeviceKind, index: int)
signal pointer_up(pos: Vector2, kind: DeviceKind, index: int)
signal device_kind_changed(kind: DeviceKind)       # last kind seen; drives hints like "tap" vs "click"
signal posture_changed(size: Vector2i)             # from get_window().size_changed

func last_device_kind() -> DeviceKind
func is_touch_first() -> bool                      # true until a mouse event is seen this session
```

- `_input(event)` maps `InputEventScreenTouch`/`InputEventScreenDrag` → TOUCH, `InputEventMouseButton`/`InputEventMouseMotion` → MOUSE (pen events on ChromeOS may arrive as mouse or touch with pressure; Sprint 1 records which, and `docs/decisions.md` gets the answer). Only the first touch index is honored; extra fingers are ignored (no multi-finger gestures). Palm rejection during pen strokes is added with the chalk slate in Phase 2.
- Drag-and-drop in the game uses `pointer_down/move/up` through `scenes/input/drag_target.tscn`, not Godot's `_get_drag_data`, so finger, pen and mouse behave identically.
- Keyboard: digits and Enter feed the `NumberPad` in laptop posture; Escape opens the pause menu.

```gdscript
# autoload/ui.gd  (registered as "UI")
func min_target_px() -> int         # 64 dp converted with DisplayServer.screen_get_dpi() and the stretch scale; never below 64 px
func scale_factor() -> float
func theme() -> Theme               # assets/themes/explorer.tres: Andika font, large sizes, high contrast
```

All interactive controls set `custom_minimum_size` from `UI.min_target_px()`.

### Save system (`autoload/save_system.gd`, `scripts/save/`)

- Files in `user://save/`: `profile.json` (the save), `attempts.jsonl` (append-only attempt log, one JSON object per line, kept out of the main save so it stays small), `profile.json.bak` (previous good save).
- **Atomic write:** serialize → write `profile.json.tmp` → rename over `profile.json` after copying the old file to `.bak`. On load, if `profile.json` fails to parse, fall back to `.bak` and report it on the parent dashboard.
- **Save points:** after every rock, on posture change, on `NOTIFICATION_APPLICATION_PAUSED`, on `NOTIFICATION_WM_CLOSE_REQUEST`, and when leaving any screen.
- **Schema v1** (changes need Spiro's sign-off, a migration in `scripts/save/migrations/`, and a fixture in `tests/save/fixtures/`):

```json
{
  "schema_version": 1,
  "created_at": "2026-11-20T15:04:05Z",
  "updated_at": "2026-12-03T21:10:00Z",
  "child": { "nickname": "Charlie" },
  "settings": { "session_minutes": 20, "interface_mode": "explorer", "read_aloud": false,
                "handwriting_coaching": false, "starting_grade": 1 },
  "placement": { "done": false, "seed": "star_2026_09" },
  "skills": {
    "pv.tens_ones.build": {
      "p_learned": 0.42, "attempts": 12, "correct": 9,
      "correct_days": ["2026-12-01", "2026-12-03"],
      "mastered_at": null, "review_stage": 0, "next_review_at": null,
      "flagged_for_review": false, "recent_latency_ms": [4200, 3900]
    }
  },
  "rewards": {
    "coins": 120,
    "gems": { "quartz": 4, "garnet": 1 },
    "inventory": ["pickaxe_t1"],
    "bolt": { "headlamp": "blue", "paint": "default", "sticker": "none" },
    "lantern": { "lit_days": ["2026-12-01", "2026-12-02"], "streak": 2 }
  },
  "session": { "resume": null }
}
```

Attempt line (`attempts.jsonl`): `{"ts","session_id","skill_id","problem_seed","representation","answer_mode","correct","hints_used","latency_ms","low_confidence_rejected":false}`.

```gdscript
# autoload/save_system.gd  (registered as "SaveSystem")
signal saved
signal load_failed(reason: String)
func load() -> void
func save_now() -> void
func data() -> Dictionary                 # live save dictionary; mutate through the owning autoload only
func append_attempt(attempt: Attempt) -> void
func export_bundle(path: String) -> Error # parent-gated: profile.json + attempts.jsonl in one JSON file
func import_bundle(path: String) -> Error # newest wins; the replaced save is kept as .bak
```

### Core data classes (`scripts/core/`)

```gdscript
class_name Skill extends Resource         # loaded from curriculum/skills/*.json
@export var id: StringName                # topic.subtopic.action
@export var zone: int
@export var prereqs: Array[StringName]
@export var generator: StringName         # script name under scripts/generators/
@export var params: Dictionary
@export var representations: Array[StringName]   # ["concrete", "pictorial", "abstract"]
@export var answer_modes: Array[StringName]      # ["tap", "drag", "number_pad", "keyboard"]
@export var terms: Array[StringName]      # Word Gem ids in curriculum/vocabulary.json
@export var bkt_type: StringName          # key into curriculum/bkt_defaults.json
@export var is_fact_skill: bool           # enables the hidden fluency check

class_name Problem extends RefCounted
var skill_id: StringName
var seed: int
var representation: StringName
var prompt_line_id: StringName
var prompt_params: Dictionary
var answer: Variant                       # canonical: int, Array[int] (ordered), or Dictionary {tens:int, ones:int}
var answer_modes: Array[StringName]
var distractors: Array[Dictionary]        # [{value: Variant, misconception: StringName}]
var visual: Dictionary                    # {type: "ten_frame"|"number_line"|"array"|"gem_piles", ...}
var hint_steps: Array[Dictionary]         # one per ladder rung: {kind, line_id, params, visual}
func is_correct(given: Variant) -> bool   # canonical comparison, order-sensitive where it matters
func to_json() -> Dictionary              # exact shape the Python cross-checker reads

class_name Attempt extends RefCounted     # fields match the attempts.jsonl line above
```

### Problem generators (`scripts/generators/`)

Pure static functions, one file per skill family, no nodes, no globals, always the passed-in `rng`:

```gdscript
class_name CountingGenerator
static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
```

Rules: distractors never equal the answer and have no duplicates; each distractor names its misconception; the generator fills `hint_steps` for the four ladder rungs; the same seed always yields the same problem.

- `scripts/generators/registry.gd` (`class_name GeneratorRegistry`) resolves a skill's `generator` string (`"CountingGenerator"` or `"Class.method"`) to a `Callable` once at load time, so later zones add generators as data plus one file. Verify in Godot docs how to obtain a static `Callable` from a `class_name` script in 4.7.
- `curriculum/misconceptions.json` is the allowed list of distractor misconception names with a one-line parent-facing description each; tests and lint rule 6 reject unknown names.
- `tests/curriculum/test_skill_graph.gd` mirrors the Python DAG check in GdUnit4 (Sprint 5), so the Godot side also fails on a cycle, a missing prerequisite or an unresolvable generator.
- Test helpers (`tests/helpers/input_sim.gd`, Sprint 4): `InputRouter.simulate_tap(pos)` and `InputRouter.simulate_drag(from, to)` feed synthetic `InputEventScreenTouch` / `InputEventScreenDrag` events so scene tests run headless.

**Zone 1–3 skill list (skill map v1, finalized in Sprint 2 with the math reviewer).** IDs are `topic.subtopic.action`; prerequisites form a DAG (a test enforces it).

| Skill ID | Zone | Prereqs | Generator / params | Representations | Answer | Named distractors |
|---|---|---|---|---|---|---|
| `count.to_20.objects` | 1 | — | counting `{max: 20}` | concrete | int (tap numeral) | `off_by_one`, `double_counted` |
| `count.to_120.read` | 1 | `count.to_20.objects` | counting `{max: 120}` | pictorial | int | `digit_swap`, `off_by_one` |
| `count.to_120.next` | 1 | `count.to_120.read` | counting `{mode: next}` | abstract | int | `off_by_one`, `decade_skip` |
| `count.to_120.between` | 1 | `count.to_120.next` | counting `{mode: between}` | abstract | int | `off_by_one` |
| `count.to_120.fill_strip` | 1 | `count.to_120.next` | counting `{mode: strip, len: 5}` | pictorial | Array[int] | `off_by_one`, `decade_skip` |
| `count.write.numeral` | 1 | `count.to_120.read` | counting `{mode: write}` | concrete→abstract | int (number pad) | `digit_swap` |
| `cmp.to_20.more_less` | 1 | `count.to_20.objects` | compare `{max: 20}` | concrete | int (tap pile) | `picked_smaller` |
| `cmp.to_100.symbols` | 1 | `count.to_120.read` | compare `{max: 100, symbols: true}` | abstract | StringName `<`,`>`,`=` | `reversed_symbol`, `compared_ones_first` |
| `cmp.to_100.order3` | 1 | `cmp.to_100.symbols` | compare `{mode: order, n: 3}` | pictorial | Array[int] | `reversed_order`, `compared_ones_first` |
| `pv.tens_ones.build` | 1 | `count.to_120.read` | place_value `{max: 99, mode: build}` | concrete (drag) | `{tens, ones}` | `digit_swap`, `counted_tens_as_ones` |
| `pv.tens_ones.read` | 1 | `pv.tens_ones.build` | place_value `{mode: read}` | concrete→abstract | int | `digit_swap`, `counted_bars_as_ones` |
| `pv.tens_ones.expanded` | 1 | `pv.tens_ones.read` | place_value `{mode: expanded}` | abstract | Array[int] `[30, 4]` | `digit_value_as_digit` |
| `pv.tens_ones.digit_value` | 1 | `pv.tens_ones.expanded` | place_value `{mode: digit_value}` | abstract | int | `digit_value_as_digit`, `wrong_place` |
| `pv.regroup.trade_ten` | 1 | `pv.tens_ones.build` | regroup `{mode: ones_to_ten, max_ones: 19}` | concrete (drag) | `{tens, ones}` | `forgot_regroup`, `traded_wrong_count` |
| `pv.regroup.untrade` | 1 | `pv.regroup.trade_ten` | regroup `{mode: ten_to_ones}` | concrete | `{tens, ones}` | `forgot_regroup` |
| `pv.tens.ten_more_less` | 1 | `pv.tens_ones.read` | place_value `{mode: ten_more_less}` | pictorial | int | `changed_ones`, `off_by_one` |
| `pv.hundred.intro` | 1 | `pv.regroup.trade_ten` | place_value `{max: 120, mode: build}` | concrete | `{hundreds, tens, ones}` | `counted_tens_as_ones` |
| `add.to_10.sums` | 2 | `count.to_20.objects` | addition `{max_sum: 10}` | concrete | int | `off_by_one`, `counted_from_one` |
| `add.to_20.sums` | 2 | `add.to_10.sums`, `pv.regroup.trade_ten` | addition `{max_sum: 20, strategy: make_ten}` | pictorial (ten frame) | int | `off_by_one`, `forgot_regroup` |
| `add.to_20.doubles` | 2 | `add.to_10.sums` | addition `{mode: doubles_near}` | pictorial | int | `off_by_one`, `off_by_two` |
| `sub.to_10.diff` | 2 | `add.to_10.sums` | subtraction `{max: 10}` | concrete | int | `added_instead`, `off_by_one` |
| `sub.to_20.diff` | 2 | `sub.to_10.diff`, `add.to_20.sums` | subtraction `{max: 20}` | pictorial | int | `added_instead`, `off_by_one` |
| `eq.fact_family.build` | 2 | `add.to_20.sums`, `sub.to_20.diff` | fact_family `{max: 20}` | abstract (drag) | Array[String] 4 facts | `wrong_operation`, `swapped_minuend` |
| `eq.missing_addend.to_20` | 2 | `eq.fact_family.build` | missing_part `{mode: addend}` | pictorial | int | `added_both`, `off_by_one` |
| `eq.missing_subtrahend.to_20` | 2 | `eq.missing_addend.to_20` | missing_part `{mode: subtrahend}` | pictorial | int | `added_both` |
| `eq.balance.true_false` | 2 | `add.to_20.sums` | balance `{max: 20}` | pictorial (scale) | bool | `left_side_only` |
| `eq.inverse.check` | 2 | `eq.fact_family.build` | fact_family `{mode: inverse_check}` | abstract | StringName fact | `wrong_operation` |
| `add.to_100.tens` | 2 | `pv.tens.ten_more_less` | addition `{multiples_of_ten: true}` | pictorial | int | `added_as_ones`, `decade_skip` |
| `add.to_100.no_regroup` | 2 | `add.to_100.tens`, `pv.tens_ones.read` | addition `{max: 100, regroup: false}` | concrete→abstract | int | `added_tens_to_ones`, `digit_swap` |
| `add.to_100.regroup` | 2 | `add.to_100.no_regroup`, `pv.regroup.trade_ten` | addition `{max: 100, regroup: true}` | concrete→abstract | int | `forgot_regroup`, `carried_twice` |
| `sub.to_100.tens` | 2 | `add.to_100.tens` | subtraction `{multiples_of_ten: true}` | pictorial | int | `subtracted_as_ones` |
| `sub.to_100.no_regroup` | 2 | `sub.to_100.tens`, `sub.to_20.diff` | subtraction `{max: 100, regroup: false}` | concrete→abstract | int | `smaller_from_larger`, `digit_swap` |
| `sub.to_100.regroup` | 2 | `sub.to_100.no_regroup`, `pv.regroup.untrade` | subtraction `{max: 100, regroup: true}` | concrete→abstract | int | `smaller_from_larger`, `forgot_untrade` |
| `add.three_addends.to_20` | 2 | `add.to_20.sums` | addition `{addends: 3, max_sum: 20}` | pictorial | int | `dropped_addend`, `off_by_one` |
| `skip.by_10.to_120` | 3 | `pv.tens.ten_more_less` | skip_count `{step: 10, max: 120}` | pictorial | Array[int] | `wrong_step`, `decade_skip` |
| `skip.by_5.to_100` | 3 | `skip.by_10.to_120` | skip_count `{step: 5}` | pictorial | Array[int] | `wrong_step` |
| `skip.by_2.to_40` | 3 | `count.to_120.next` | skip_count `{step: 2}` | concrete (pairs) | Array[int] | `wrong_step`, `off_by_one` |
| `parity.even_odd.pairs` | 3 | `skip.by_2.to_40` | parity `{max: 20, mode: pairs}` | concrete | bool | `leftover_miscounted` |
| `parity.even_odd.rule` | 3 | `parity.even_odd.pairs`, `pv.tens_ones.read` | parity `{max: 100, mode: last_digit}` | abstract | bool | `used_tens_digit` |
| `arr.rows_cols.count` | 3 | `skip.by_2.to_40`, `skip.by_5.to_100` | arrays `{max_rows: 5, max_cols: 5}` | concrete | int | `rows_plus_cols`, `off_by_row` |
| `arr.rows_cols.build` | 3 | `arr.rows_cols.count` | arrays `{mode: build}` | concrete (drag) | `{rows, cols}` | `rows_cols_swapped` |
| `mult.repeated_add.to_sum` | 3 | `arr.rows_cols.count`, `add.three_addends.to_20` | multiplication `{mode: repeated_add}` | pictorial | int | `counted_groups`, `off_by_group` |
| `mult.equal_groups.total` | 3 | `mult.repeated_add.to_sum` | multiplication `{mode: equal_groups, max: 25}` | concrete | int | `rows_plus_cols`, `counted_groups` |
| `mult.commutative.match` | 3 | `mult.equal_groups.total`, `arr.rows_cols.build` | multiplication `{mode: commutative}` | pictorial | StringName | `rows_cols_swapped_wrong` |
| `mult.facts.2_5_10` | 3 | `mult.equal_groups.total`, `skip.by_5.to_100` | multiplication `{tables: [2, 5, 10]}` | abstract | int | `off_by_group`, `wrong_table` |

Word Gems introduced (recorded in `curriculum/vocabulary.json`): digit, numeral, tens, ones, hundred, regrouping ("trade ten"), greater than, less than, equal, sum, difference, fact family, inverse, even, odd, array, row, column, equal groups, multiply, commutative.

**Cross-checker.** `tools/crosscheck/export_problems.gd` runs headless (`"$GODOT" --headless --path . --script res://tools/crosscheck/export_problems.gd -- --skill <id> --n 10000 --seed 1 --out build/crosscheck/<id>.jsonl`) and writes `Problem.to_json()` lines. `tools/crosscheck/run.py --all --n 10000` drives it for every skill in `curriculum/skills/` and re-derives each answer from `prompt_params` in Python, written separately from the GDScript. Failures print the seed. The checker and generator must not share code or data files other than the exported JSONL.

### Adaptive engine (`autoload/adaptive.gd`, `scripts/adaptive/`)

```gdscript
# scripts/adaptive/bkt.gd
class_name BKT
static func update(p_learned: float, correct: bool, p: Dictionary) -> float
# p = {prior, learn, guess, slip} from curriculum/bkt_defaults.json by skill.bkt_type
# posterior_correct = pL(1-slip) / (pL(1-slip) + (1-pL)guess)
# posterior_wrong   = pL*slip    / (pL*slip    + (1-pL)(1-guess))
# return posterior + (1 - posterior) * learn
static func update_with_hints(p_learned: float, correct: bool, hints_used: int, p: Dictionary) -> float
# hint-assisted correct = partial evidence: blend 50% toward the "correct" update (default weight, tunable in bkt_defaults.json)
```

- `curriculum/bkt_defaults.json`: `{ "default": {"prior": 0.3, "learn": 0.2, "guess": 0.2, "slip": 0.1}, "fact": {...}, "procedure": {...}, "concept": {...}, "hint_weight": 0.5 }`. Literature-typical starting values; fitted later by `tools/bkt/fit.py` (Phase 2). Changing them needs Spiro.
- **Mastery:** `p_learned >= 0.95` and `correct_days.size() >= 2` (distinct calendar days). Fact skills (`is_fact_skill`) also need median `recent_latency_ms` under the skill's threshold; never shown to the child.
- **Frontier:** skills whose prereqs are all mastered (or placement-passed) and are not mastered themselves. `Adaptive.next_problem()` interleaves 2–3 frontier skills (never the same skill three rocks in a row) and reserves about 30% of rocks for review.
- **Spaced review:** on mastery, `review_stage = 0` and `next_review_at = now + 1 day`; each correct review advances through 1, 3, 7, 21, 60 days; a wrong review resets `review_stage` to 0, sets `flagged_for_review` and returns the skill to the frontier.
- **Hint ladder** (`scripts/adaptive/hint_ladder.gd`): `enum Rung { REPEAT_HIGHLIGHT, VISUAL_MODEL, WORKED_EXAMPLE, EASIER_PROBLEM }`; `next_rung(wrong_count: int) -> Rung`. Rung 4 asks the generator for an easier problem of the same skill (`params.difficulty -= 1`) and flags the skill for review and the dashboard. Rungs 1–2 ship in Sprint 6, rungs 3–4 in Sprint 8.
- **Placement quest** (`scripts/adaptive/placement.gd`): a 10-minute "survey the mountain" run. Seeded start set for Charlie: `count.to_120.read`, `pv.tens_ones.build`, `add.to_10.sums`. For each probed skill: 2 problems; both right → mark the skill and all its prerequisites `placement_passed` (p_learned set to 0.85, not mastered) and probe a successor; otherwise probe a prerequisite. Stops at 10 minutes or when no frontier change is possible. Parents can re-run it from the parent area.
- **Session:** `Adaptive.start_session()` picks the interleave set; `Adaptive.record(attempt)` updates BKT, appends to `attempts.jsonl`, and emits `skill_mastered(skill_id)` / `skill_flagged(skill_id)` for Rewards and the dashboard.

```gdscript
# autoload/adaptive.gd  (registered as "Adaptive")
signal skill_mastered(skill_id: StringName)
signal skill_flagged(skill_id: StringName)
func next_problem(rng: RandomNumberGenerator) -> Problem
func record(attempt: Attempt) -> void
func frontier() -> Array[StringName]
func mastered() -> Array[StringName]
func struggling() -> Array[StringName]          # flagged_for_review or 3+ wrong in the last 5 attempts
```

**Simulated learners** (`tests/adaptive/test_simulated_learners.gd`): fast (p_correct 0.95), average (0.7 rising with practice), slow (0.5 rising), random guesser (1/choices), forgetter (drops to 0.4 after mastery). Required outcomes: the guesser never masters anything in 2,000 rocks; the fast learner masters Zone 1 within 150 rocks across 2 simulated days; the forgetter gets pulled back into practice by a failed review.

### Mine scene (`scenes/mine/`)

```
Mine (Control)                       scenes/mine/mine.tscn
├── RockWall (Control)               scenes/mine/rock_wall.tscn: grid of 6–9 Rock instances for this dig
│   └── Rock (TextureButton)         scenes/mine/rock.tscn: idle → selected → wobble → crack → gem_drop
├── ProblemPanel (Control)           prompt (speech bubble from Bolt), visual model slot, answer area
│   ├── BoltBubble (Control)         scenes/mine/bolt.tscn: Label from Text, tappable Word Gem terms
│   ├── VisualModel (Control)        ten_frame / number_line / array / gem_piles, chosen by Problem.visual
│   └── AnswerArea (Control)         one of scenes/input/: tap choices, DragTarget set, NumberPad
├── Cart (Control)                   scenes/mine/cart.tscn: gems fly in; coin counter
└── SessionTimer (Node)              soft limit; emits wind_down_due at the next rock boundary
```

Dig state machine in `scenes/mine/mine.gd` (presentation only): `PICK_ROCK → SHOW_PROBLEM → AWAIT_ANSWER → (CORRECT: CRACK → GEM_DROP → PICK_ROCK | WRONG: WOBBLE → HINT → AWAIT_ANSWER)`. Each state change saves (`SaveSystem.save_now()` after `GEM_DROP`). The rock wall is complete when all rocks are cracked; Bolt offers "head to the surface" or "dig more".

Answer input scenes (`scenes/input/`): `number_pad.tscn` (0–9, backspace, big Go button; keyboard digits also feed it), `drag_target.tscn` (slot that accepts `DragItem`s such as ten-bars and one-gems and reports `{tens, ones}`), `choice_buttons.tscn` (2–4 big buttons, answer plus distractors, shuffled with the problem's rng). Never `LineEdit` or `TextEdit` here (rule 6).

### Rewards v1 (`autoload/rewards.gd`, `scenes/workshop/`)

- Every cracked rock gives 1 coin (2 on the first try) and one gem of the zone's type: Zone 1 quartz, Zone 2 garnet, Zone 3 pyrite. Mastering a skill drops a bonus gem (amethyst). Wrong answers cost nothing. No randomness in value.
- **Gem Museum** (`scenes/workshop/museum.tscn`): 10 minerals with a text fact each (`hub.museum.<mineral>_fact`): quartz, garnet, pyrite, amethyst, malachite, fluorite, hematite, calcite, topaz, obsidian. A case opens when the player holds that gem (museum pieces are earned from zone completions and mastery, not bought).
- **Tools:** `pickaxe_t1` (start) and `pickaxe_t2` (costs 50 coins; cracks rocks with a bigger effect). **Bolt customization:** 3 headlamp colors (blue default, green 20 coins, gold 40 coins). Purchases are coin-only; no real money.
- **Lantern streak:** a lantern lights for each calendar day with at least one cracked rock. Missed days pause the streak; it never resets.
- **Session timer:** `settings.session_minutes` (default 20). At the limit, Bolt's wind-down line plays at the next rock boundary and the recap shows skills practiced and gems earned. The child can still finish the current rock. No countdown is ever shown.

### Workshop hub and parent area (`scenes/shell/hub.tscn`, `scenes/shell/parent_area/`)

- Hub buttons: Dig (Bolt suggests the tunnel; the engine picks it), Museum, Bolt's Garage (customization and tools), Settings, Grown-ups (parent gate).
- **Parent gate:** a 2-digit × 1-digit multiplication question answered on the `NumberPad`; three misses → 30-second cooldown. `LineEdit` is allowed inside the parent area only.
- **Dashboard v1** (`parent_area/dashboard.tscn`): time played (today, this week), skills mastered (names from `curriculum/`), struggling skills, last 7 sessions, settings (session length, nickname, re-run placement), **Export progress** (`SaveSystem.export_bundle`) and **Import progress**. Export writes a JSON file through the native file dialog (`DisplayServer.file_dialog_show`; verify Android support in the Godot 4.7 docs, otherwise write to the app's external files directory and show the path). Nothing leaves the device unless the parent does this.

### Content lint and CI (`tools/ci/lint_content.py`, `.github/workflows/ci.yml`)

Lint rules (each a pytest-able function): (1) no literal `text = "..."` or `.text = "..."` in `scenes/` and `scripts/` outside `scenes/shell/parent_area/`, except an allowlist file `tools/ci/lint_allowlist.txt` (the placeholder title label until Sprint 10's logo); (2) no `LineEdit`/`TextEdit` node types outside `scenes/shell/parent_area/`; (3) banned words (word-boundary, case-insensitive) in `text/lines.csv`, `curriculum/**`, `docs/gdd.md` and asset filenames: alcohol, beer, wine, gambling, casino, lottery, smoke, smoking, tobacco, campfire, fireplace, torch, bee, bees, honeycomb, cat, cats, kitten, dog, dogs, puppy, octopus, shellfish, shrimp, lobster, crab, clam, oyster; (4) line IDs match `^[a-z0-9]+(\.[a-z0-9_]+){2,}$` and are unique; (5) Explorer lines over 12 words per sentence are warnings; (6) every `terms` entry in `curriculum/skills/` exists in `vocabulary.json`; (7) the prerequisite graph is acyclic.

CI jobs: `godot-import` (exists), `gdunit` (Sprint 3: `addons/gdUnit4/runtest.sh -a res://tests`), `python` (Sprint 3: `pytest tools` and `lint_content.py`), `crosscheck` (Sprint 5: nightly and on generator changes, `n=10000`), `android-debug` (Sprint 11: debug APK artifact; release AAB stays a local Friday step because it needs the keystore).

## Sprint plan

### Sprint 1 (Nov 2–6): Setup, Godot ramp-up, device test

Goal: tools installed, Godot basics learned, and a "hello rock" build installed on both devices from the internal testing track.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S01-01 | — | Decide account type; start LLC + D-U-N-S if organization; create the Play Console account ($25) | Account exists; paperwork started |
| P1-S01-02 | — | Install Godot 4.7.2 (matches `.godot-version`), Android Studio + SDK for API 36, JDK 17 Temurin, Android export templates for 4.7.2 | `"$GODOT" --headless --path . --import` runs on the dev PC |
| P1-S01-03 | — | Godot ramp-up: "Your first 2D game", GDScript reference, Android export guide (~12 h); game-feel study (~3 h) | Notes in `docs/gdd.md` "Game feel" section |
| P1-S01-04 | `feat/hello-rock` | Hello rock: one tappable rock (TextureButton) that wobbles then cracks with a sound; shows device kind and window size on screen | Runs in editor and on Android |
| P1-S01-05 | `chore/android-export-preset` | Verify the committed `export_presets.cfg` (presets "Android" APK and "Android AAB", arm64-v8a + x86_64, target SDK 36, Gradle build, **no INTERNET permission**, approved 2026-10-17) on the dev PC with the templates and SDK installed; confirm the package id before the first Play upload | Debug APK installs with `adb` |
| P1-S01-06 | — | Internal testing track: upload the AAB, add Spiro's and Charlie's accounts | Installs from Play on both devices (or emulator if a device is late) |
| P1-S01-07 | `docs/device-findings` | Device test: touch, stylus (pen vs touch events, pressure), trackpad, keyboard, fullscreen, landscape lock in tablet posture, posture switching mid-run | Findings recorded in `docs/decisions.md` |

Implementation notes for the agent: keep hello rock out of the long-term layout (`scenes/mine/hello_rock.tscn`, deleted in Sprint 4); print `InputEvent` classes and `InputEventMouseMotion.pressure`/`InputEventScreenDrag.pressure` to the debug overlay so Spiro can read what the stylus sends; a signal is a node announcing an event that other nodes subscribe to with `.connect`. Tests: none beyond the CI import check. Playtest: let Charlie tap the rock and watch whether the target feels big enough.

### Sprint 2 (Nov 9–13): Game design and curriculum

Goal: a short GDD, skill map v1 with Zones 1–3 in full, placeholder art direction, and a paper-prototype playtest.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S02-01 | `docs/gdd` | Write `docs/gdd.md`: loop, screens, rewards, tone, Bolt's voice, feedback wording | Reviewed by Spiro |
| P1-S02-02 | `content/skill-map-v1` | `curriculum/skills/z01_pebble_meadow.json`, `z02_quarry_of_tens.json`, `z03_skip_count_caves.json` from the table above; `z04`–`z12` outlined (ids and names only); `curriculum/vocabulary.json`; `curriculum/bkt_defaults.json` | Math reviewer signs off on Zones 1–3; DAG check passes |
| P1-S02-03 | `test/curriculum-dag` | Python test: skill JSON schema, unique ids, acyclic prereqs, every generator name exists (string check for now) | `pytest tools` green |
| P1-S02-04 | `content/art-direction` | Pick CC0 packs (Kenney) for rocks, gems, UI; record each in `assets/CREDITS.md`; add Andika font with its OFL license | Lint and credits pass |
| P1-S02-05 | — | Paper prototype with paper rocks and Lego ten-bars/one-gems: does "trade ten" make sense to Charlie? | Notes in `docs/gdd.md` |

Tests: curriculum schema and DAG tests. Playtest: the paper prototype; log which words confused him.

### Sprint 3 (Nov 16–20): Architecture

Goal: the game shell, input router, number pad, text system, save system v1, and tests in CI.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S03-01 | `chore/gdunit4` | GdUnit4 6.2.2 is installed and in CI with one smoke test (scaffold PR); add the `tests/helpers/` input simulation and the first real suites | CI `gdunit` step green with Sprint 3 suites |
| P1-S03-02 | `feat/shell` | `shell.tscn` with ScreenHost, overlays, transitions; title, hub (stub), settings, pause; set as main scene; delete `title.tscn` placeholder text in favor of a logo texture (or allowlist it) | Screens switch with fade; Escape pauses |
| P1-S03-03 | `feat/text-autoload` | `Text` autoload, CSV loader, placeholder fill, `missing_line` signal; first ~40 UI lines | Unit tests for fill and missing params |
| P1-S03-04 | `feat/input-router` | `InputRouter` and `UI` autoloads; `min_target_px()`; theme `assets/themes/explorer.tres` | Debug overlay shows kind and posture; resize re-lays out |
| P1-S03-05 | `feat/number-pad` | `scenes/input/number_pad.tscn` with keyboard support | Works by touch, pen, mouse, keyboard |
| P1-S03-06 | `feat/save-v1` | `SaveSystem`, atomic write, `.bak` recovery, `attempts.jsonl`, schema v1, `tests/save/fixtures/v1.json` | Kill the app mid-write in a test; recovery passes |
| P1-S03-07 | `chore/python-ci` | `tools/ci/lint_content.py` rules 1–4, pytest job in CI | Lint runs on every PR |

Implementation notes: an autoload is a script Godot instantiates once at startup and exposes by name to every script; register them in `project.godot` `[autoload]` in this order: `Text`, `UI`, `InputRouter`, `SaveSystem`. Tests: GdUnit4 for Text and SaveSystem; pytest for lint. Playtest: none (no gameplay yet); Friday build still goes to internal testing.

### Sprint 4 (Nov 23–25, 3 days): Core dig loop (gray-box)

Goal: the dig loop with placeholder shapes and one hard-coded problem type, then the "is digging fun?" test.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S04-01 | `feat/mine-greybox` | `mine.tscn`, `rock_wall.tscn`, `rock.tscn` with wobble/crack tweens, `cart.tscn` with gem fly-in, `bolt.tscn` bubble | Loop runs end to end with hard-coded `pv.tens_ones.build` |
| P1-S04-02 | `feat/drag-target` | `drag_target.tscn` + `DragItem` for ten-bars and one-gems via `InputRouter` | Identical with finger, pen, mouse |
| P1-S04-03 | `feat/choice-buttons` | `choice_buttons.tscn` | Shuffled by problem rng |
| P1-S04-04 | `feat/dig-sfx` | Crack, gem, wobble sounds (licensed pack, credited), on the `SFX` bus | Every action has a sound |

Tests: scene-load smoke tests; drag test with synthetic `InputEventScreenTouch`. Playtest (Thanksgiving weekend): the fun test. If the loop is not fun with gray boxes, Sprint 5 starts with loop fixes, not content.

### Sprint 5 (Nov 30–Dec 4): Problem generators and Zone 1 content

Goal: the generator framework, all Zone 1 generators, and the independent cross-checker.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S05-01 | `feat/core-resources` | `Skill`, `Problem`, `Attempt` classes; `Skill` loader from JSON | Unit tests |
| P1-S05-02 | `feat/generators-counting` | `counting.gd`, `compare.gd` | Seeded tests, 10,000-problem runs |
| P1-S05-03 | `feat/generators-place-value` | `place_value.gd`, `regroup.gd` | Seeded tests, 10,000-problem runs |
| P1-S05-04 | `feat/crosscheck` | `export_problems.gd`, `tools/crosscheck/run.py` + one Python checker per Zone 1 generator | `run.py --all --n 10000` green in CI |
| P1-S05-05 | `content/z1-lines` | Zone 1 prompt and hint lines; visual models `ten_frame`, `gem_piles`, `number_line` | Lint green; every Zone 1 problem renders |

Implementation notes: generators are `static func` on a `class_name`; use only the passed `rng` (`rng.randi_range`); distractor sets are built by named misconception functions and deduplicated. Tests: determinism (same seed, same problem), answer in range, distractors never equal answer, no duplicates, misconception names from the allowed list. Playtest: Zone 1 rocks on the real loop.

### Sprint 6 (Dec 7–11): Adaptive engine v1 (BKT)

Goal: BKT, mastery, frontier, spaced review, attempt logging, hint rungs 1–2, placement quest, simulated learners.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S06-01 | `feat/bkt` | `bkt.gd` update rules, hint weighting; `bkt_defaults.json` loader | Unit tests against hand-computed values |
| P1-S06-02 | `feat/scheduler` | `scheduler.gd`: frontier, interleave 2–3 skills, 70/30 review mix, spaced intervals | Unit tests with a fake clock |
| P1-S06-03 | `feat/adaptive-autoload` | `Adaptive` autoload wiring to `SaveSystem` and the mine | Mine pulls `next_problem()` |
| P1-S06-04 | `feat/hint-ladder-1-2` | Rung 1 highlight + repeat; rung 2 visual model | Both rungs render for every Zone 1 skill |
| P1-S06-05 | `feat/placement` | Placement quest with Charlie's seed set; parent re-run | Simulated fast learner places into Zone 2 |
| P1-S06-06 | `test/simulated-learners` | Suite above | All five learner outcomes hold |

Tests: BKT math, scheduler, simulated learners (these must keep passing forever; changing thresholds needs Spiro). Playtest: placement quest with Charlie; compare its result with the Star report.

### Sprint 7 (Dec 14–18): Zone 2 content and kid-friendly text

Goal: Zone 2 generators and checkers, readable text with Word Gems, every MVP line written.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S07-01 | `feat/generators-addition` | `addition.gd`, `subtraction.gd` incl. regrouping and multiples of ten | Tests + cross-check |
| P1-S07-02 | `feat/generators-equations` | `fact_family.gd`, `missing_part.gd`, `balance.gd` | Tests + cross-check |
| P1-S07-03 | `feat/word-gems` | Tappable terms in `BoltBubble` → picture + kid definition from `vocabulary.json` | Every Zone 1–2 term works |
| P1-S07-04 | `feat/explorer-theme` | Andika at large sizes, speech-bubble layout, contrast check | Readable from 60 cm on the tablet |
| P1-S07-05 | `content/mvp-lines` | All ~300 MVP lines (prompts, hints, hub, museum, settings, wind-down) | Lint green; reading check with Charlie |
| P1-S07-06 | `feat/dig-feel` | Buffer: squash-and-stretch on crack, particle burst, cart bounce | Spiro's call on feel |

Tests: generators + cross-check; Word Gem lookup test; lint rule 5 (sentence length). Playtest: Zone 2 rocks; which lines did he reread or ask about?

> **Holiday break Dec 21 – Jan 1.** Zones 1–2 build on internal testing for informal play. On return, export the attempt log into `private/` for the first tuning look (never commit `private/`).

### Sprint 8 (Jan 4–8): Rewards v1

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S08-01 | `feat/rewards-autoload` | `Rewards` autoload: coins, gems, inventory, purchases, lantern | Unit tests incl. streak pause |
| P1-S08-02 | `feat/museum` | Museum with 10 minerals and facts | All 10 cases open from save data |
| P1-S08-03 | `feat/garage` | Tools (2 tiers) and 3 headlamp colors; cart and crack effects reflect the tool | Purchases persist |
| P1-S08-04 | `feat/session-timer` | Soft limit, wind-down overlay, recap | Finishes the current rock first; no countdown shown |
| P1-S08-05 | `feat/hint-ladder-3-4` | Worked example; easier problem + flag for review | Flag appears on the dashboard stub |
| P1-S08-06 | `feat/celebrations` | Mastery celebration, lantern lighting animation | No reward for speed or luck |

Tests: rewards math, streak across date boundaries (fake clock), hint rung 4 difficulty drop. Playtest: does he visit the museum on his own?

### Sprint 9 (Jan 11–15): Zone 3 content and parent area

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S09-01 | `feat/generators-skip-parity` | `skip_count.gd`, `parity.gd` | Tests + cross-check |
| P1-S09-02 | `feat/generators-arrays-mult` | `arrays.gd`, `multiplication.gd`; `array` visual model | Tests + cross-check |
| P1-S09-03 | `feat/parent-gate` | Gate with NumberPad and cooldown | Cannot be passed by random taps in 20 tries |
| P1-S09-04 | `feat/parent-dashboard-v1` | Time played, mastered, struggling, sessions, settings, placement re-run | Numbers match the save and attempt log |
| P1-S09-05 | `feat/progress-export-import` | Export/import bundle, newest-wins, `.bak` | Round trip between the two devices |

Tests: generators; dashboard aggregation from a fixture `attempts.jsonl`; export/import round trip. Playtest: Zone 3; a second adult reads the dashboard and says whether it matches what they saw.

### Sprint 10 (Jan 18–22, 4 days): Look, sound and first-run

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S10-01 | `content/placeholder-art-pass` | Coherent CC0 pass: Zones 1–3 walls, hub, Bolt (placeholder), gems differ by shape and color | Credits complete |
| P1-S10-02 | `feat/music-sfx` | Hub and mine music on the `Music` bus; remaining SFX | Volumes in settings |
| P1-S10-03 | `feat/first-run` | Nickname (number-pad-free picker from preset names or parent-entered in the parent area), Bolt intro, placement quest hand-off | Charlie can start alone |
| P1-S10-04 | `chore/readability-audit` | Every screen: target size ≥ `min_target_px()`, understandable from text + picture, color never the only clue | Checklist in `docs/gdd.md` |

Playtest: first-run from a wiped save, no adult help.

### Sprint 11 (Jan 25–29): MVP hardening and release

| ID | Branch | Item | Done when |
|---|---|---|---|
| P1-S11-01 | `fix/bug-bash` | Two-day bug bash on both devices | Zero known crashes |
| P1-S11-02 | `test/posture-save-update` | Automated and manual tests: posture change mid-rock, close mid-dig, device restart, install update over old save, airplane mode session | All pass on both devices |
| P1-S11-03 | `chore/perf-check` | 60 fps on both devices; no allocations in `_process`; texture atlases; download < 150 MB | Profiler captures attached to the PR |
| P1-S11-04 | `chore/android-ci-debug` | CI builds a debug APK artifact | Artifact on every main merge |
| P1-S11-05 | — | Release-signed AAB to internal testing; installed on both devices; Charlie plays a full session alone | MVP acceptance below |

## Testing and quality

| Area | Phase 1 approach |
|---|---|
| Math correctness | 10,000 seeded problems per generator in GdUnit4; independent Python cross-check in CI; math reviewer samples Zones 1–3 |
| Adaptive engine | BKT unit tests against hand-computed posteriors; scheduler tests with a fake clock; five simulated learners |
| Text | Lint rules 1–7; reading-level check with Charlie in Sprint 7; `missing_line` never fires in a full playthrough |
| Input | Every screen completed with touch only, stylus only, and mouse/keyboard where relevant, each Friday |
| Devices | Friday: 2-in-1 in laptop, tent and tablet postures; the tablet; emulator tablet and desktop profiles |
| Saves | Close mid-dig, posture switch, restart, update over old save, corrupt `profile.json` → `.bak` recovery |
| Offline | Airplane-mode full session; export preset has no INTERNET permission (checked by a test that parses `export_presets.cfg`) |
| Performance | 60 fps on both devices; profiler run in Sprint 11 |
| Accessibility | Targets ≥ 64 dp; gems differ by shape as well as color; Explorer lines ≤ 12 words |

## Exit criteria (MVP acceptance)

1. Charlie starts and finishes a 20-minute session on either device with no adult help after his first session.
2. Zero crashes across 5 consecutive playtest sessions.
3. Every Zone 1–3 generator passes its GdUnit4 tests and the Python cross-check at n = 10,000.
4. Progress survives closing the app, switching posture, restarting the device and installing an update.
5. The dashboard's mastered-skill list matches an adult observer's judgment.
6. Lint, GdUnit4, pytest and the CI import check are green on `main`; the release AAB is on internal testing and installed on both devices.

Then the decision gate (Feb 19, 2027, during Sprint 14): does Charlie ask to play, play 3+ days a week unprompted, and show a rising mastered-skill count; and is the pace sustainable for Spiro?

## Risks

| Risk | Likelihood | Mitigation in Phase 1 |
|---|---|---|
| Digging is not fun with gray boxes | Medium | Sprint 4 fun test before content; Sprint 7 buffer for feel; sound on every action |
| Stylus or posture quirks on ChromeOS | Low–Medium | Sprint 1 device test; posture tests in every Definition of done |
| Devices arrive late | Medium | Emulator for Sprints 1–2; both devices required by Sprint 3 |
| Text too hard for Charlie | Low–Medium | Word Gems; Sprint 7 reading check; parent can read along |
| Generator and test share a mistake | Low | Independent Python cross-checker, no shared code |
| Save corruption on abrupt close | Low | Atomic write + `.bak`; kill-mid-write test |
| Scope creep from AI ideas | Medium | Backlog, not the sprint; out-of-scope list above |
| Solo-developer burnout | Medium | Short Sprint 4 and 10; holiday break; MVP gate |

## Decisions for Spiro

1. **Account type** (organization recommended; start now).
2. **Stylus handling** after the Sprint 1 device test: treat pen as touch for all MVP interactions (recommended) or keep pen separate from day one.
3. **Nickname entry:** preset picker for the child (recommended) vs. parent-entered in the parent area.
4. **Session default** 20 minutes (recommended) and whether the wind-down allows one extra rock.
5. **Export file location:** native file dialog if Godot 4.7 supports it on Android (recommended), otherwise app external files directory.
6. **Approve the Sprint 1 export preset** (permissions, ABIs, target SDK) and the GdUnit4 and Andika entries in `docs/sdk-audit.md`.

## Hand-off to Phase 2

Phase 2 (`docs/phases/phase-2-version-1-0.md`) expects: the autoloads above in place with tests; `Problem.answer_modes` and `scenes/input/` ready to accept a `ChalkSlate` input scene; `attempts.jsonl` export working so `tools/bkt/fit.py` can fit parameters from Charlie's logs; save schema v1 with its fixture so the Phase 2 migrations have a baseline; the `InputRouter` as the single place to add palm rejection; the hint ladder and `flagged_for_review` feeding the dashboard; and the three-week play period's exported logs in `private/`.
