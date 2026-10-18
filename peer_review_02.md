# Peer review 02: Phase 2 (Sprints 12–21) code audit

**Date:** 2026-10-18
**Scope:** everything built for Phase 2 of `docs/development-plan.md` (section 8.3) and `docs/phases/phase-2-version-1-0.md`, on top of the Phase 1 code that `peer_review_01.md` audited: the six autoloads, every script under `scripts/` (adaptive, save and its v1→v2 migration, core rules, generators, handwriting, workshop), every scene under `scenes/` (mine, input widgets incl. the chalk slate, boulder split, sieve grid, factor tree, shell, parent area, workshop), `project.godot`, `export_presets.cfg`, the curriculum data, the text table, the Python tools (cross-check, lint, perf, BKT, handwriting) and the test suites. Phase 3 work (narration, profiles, the v2→v3 migration) was not started; nothing scheduled for it was built.
**Method:** `status.md` first, then the Phase 2 plan, the decisions log and the Phase 2 retrospective. A clean headless import, then the whole verification set run **before any change** as the baseline: the GdUnit4 suites, pytest, the content lint, the static perf check, the curriculum check, the 10,000-problem Python cross-check of all 72 generators, and the main scene run headless for three frames. Then a full read of the code in four passes (core logic and autoloads; mine, input and zone scenes; shell, workshop and parent area; generators and checkers), each claim traced end to end before it was counted. Fixes were made test-first: each defect got a regression test, the test was shown to fail against the unfixed source and pass with the fix, then the full set was re-run.

---

## 1. Executive summary

**The Phase 2 codebase is in good shape and stable; it is ready for the device and human steps that gate Version 1.0.** It does what `status.md` and the Phase 2 plan say it does, in the shape the plan describes, and the architecture rules of `CLAUDE.md` hold throughout:

- Game logic stays in `scripts/` as typed, node-free classes (`AdaptiveEngine`, `Scheduler`, `SaveMerge`, `ProgressBundle`, `WorkshopRules`, `MotivationRules`, `SlateReader`, `StrokeRaster`, `DigitNet`, the 22 generators); scene scripts present them and talk to autoloads through signals and methods. No scene reaches into another scene's nodes.
- Every child-facing word comes from `text/lines.csv` through `Text`; the only `LineEdit`s are the parent area's; every interactive control is sized by `UI.make_touch_target` / `UI.target_size`; there is no network class, no `INTERNET` permission, no randomness in rewards, no path by which a wrong answer costs anything (a Challenge Door miss only closes the door, a "Try again" on the slate never reaches BKT).
- Handwriting keeps nothing: strokes live in `DigitBox` while the child can see them and are cleared on submit, erase and `_exit_tree`; `NetRecognizer` holds no state; the capture screen is debug-build-only and writes stroke JSON, never a picture. The GDScript rasterizer and network match the Python twins to the fixtures.
- The save layer is sound: atomic writes with `.bak` recovery, one v1→v2 migration that drops nothing, a bundle checksum, newest-wins import with five backups, device-only state outside the child's save. The adaptive engine's evidence rules, mastery thresholds, review intervals and the Challenge Door's guess bound are as the plan and the decisions describe, and the simulated learners still behave.
- The math is right as far as 10,000 seeded problems per skill can show: all 72 Zone 1–5 generators pass their GdUnit4 invariants and the independent Python checkers. The checkers share no code with the generators. The generator review found **no math defect**.
- The baseline was green before the review: **1039 GdUnit4 tests in 95 suites, 839 pytest tests (34 skipped by design), lint 0/0, perf 0, curriculum 0, cross-check 72/72, headless startup clean** (one benign exit-time report, section 3, note A).

**Thirteen issues were found and fixed** (section 3), with regression tests for each. Two matter for a child's session:

1. **A handwritten answer could vanish.** With numeral coaching on, the third backwards digit made the slate show Bolt's stroke demo *before* it reported the answer; the demo puts the panel to sleep, and a sleeping panel drops answers. The child's rock stayed open with no feedback and nothing logged.
2. **A save from the MVP build lost its Word Gems on update.** The v1→v2 migration relies on `Rewards.sync_word_gems` "on load", but at a real app start `SaveSystem` loads before `Rewards` exists, so the sync never ran (it only ran in tests and after an import). The glossary showed "0 found" for every skill mastered under the MVP.

The rest: a stylus takeover from a resting palm was reported to the drag boards as a tap or a drop (a placed piece could disappear); the parent gate's 30-second lock and miss count reset by tapping Back and "Grown-ups" again; the Deep Dig's geode card could be replaced by the same rock's lantern or badge card; the sieve's rocks did not follow `min_target_px()` after a posture change; a factor-tree piece could be picked mid-crack and a coroutine could resume on a freed tree; the build screen could index past a build's step list; an eased generator limit could exceed the authored one; a cross-check guard never fired (operator precedence); the cross-check never saw the eased problems hint rung 4 swaps in; a stale end-to-end test count; and per-frame allocations in three animated draw paths. All fixed; the suite is green again (**1051 GdUnit4 tests**, **841 pytest**), and a new cross-check run of every skill at difficulty −1 (2,000 problems each) passed.

**Not verifiable here** and still pending, as `status.md` section 5 lists: Charlie's digits against the 97% bar, the device matrices (postures × input, save migration on a device, cross-device round trip, airplane mode, frame times), the native file picker on ChromeOS/Android, the release-signed AAB and the `v1.0.0` tag, the human math review and the Zone 4/5 prerequisite sign-off, the MNIST licence. They are marked as pending in the matrix, not as defects.

---

## 2. Phase 2 compliance matrix

Status values: **Completed** (built and verified by tests or by this read), **Partially Completed** (built, with a documented gap or a pending decision), **Defect Found & Fixed** (built, a defect was found by this review and fixed), **Pending (device/human step)** (a step the plan schedules that cannot be run in this environment).

### 2.1 Non-negotiable rules (CLAUDE.md) and the Version 1.0 exit criteria

| # | Requirement | Status | Evidence |
|---|---|---|---|
| R1 | No network access in the shipped game | Completed | `permissions/internet=false` in both presets (`test_export_presets.py`); lint rule 9 finds no network class or URL in game code; the CI APK job checks the built manifest with `aapt2`; the digit network runs in GDScript with no download. |
| R2 | No data leaves the device except a parent-gated export; no handwriting images | Completed | Only `SaveSystem.export_bundle` and the debug capture screen (both behind `ParentGateScreen`) write outside `user://`. The bundle holds the profile, the attempt log (flags only) and the random device UUID. Strokes are cleared on submit/erase/exit; the capture screen writes stroke JSON only in debug builds. |
| R3 | No new dependency without approval; `docs/sdk-audit.md` complete | Completed | `addons/` holds GdUnit4 only (excluded from exports). The audit lists Godot, Andika, GdUnit4, the project's own digit network and the build-time PyTorch/numpy, and the rejected SDKs (ML Kit, LiteRT, Play Games, a share-sheet plugin) with reasons. |
| R4 | Every child-facing string from `text/lines.csv` via `Text` | Completed | Lint rules 1 and 8 pass; every static and dynamic line id family used by the scenes resolves (checked in the shell/workshop pass); the readability suite asserts no `[missing.id]` is ever shown. |
| R5 | First-grade reading level; pictures; tappable terms; read-aloud from Phase 3 | Partially Completed | Sentence-length lint passes; lint rule 11 ties every math term in a line to a Word Gem; the rule-5 reading for abstract problems stays the recorded open item from Phase 1. Read-aloud is Phase 3. |
| R6 | No `LineEdit`/`TextEdit` in child-facing scenes | Completed | Lint rule 2; the only `LineEdit`s are the nickname field and the family-goal field, both parent-gated (`test_only_the_parent_area_has_a_text_field`). |
| R7 | Touch targets at least 64 dp via `UI.min_target_px()` | Defect Found & Fixed | Every interactive control is a registered touch target except the sieve's 100 rocks, which were sized once from `UI.target_size` and did not follow a posture change (issue 6). Fixed: they are registered with `UI.make_touch_target` and the grid re-lays out on `UI.metrics_changed`. |
| R8 | Wrong answers never cost anything; no timers | Completed | `DigFlow`, `RewardsRules`, `WorkshopRules.craft` (gems spent only after a right answer), `MotivationRules` (a door miss closes the door for a day, never reaches BKT) are pure and tested; a rejected slate reading is logged and returns before BKT (`test_try_again_changes_nothing_the_engine_knows`). |
| R9 | Rewards earned, deterministic; no purchases | Completed | Rare gems come from rare numbers (`gem_for_value`, checked against `rare_numbers.py` to 10,000); badges from mastery only; family points never read speed (a test greps the rules file for `latency`); the garage is coins only. |
| R10 | Math correct: seeded tests plus an independent cross-check per generator | Completed | 22 generators, 22 checkers, 72 skills at 10,000 problems each, green before and after; plus the new eased-difficulty run (issue 11). The generator review found no math defect (section 3, "Checked and found correct"). |
| E1 | Handwriting on both devices; misreads confirm; a rejection never counts; the pad appears where unavailable | Partially Completed | Built and tested with `FakeRecognizer` and the real network; the device half (stylus and finger on the 2-in-1 and the tablet, Charlie's digits against 97%) is pending. Issue 1 fixed the one path where a written answer was lost. |
| E2 | Zones 4 and 5 playable end to end; every generator checked; math reviewer signed off | Partially Completed | 27 Zone 4–5 skills play through the normal mine (`test_zone4_answer_panel`, `test_zone5_answer_panel`, the sieve and tree scene suites); the cross-check is green; the human sign-off is pending (`docs/reviews/2027-04-math-review.md`). |
| E3 | Crafting and both builds work, persist across close, unlock zones | Defect Found & Fixed | End-to-end tests for the pickaxe recipe, resume mid-build and the elevator opening Zone 4 pass. Fixed: a build record at the end of its step list no longer indexes past `steps[]` (issue 8). |
| E4 | Progress round-trips between devices with newest-wins and a verified backup | Partially Completed | `SaveMerge`, the checksum, five backups and the log are unit- and screen-tested (2-in-1 → tablet → 2-in-1 round trip in `test_cross_device.gd`); the real-device round trip and the native picker are device steps. |
| E5 | Badges, Word Gems, Deep Dig, Challenge Door, family points live and earned from mastery and effort only | Defect Found & Fixed | All five are tested. Fixed: Word Gems of a pre-Sprint-19 save are now collected at app start (issue 2); the Deep Dig's geode shares the last rock's celebration instead of racing it (issue 5). |
| E6 | Bolt's poses and key art integrated; 60 fps; under 150 MB | Partially Completed | Six poses, zone tints, banners and the hub art are in; the exported size is 3.5 MB; draw calls are recorded. Frame times on the devices are pending. Three animated draw paths that allocated per frame were tidied (issue 13). |
| E7 | Every save from every tagged release migrates, in tests and on a device | Partially Completed | The v1 and v2 fixtures migrate and load through the whole system in tests; the on-device update-over-MVP step is pending. |
| E8 | Zero crashes across 5 playtest sessions; airplane mode | Pending (device/human step) | No runtime script error in any suite or in the headless startup run. |
| E9 | Every child-facing string from the table; lint and all suites pass on the release commit | Completed | Section 5. |
| E10 | No `INTERNET`; no SDK without an audit entry | Completed | As R1 and R3. |

### 2.2 Sprint backlog items

| Item | Deliverable | Status | Notes |
|---|---|---|---|
| P2-S12-01, -04 | Playtest triage; difficulty tuning from logs | Pending (device/human step) | No play log exists; `tools/bkt/gate_report.py` is the tool for both once a bundle exists (decisions, Sprint 12). Nothing was invented. |
| P2-S12-02, -03 | BKT fit pipeline; fitted values used from 30 samples | Completed | `tools/bkt/fit.py` (EM with a MAP pull; pytest recovers known parameters), `BKT.params_for_skill`; `bkt_fitted.json` is shipped empty on purpose. |
| P2-S12-05 | Debug-only stroke capture screen | Completed | `StrokeCapture.is_enabled()` is `OS.is_debug_build() and` the project setting; strokes only, never a picture; export is parent-gated. |
| P2-S13-01 … -05 | Handwriting: plugin skeleton, dataset, model, ML Kit benchmark, decision | Completed (with a recorded deviation) | Spiro's decision replaced the Kotlin/LiteRT plugin with a GDScript network; ML Kit was skipped (needs `INTERNET`). Measured numbers are honest (97% not yet shown on Charlie's digits). `android/plugins/digit_ink/` is an empty placeholder with a README. |
| P2-S14-01 | `ChalkSlate`, `DigitBox`, Clear, Done | Defect Found & Fixed | Built and tested. Fixed: the answer is reported before the digits that bring the coaching demo (issue 1). |
| P2-S14-02 | Palm rejection in `InputRouter` | Defect Found & Fixed | Stroke-level rejection and takeover are tested. Fixed: a taken-over palm is now cancelled, not lifted, so drag boards never read it as a tap or drop (issue 3). The ChromeOS stylus delivery path is still the unverified Sprint 1 device item. |
| P2-S14-03 | Confirmation bubble; a rejection ignored by BKT | Completed | `SlateReader` is pure and tested; `Adaptive.record` returns before BKT on `low_confidence_rejected`; `confirmed` is logged for the dashboard. |
| P2-S14-04 | Slate vs number pad from `answer_modes`, device capability, parent setting | Completed | `DigitInk.is_available()` (weights + touch screen, or the debug force setting) and `DeviceSettings.handwriting_enabled()`; mouse-only machines never see the slate. |
| P2-S14-05 | Numeral coaching, parent setting, default off | Defect Found & Fixed | `NumeralCoach` is pure and tested; the demo never blocks submitting. Fixed: the demo keeps the panel asleep like the Word Gem card, and the answer that triggers it is no longer dropped (issue 1). |
| P2-S14-06 | Slate lines | Completed | 14 `input.slate.*` lines; lint passes. |
| P2-S14-07 | Decision-gate memo | Pending (device/human step) | The memo's template is in the decisions log; the numbers need Charlie's log. |
| P2-S15-01 … -04 | Zone 4 skill map; mult/div facts; factors/multiples; prime/composite generators | Completed | 15 skills; `MathUtil` tested against brute force to 1,000; one checker per generator; prerequisite sign-off pending. |
| P2-S15-05 | `BoulderSplit` | Defect Found & Fixed | Finger, pen and mouse through `InputRouter` (tested). Fixed: a taken-over palm drops the pickaxe without a split (issue 3). |
| P2-S15-06 | Rare gems | Completed | `RewardsRules.gem_for_value` against `rare_numbers.py` for 1–10,000; the Mersenne list is complete to 10,000. |
| P2-S15-07, -09 | Zone 4 lines; asset-credit lint | Completed | Lint rule 10 found and credited the weights file. |
| P2-S15-08 | Artist brief | Completed (not sent) | `docs/art/bolt-brief.md`; Spiro chose no commission. |
| P2-S16-01 … -06 | Recipes, crafting screen, build framework, cart track, elevator, lines | Defect Found & Fixed | Crafting spends gems only on a right answer; a step is saved at once; the elevator opens Zone 4 unless the child already dug there. Fixed: a build record at `step == step_count` with `done` false is treated as built (issue 8). |
| P2-S17-01 | Save schema v2, migration, fixtures | Defect Found & Fixed | One v1→v2 migration; `validate` requires the new dictionaries only from v2; the v1 and v2 fixtures load through the whole system. Fixed: the Word Gem catch-up the migration delegates to `Rewards` now runs at app start (issue 2). |
| P2-S17-02, -03 | Export via the system picker; import with validation, newest-wins, backup, the parent's choice | Partially Completed | Built with Godot's native file dialog (no share-sheet plugin, a recorded decision); whether the picker returns a writable path on ChromeOS and the tablet is a device step. |
| P2-S17-04, -05 | Import/export log on the dashboard; the decision | Completed | `sync_log.json` is device-only; the dashboard shows the last 10; decisions entry with alternatives. |
| P2-S18-01 … -09 | Zone 5 skill map, sieve, sieve grid, factor tree generator and scene, divisibility, FTA, rare-gem drops, lines | Defect Found & Fixed | 11 skills, 4 generators, 4 checkers, 10,000 problems each; 127 is diggable. Fixed: sieve rocks follow a posture change (issue 6); a tree piece cannot be picked mid-crack and the pause no longer awaits on a node that may be freed (issue 7). |
| P2-S19-01 | Badges | Completed | Four badges from mastery only; checked on every mastery so a lapsed skill won back can complete one. |
| P2-S19-02 | Word Gems glossary | Defect Found & Fixed | Issue 2. |
| P2-S19-03 | Weekly Deep Dig | Defect Found & Fixed | Once per ISO week, immune to a clock set back; the geode now joins the last rock's celebration (issue 5). |
| P2-S19-04 | Challenge Door | Completed | At least three problems at the hardest settings, more while a guesser's chance exceeds 1/64; a miss closes the door for a day and never reaches BKT; 10,000-door simulation in `test_challenge_door.gd`. |
| P2-S19-05, -06 | Family points, parent goals, lines | Completed | Points per key, idempotent; nothing reads speed; goals and claims are parent-gated. |
| P2-S20-01 … -04 | Bolt's poses, zone art, music and SFX, animation polish | Defect Found & Fixed | All in, CC0 and code-drawn, OGG, credited. Fixed: three animated draw paths no longer allocate per frame (issue 13). |
| P2-S20-05 | Accessibility pass, four aspect ratios | Completed | Screenshots under `docs/qa/screens-1.0/`; one real layout bug was caught and fixed in the sprint. |
| P2-S20-06 | Feel-issue batch | Pending (device/human step) | No playtest notes exist yet. |
| P2-S21-01 | Dashboard v2 | Completed | Skill map from `Adaptive.skill_states()`; weekly summary incl. the confirmation rate; `test_dashboard_v2.gd`. |
| P2-S21-02 | Math review of Zones 1–5 | Pending (device/human step) | The packet and the AI pre-review exist; the human session is Spiro's. |
| P2-S21-03, -04, -05 | Save-migration matrix, posture/input matrix, release AAB and tag | Pending (device/human step) | `docs/qa/release-1.0.md`; the automated half is green. |
| P2-S21-06 | Retrospective; `CLAUDE.md` current phase | Completed | `docs/phases/phase-2-retrospective.md`; `CLAUDE.md` names Phase 3 as next. |

### 2.3 Engine idioms and quality checks (what was looked for, and found sound)

- **Godot 4 only.** No `yield`, `emit_signal`, `onready`/`export` without `@`, `.method()` super calls, `File.new()` or `instance()` anywhere outside `addons/`. `untyped_declaration` is an error in `project.godot` and the suites pass under it.
- **Lifecycle.** No `_process` or `_physics_process` exists in the game scenes; animation is tweens and `CPUParticles2D`. Every `InputRouter` consumer connects in `_ready` and disconnects in `_exit_tree`; every `await` continuation that touches a node checks `is_inside_tree()` (one that did not is issue 7). Autoload order is consistent with every cross-reference in `_ready` except the one in issue 2.
- **Signals.** Scenes connect to autoload signals once per fresh instance and rely on Godot's disconnect-on-free, which is correct for method callables and for lambdas that reference `self`, and **not** for a lambda that captures only locals (it has no bound object, so the autoload keeps calling it after the scene is freed; see issue 13). Phase 1's pause/overlay gating of the drag boards still holds; the stroke demo now gates the panel the same way (issue 1).
- **Node references.** Every `%Unique` used by an `@onready` in `mine.tscn` exists with `unique_name_in_owner`; the other `.tscn` files are single-node wrappers with consistent `ext_resource` ids; no `uid://` value was edited. One note: `hub.gd` re-parents `%DigButton`, which clears its owner (nothing uses the `%` path after `_ready`; see section 4).
- **Save points.** After every rock (`_pay_rock`), after every crafted recipe and finished build step, when leaving a screen, on a posture change, on `NOTIFICATION_APPLICATION_PAUSED` / `WM_CLOSE_REQUEST`; every settings change saves.
- **Randomness.** `scripts/generators` and `scripts/core` use only the passed `rng` (no `randi()`, `shuffle()`, `pick_random()`, `randomize()` outside the parent gate's own question rng). Every rejection-sampling loop is bounded with a valid fallback.

---

## 3. Issues identified and remediation

### Issue 1 (medium): a written answer was dropped when the numeral-coaching demo fired on submit

- **Where:** `scenes/input/chalk_slate/chalk_slate.gd` (`_submit`), `scenes/mine/mine.gd` (`_show_stroke_demo`, `_on_state_changed`, `_on_word_gem_closed`), `scenes/mine/answer_panel.gd` (`_on_value_given` forwards only while enabled).
- **Trigger:** `settings.handwriting_coaching` on (a parent switch, default off); the child writes the same digit backwards for the third time this visit and taps Done (a sure reading, or Yes to "Did you write…?").
- **Root cause:** `_submit` emitted `digit_read` for every box, then `answer_submitted`. The mine's `digit_read` handler showed the stroke demo and called `_panel.set_enabled(false)`; `answer_submitted` then arrived at a disabled panel and was dropped. The strokes were already wiped, nothing was logged, the rock stayed open. Not a cost (no wrong attempt), but a lost answer with no feedback. A second gap: once the demo was up, `WOBBLE → HINT → AWAIT_ANSWER` re-enabled the panel under the demo's dimmer (digit boxes take `InputRouter` strokes regardless of GUI overlays).
- **Fix:** `_submit` takes a copy of the readings, clears the boxes, emits `answer_submitted` first, then `digit_read`. The mine keeps `_demo_overlay` and a `_overlay_up()` helper (Word Gem card or demo); `AWAIT_ANSWER` and the card's close re-enable the panel only when nothing is over it; the demo's close clears the reference and re-enables the panel if the rock is still open. `AnswerPanel.is_enabled()` was added for the test.
- **Test:** `test_mine_slate.gd::test_the_answer_that_brings_the_demo_is_still_an_answer` (the attempt is logged on the demo rock; the panel sleeps under the demo and wakes when it closes). Fails against the old `_submit`.

### Issue 2 (medium): Word Gems of an MVP save were never collected at a real app start

- **Where:** `autoload/rewards.gd` (`_ready`), `autoload/save_system.gd` (`_ready` → `load_profile` → `profile_loaded`), `scripts/save/migrations/v1_to_v2.gd` (its header delegates Word Gem collection to `Rewards.sync_word_gems` "on load").
- **Trigger:** install the Phase 2 build over the MVP's v1 save (mastered skills, no `motivation.word_gems`), cold start, Museum → Glossary: "0 found", every term locked; Bolt's term chips for those words missing until an import replaces the save or the skill is mastered again.
- **Root cause:** autoload order is Text, UI, InputRouter, SaveSystem, Adaptive, Rewards; each autoload's `_ready` runs as it is added. `SaveSystem` emitted `profile_loaded` before `Rewards` existed to hear it. `sync_word_gems` was called from nowhere else in the game (only `tools/qa/capture_screens.gd` called it by hand). The existing test loaded the profile after all autoloads existed and so passed.
- **Fix:** `Rewards._ready` calls `sync_word_gems()` after connecting (Adaptive and Text, which it needs, are already up).
- **Test:** `test_rewards.gd::test_word_gems_of_an_older_save_are_collected_when_the_autoload_starts` (a fresh `Rewards` node added to the tree against a save with a mastered skill and no Word Gems). Fails against the old `_ready`.

### Issue 3 (medium/low): a palm the pen took over from was reported to drag boards as a tap or a drop

- **Where:** `autoload/input_router.gd` (`_take_over`), `scenes/input/build_board.gd`, `tile_board.gd`, `array_builder.gd`, `scenes/mine/boulder_split/boulder_split.gd`.
- **Trigger:** on a build board, tile board, array builder or boulder split, the child rests a palm on a placed piece (or a pile) and then the stylus comes down and reports a tilt or the eraser end (the takeover rule). Depends on the device reporting tilt; without it there is no takeover and no bug.
- **Root cause:** the takeover emitted `pointer_up` for the palm at its down position so "nothing is left held". For a board, a `pointer_up` within the tap slop of its `pointer_down` *is a tap*: a placed piece was removed (or a pile piece added) before the pen's own `pointer_down`. The stroke path already had `stroke_cancelled` for this; the pointer path had no equivalent.
- **Fix:** a new `InputRouter.pointer_cancelled(index)` signal, emitted in `_take_over` instead of `pointer_up`. Each board connects it (and disconnects in `_exit_tree`): `BuildBoard` puts a piece picked up from the tray back in the tray and discards one taken from a pile, announcing nothing; `TileBoard` and `ArrayBuilder` end the drag/press without acting; `BoulderSplit` drops the pickaxe back without a split.
- **Tests:** `test_input_router_pen.gd` (the takeover now logs `dropped 0`, never `up 0 0`); `test_drag_and_build.gd::test_a_palm_resting_on_a_placed_piece_is_not_a_tap_when_the_pen_takes_over`. Both fail against the old `_take_over`.

### Issue 4 (low, parent gate): the 30-second lock and the miss count reset by leaving the gate

- **Where:** `scenes/shell/parent_area/parent_gate.gd` (`_ready` built fresh `ParentGateRules`; `Shell._swap_screen` instantiates a new screen on every visit; Back stays enabled while locked).
- **Trigger:** three wrong answers → "wait" → Back → "Grown-ups": a new gate with three fresh tries and no cooldown. The odds per guess (about 1/900) still keep the gate shut, but the stated defence ("random tapping cannot get through") did not hold.
- **Fix:** `ParentGateScreen` remembers `locked_until_ms` and `misses` in static vars across instances; `_ready` restores them into the rules and shows the locked state when the lock is still running; `_on_submitted` writes them back. `forget_lock()` resets them (tests).
- **Tests:** `test_parent_area.gd::test_the_lock_outlives_leaving_the_gate_and_coming_back` and `::test_misses_carry_over_when_the_gate_is_opened_again`. Both fail without the memory.

### Issue 5 (low): the Deep Dig's geode card could be replaced, and `_after_rock` could run twice

- **Where:** `scenes/mine/mine.gd` (`_on_gem_landed`, `WALL_CLEAR` → `_deep_dig_wall_done`).
- **Trigger:** the last Deep Dig rock also earned a celebration of its own (the day's first lantern, a badge from a re-mastered lapsed skill, a mineral). `flow.gem_dropped()` reached `WALL_CLEAR` and `celebrate([geode])` *inside* `_on_gem_landed`, which then called `celebrate(pending)` in the same frame: the geode's labels and art were freed and replaced, the `deepdig.mine.done` line was never seen, and both coroutines tweened the same art nodes. With nothing pending, `_after_rock()` ran at once and again on `closed`.
- **Fix:** `_deep_dig_wall_done` appends the geode to `_pending_celebrations`; `_on_gem_landed` shows everything the rock earned in one card and `_after_rock` runs once, on `closed`.
- **Test:** `test_motivation_screens.gd::test_the_geode_joins_the_last_rocks_celebration_instead_of_replacing_it` (a new day before the last rock: the card shows both `bolt.celebrate.lantern` and `deepdig.mine.done`). Fails against the old `_deep_dig_wall_done`.

### Issue 6 (low, rule 7): sieve rocks did not follow `min_target_px()` after a posture change

- **Where:** `scenes/zones/z05_prime_caverns/sieve_grid.gd` (`setup`).
- **Trigger:** open a sieve problem in laptop posture, flip to tablet mid-problem: the 100 `Button`s kept the old canvas size (`UI.min_target_px()` depends on the window's scale; only controls registered with `make_touch_target` are re-sized).
- **Fix:** each rock is registered with `UI.make_touch_target`; the grid connects `UI.metrics_changed` to `_relayout`, which re-sizes the scroll width and the digit font.
- **Test:** `test_sieve_grid.gd::test_rocks_are_touch_targets_that_follow_a_posture_change` (halves the window; the rocks and the grid width follow the new `min_target_px`). Fails against the old `setup`.

### Issue 7 (low): a factor-tree piece could be picked mid-crack; the pause awaited on a node that may be freed

- **Where:** `scenes/zones/z05_prime_caverns/factor_tree.gd` (`pick`, `_pause`, `_on_split_chosen`, `_on_prime_declared`).
- **Trigger:** during the 0.5 s pause after a split, the two new leaf buttons were already enabled; tapping one called `_split.setup()`, which killed the crack tween mid-animation, and when the pause ended `_pick_next` overrode the child's pick. Separately, Done during the pause with a wrong hand-in on the fourth miss swaps the panel; the tree was freed before the timer fired and the coroutine resumed on a gone instance (an error log in debug builds; noise, not corruption).
- **Fix:** `pick` returns false while `_busy`. The pause is a one-shot connection to the timer's `timeout` carrying the continuation (`_pause(then)` / `_end_pause`) instead of an `await`: a freed tree is simply never called back.
- **Test:** `test_factor_tree_scene.gd::test_no_rock_can_be_picked_during_the_pause_after_a_split`. Fails against the old `pick`.

### Issue 8 (low): the build screen could index past a build's step list

- **Where:** `scripts/workshop/workshop_rules.gd` (`build_state` clamped `step` to `step_count` but trusted `done`), `scenes/workshop/builds/build_screen.gd` (`_build.steps[index]`).
- **Trigger:** a record `{step: N, done: false}` with `N == step_count` (a build whose step list later shrank in `builds.json`, or an edited save): an out-of-range error every time the build is opened.
- **Fix:** `build_state` reports `done` when `step >= step_count` whatever the record says; `finish_step` then refuses as for any finished build.
- **Test:** `test_workshop_rules.gd::test_a_record_at_the_last_step_counts_as_built_even_without_done`. Fails against the old `build_state`.

### Issue 9 (low, generators): an eased limit could exceed the authored one; a degenerate column range

- **Where:** `scripts/generators/generator_kit.gd` (`eased_max`: `clampi(scaled, low + minimum_span, high)` returns the floor when it is above `high`), `scripts/generators/arrays.gd` (`_build` with `max_cols` 2 and rows 2 asked `randi_range(2, 1)`).
- **Reach:** not reachable with the shipped curriculum parameters (every call's floor is at or below its `high`, enumerated by the generator review); a hazard for the Phase 4 zones.
- **Fix:** the floor is `mini(low + minimum_span, high)`; the array builder keeps at least three columns so a column count other than `rows` always exists.
- **Tests:** new `tests/generators/test_generator_kit.gd`; `test_arrays.gd::test_a_two_column_builder_still_makes_rows_and_columns_differ`. Both fail against the old code.

### Issue 10 (low, checker): the counting checker's range guard never fired

- **Where:** `tools/crosscheck/checkers/counting.py:77`: `if not 1 <= first and answer <= 120` parses as `(first < 1) and (answer <= 120)`.
- **Reach:** the generator caps at 120, so nothing slipped; the guard was simply inert.
- **Fix:** `if not (1 <= first and answer <= 120)`. **Test:** `test_checkers.py::test_the_range_guard_catches_a_too_large_answer`.

### Issue 11 (coverage): the cross-check never saw the eased problems hint rung 4 swaps in

- **Where:** `tools/crosscheck/export_problems.gd` cycled representations only; `run.py` had no difficulty option. Rung 4 regenerates the same skill at `difficulty − 1`, which changes every range (`eased_max`) and several branches (`addition` near gate, `compare` conflict gate, `multiplication` and `factors` pools). The checkers' docstrings claimed to bound the easier problems but never received one; the GdUnit suites check structural invariants at low difficulty, not the independent math.
- **Fix:** `--difficulty` on the exporter and the runner (passed through only when non-zero, so the default export is byte-identical; the file name carries `.d-1`). **Run:** `python tools/crosscheck/run.py --all --n 2000 --difficulty -1`: **72 skills, all passed.** **Test:** `test_checkers.py::test_difficulty_reaches_the_exporter_and_names_the_file`.

### Issue 12 (test): a stale end-to-end count

- `tools/crosscheck/test_checkers.py::test_end_to_end_every_skill` expected 61 "ok" lines (Zones 1–4). It only runs with `GODOT` set, which the pytest CI job does not, so it has been silently wrong since Zone 5 (72 skills). It now compares against `len(run.load_skills())`.

### Issue 13 (perf, low): per-frame allocations in animated draw paths

- `scenes/workshop/workshop_art.gd` built two `PackedVector2Array`s on every redraw of the crystal lamp, which the hub tweens in a loop (a 60 fps path while the lamp sits on the shelf): the arrays are now members filled in place. `scenes/mine/bolt.gd` looked up `Rewards.headlamp()` (a dictionary read and a String) on every frame of a pose tween: the lamp color is now a cached property set by `Bolt` and on `headlamp_changed` through a bound method. (The first attempt used a lambda capturing the local `figure`; a lambda that references no `self` is not disconnected when its `Bolt` is freed, and the autoload's next emit hit a freed capture 844 times across the suite. The full-suite run caught it; the connection is a method now, and the lesson is in section 4.) `scenes/input/chalk_slate/digit_box.gd` allocated its guide-fraction array on every redraw: now a constant. `perf_check.py` scans `_process` only, so none were flagged; see section 4.

### Checked and found correct (no change)

- **Save layer:** atomic write order and every `crash_after` seam; `.bak` only copied when the current profile is valid; `read_profile` order profile → tmp → bak; the attempt log's half-line repair; `write_attempts` via `.tmp` + rename; `import_bundle` refusals (read-only, not a bundle, newer bundle, checksum, bad profile, no saved time) all before any write; backups before replace, newest five kept; the log outside the save; `SaveMerge` string ordering of ISO UTC stamps; `ProgressBundle.merge_attempts` dedup key and ordering; the checksum computed after a JSON round trip at full precision.
- **Adaptive:** `record_answer`'s first-try / hinted / later-wrong policy; the guessing guard's floor; mastery (P(L), two days, evidence, fluency median); review stages 1/3/7/21/60; lapse resets `correct_days` and keeps `mastered_at` (so a win-back is `first_time = false`); `master_by_challenge` keeps `mastery_evidence`; `challenge_problems`' luck bound; `Scheduler`'s locked zones, resting rule, 30% review share, interleave of three, no-triple-repeat; `Placement`'s two-probe pass, ancestors/successors, done conditions; `BKT.with_chance` capped at 0.99; fitted values only from 30 samples.
- **Rewards and motivation:** `pay_rock` once per rock in `GEM_DROP` before the gem flies, then a save; the lantern streak is a count of lit days (a missed day pauses it); `buy` never overspends; `WorkshopRules.craft` re-checks `can_craft` before spending; `finish_step` is one-shot; `award_points` idempotent per key; `claim_goal` refuses when short; `earn_badges` once per badge from mastery only (placement passes do not count); Deep Dig once per ISO week, immune to a clock set back; door offers only practised frontier skills.
- **Handwriting:** `DigitNet.forward`'s zero-padded 30×30 / 16×16 indexing and channel-major flatten; `read`'s softmax over the ten digit logits and the sigmoid mirrored flag; `StrokeRaster`'s bounding box, 20 px fit, centre of mass, brush stamping (fixtures agree with the Python twin); `SlateReader`'s leading-zero, incomplete, unreadable, unsure rules; `DigitInk.is_available` (weights + touch screen or the debug setting); `NumeralCoach` once per digit per session.
- **Input:** first-finger-only, emulated-mouse drop, left-button-only, `pen_stroke_active` on both the touch and the mouse-motion stylus paths; every board gates on `is_visible_in_tree()` and `can_process()` and cancels on `NOTIFICATION_PAUSED`.
- **Generators (the review's full list):** no global randomness; every rejection loop bounded; no division by zero or negative modulo; answers and every named distractor for all 22 generators re-derived; every distractor-equals-answer collision handled by `add_distractor`'s dedup (the review enumerated them, e.g. repdigits in `count.write.numeral` end with zero distractors, which is allowed for a number-pad skill); every skill names a registered generator; the 176-skill prerequisite graph is a DAG; every misconception and line id exists; `rare_numbers.json` complete to 10,000; every generator has a non-trivial checker that recomputes answers, distractors, the hint model and the worked example from the JSON.
- **Project and presets:** both presets `permissions/internet=false`, `user_data_backup/allow=false`, arm64-v8a + x86_64, target SDK 36, sensor landscape; `gem_mines/debug/capture_enabled=true` is harmless because `is_enabled()` also requires a debug build; the debug overlay is inert in release.

### Noted, not changed (see section 4)

- **A.** The headless startup run reports four leaked `AudioStream*` instances and the hub loop "still in use" at exit. It is the music playback still running when the tree quits; stopping the players and dropping the stream in `Shell._exit_tree` changed nothing (the `AudioServer` holds the playback until its next mix, which the headless Dummy driver never runs), so the change was not kept. Exit-time only; no effect on a session.
- **B.** A badge or Word Gem completed by an answer outside the mine (a crafting-bench problem, a build step, the Challenge Door) is saved but not shown there; the workshop screens show only their own line. Nothing is lost; the "earned" moment is missed.
- **C.** `IconArt.attach` installs duplicated stylebox overrides, so icon buttons keep their old padding after a posture change (touch-target size itself follows). `hub.gd` re-parents `%DigButton`, which clears its owner; nothing uses the `%` path after `_ready`.
- **D.** `StyleBoxFlat.new()` per `_draw` in `array_builder.gd`, `drag_item.gd`, `visual_model.gd` and `tile_board.gd` (redraw-only, not per frame). `DigitBox._draw_stroke` makes a transformed copy of each stroke per redraw (redraws on every stroke point; bounded at 256 points).
- **E.** Documentary parameters: `multiples_of_ten` on `add.to_100.tens` / `sub.to_100.tens` is read only by the Python checkers; `parity.even_odd.pairs` lists `parity_swapped` but its mode never emits it. The checkers for the factor tree, prime/composite, factors and sieve mirror the GDScript's *layout* thresholds (array vs hops, `MAX_SIDE`, `MAX_HOPS`); all math values still come from definition-based `numbers.py`.

---

## 4. Technical debt and architectural notes before Phase 3

1. **Autoload start-up order is an implicit contract.** Issue 2 was a `_ready`-order bug invisible to every test, because tests load profiles after all autoloads exist. Before Phase 3 adds `Narration` and `Profiles` (both of which will react to `profile_loaded` and the active profile), consider one explicit start: `SaveSystem` stops emitting from its own `_ready`, and the Shell (or a small `Game` autoload last in the list) calls `SaveSystem.load_profile()` once every listener is connected. The `Profiles` switch is the same shape as an import (`profile_loaded` → every autoload resets), so it should go through that one path. A startup test that instantiates the autoload chain from `project.godot` in order would have caught issue 2.
2. **Overlay gating of the answer panel is now in two places** (`_overlay_up()`: the Word Gem card and the stroke demo). Phase 3's read-aloud replay button and any narration bubble that pauses input should use the same helper rather than a third flag; better still, a single `ModalLayer` in the mine that owns "what is over the panel" and emits one `cleared` signal.
3. **Autoload signal connections from scenes should be methods, or lambdas that touch `self`.** Issue 13's first fix showed the failure mode: a lambda over a local is never disconnected when the scene goes. A lint rule (a `.connect(func(` whose body names no member) would be cheap; Phase 3's `Narration` and `Profiles` signals will multiply these connections.
4. **`InputRouter` now has a complete pointer vocabulary** (`down / move / up / cancelled`). Any new widget in Phase 3 (profile picker tiles, the replay button if it is a drag target) must implement `cancelled`; a test helper that asserts every `pointer_down` connector also connects `pointer_cancelled` would make that mechanical.
5. **`perf_check.py` only scans `_process`.** Issue 13's allocations were in `_draw` on tweened properties, which is the project's actual per-frame path (there is no `_process` anywhere). Extend the check to `_draw` bodies of classes with a `queue_redraw()` in a property setter, or add a rule that `_draw` may not contain `PackedVector2Array([`, `StyleBoxFlat.new()` or an Array literal.
6. **The cross-check's difficulty dimension should be in CI.** Issue 11's `--difficulty -1` run passed, but only as a one-off here. Add `--difficulty -1 --n 2000` to the CI job (about the cost of the existing run at 2,000) so rung-4 problems stay covered as Phase 4 adds generators; `--difficulty -2` is cheap to add too.
7. **The parent gate's memory is static state on a screen.** It is the smallest fix (issue 4) and correct for one child per device; with Phase 3 profiles it stays per device, which is what a gate wants. If the gate ever moves into `DeviceSettings`, that is the place for it (not the child's save).
8. **Handwriting 97% bar.** Everything is in place to measure it (`tools/handwriting/evaluate.py`, the capture screen) and nothing has been measured on real writing. This is the single biggest unknown for Version 1.0 and should be the first device session, before any Phase 3 narration work makes the slate harder to change.
9. **Phase 3 save migration (v2→v3 profiles).** The v1→v2 migration keeps everything under one document and `SaveSchema.with_defaults` fills gaps; a `profiles[]` wrapper with the current document as profile 0 is straightforward. Two things to decide first: whether device-only state stays in `device_settings.cfg` (recommended; nothing about a child goes there) and whether `sync_log.json` and the backups become per profile. The import path (`SaveMerge`) will need the profile id in the bundle.
10. **Exit-time audio report (note A).** If it bothers the device QA logs, the cleanest fix is a `Shell` handler for `NOTIFICATION_WM_CLOSE_REQUEST` that fades out and quits a frame later; not worth it before a device shows a real effect.
11. **Celebrations outside the mine (note B)** are a Phase 3 polish item: a shared `Celebration` host in the Shell that any screen can hand pending items to, so a badge earned on the bench is seen there.

---

## 5. Verification record

All runs are in this environment (Godot 4.7.2 stable Linux headless, Python 3.13); nothing needing a device, a renderer or the keystore was run.

| Check | Baseline (before any change) | After the fixes |
|---|---|---|
| Headless import | clean | clean |
| Main scene, 3 frames headless | clean (note A at exit) | clean (note A at exit) |
| GdUnit4 (`runtest.sh -c -a res://tests`) | 1039 tests, 95 suites, 0 failures, 0 orphans (9 m 51 s) | **1051 tests, 96 suites, 0 failures, 0 orphans** |
| pytest (`tools`) | 839 passed, 34 skipped | **841 passed, 34 skipped** |
| `lint_content.py` | 0 errors, 0 warnings | 0 errors, 0 warnings |
| `perf_check.py` | 0 problems, exported 3.5 MB | 0 problems, exported 3.5 MB |
| `curriculum_check.py` | 0 problems | 0 problems |
| Cross-check, 72 skills × 10,000 | all passed | all passed (generators changed: `arrays.gd`, `generator_kit.gd`) |
| Cross-check, 72 skills × 2,000 at difficulty −1 | (not possible before issue 11) | **all passed** |
| Regression tests vs. the unfixed sources | — | every new test fails against the reverted source and passes with the fix (reverted file by file, see the issue entries) |

The 34 pytest skips are the handwriting trainer (needs PyTorch and the MNIST download), the private-digit loader (no `private/`), and the cross-check end-to-end tests when `GODOT` is unset (they were run with it set).

---

## 6. Status synchronization

`status.md` was updated in this change: the header (date, branch, commit), a "Recent changes" entry for this review, the health check with the numbers above, and one new line in "Immediate next steps" (the CI follow-ups: items 3, 5 and 6 of section 4). The open items in its section 5 are unchanged: none was closed by code, and the review added none. `docs/decisions.md` has an entry for this review's two small design choices (`InputRouter.pointer_cancelled`; the parent gate's lock memory).
