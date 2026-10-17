# Peer review 01: Phase 1 (Sprints 1–11) code audit

**Date:** 2026-10-17
**Scope:** everything built for Phase 1 of `docs/development-plan.md` (section 8.2) and `docs/phases/phase-1-ramp-up-to-mvp.md`: the six autoloads, `scripts/`, every scene under `scenes/`, `project.godot`, `export_presets.cfg`, the curriculum data, the text table, the Python tools and the test suites. Phase 2 and later work was not touched.
**Method:** a full read of every script, scene file and test; a clean headless import; the GdUnit4 suites, pytest, the content lint, the static performance check and the 10,000-problem Python cross-check, all run before any change (the baseline) and again after the fixes. Fixes were made test-first: each defect got a failing regression test, then the fix, then the suite was re-run.

---

## 1. Executive summary

**The Phase 1 codebase is in good shape and stable.** It does what the plan says, in the shape the plan says, with the architecture rules of `CLAUDE.md` respected throughout:

- Game logic lives in `scripts/` as plain, typed, node-free classes (`DigFlow`, the generators, `AdaptiveEngine`, `Scheduler`, `Placement`, `RewardsRules`, `SaveStore`); scene scripts present them and talk to autoloads through signals and methods. There is no scene reaching into another scene's nodes.
- Every child-facing word comes from `text/lines.csv` through `Text`; no `LineEdit` exists outside the parent area; every interactive control sizes itself from `UI.min_target_px()`; there is no network class, no `INTERNET` permission, no randomness in rewards and no path by which a wrong answer costs anything. The lint and the suites enforce each of these.
- GDScript is statically typed everywhere (`untyped_declaration` is an error in `project.godot`) and uses Godot 4 idioms only (`@onready`, `@export`, typed signals, `create_tween()`, `FileAccess`, `instantiate()`). No Godot 3 forms were found.
- The math is right as far as 10,000 seeded problems per skill can show: the 45 Zone 1–3 generators pass their GdUnit4 invariants and the independent Python checkers.
- The baseline was green before the review: **675 GdUnit4 tests in 58 suites, 533 pytest tests (15 skipped by design), lint 0 errors / 0 warnings, perf check 0 problems, headless startup clean.**

**Seven issues were found and fixed** (section 3). The two that matter for a child's session are both in how input reaches the drag boards and how a cracked rock is paid:

1. A tap on the pause menu or on the Word Gem card's dimmer also reached the drag board underneath (`BuildBoard`, `TileBoard`, `ArrayBuilder`), because `InputRouter` sees every event before the GUI does and a signal still reaches a paused node. Closing the card by tapping outside it could add a piece to the child's answer.
2. A cracked rock was paid (coins, gem, lantern) only when its flying gem landed in the cart, so leaving the mine during the flight lost a reward the child had already earned.

The remaining five are an import that bypassed the newer-save guard, per-event string work in the debug overlay in release builds, a theme that went stale after a posture change, a coroutine that could run on a freed node, and an incorrect claim in the SDK audit. All seven are fixed, each with a regression test where one is possible, and the full suite is green again (**684 GdUnit4 tests**).

**Not verifiable here:** the device-only Sprint 1 and Sprint 11 steps (stylus behaviour on ChromeOS, posture switching on the real 2-in-1, the airplane-mode session, the profiler captures, the release AAB, Charlie's first session). They are listed as pending in the matrix, not as defects.

---

## 2. Phase 1 compliance matrix

Status values: **Completed** (built and verified by tests or by this read), **Partially Completed** (built, with a documented gap or a pending decision), **Defect Found & Fixed** (built, a defect was found by this review and fixed), **Pending (device step)** (a human or device step the plan schedules that cannot be run in this environment).

### 2.1 Non-negotiable rules (CLAUDE.md) and MVP acceptance criteria

| # | Requirement | Status | Evidence |
|---|---|---|---|
| R1 | No network access in the shipped game | Completed | `permissions/internet=false` in both presets (checked by `tools/ci/test_export_presets.py`); lint rule 9 finds no network class, `OS.shell_open` or URL in game code; the CI APK job checks the built manifest with `aapt2`. |
| R2 | No data leaves the device except a parent-gated export | Completed | Only `SaveSystem.export_bundle`, called from `DashboardScreen` behind `ParentGateScreen`, writes outside `user://`. No handwriting yet (Phase 2). |
| R3 | No dependency without approval; `docs/sdk-audit.md` complete | Defect Found & Fixed | The audit claimed GdUnit4 is excluded from exports; it is not (the preset's `exclude_filter` omits `addons/gdUnit4/*`, already flagged "Needs Spiro" in `docs/decisions.md`). The audit row now says so. |
| R4 | Every child-facing string from `text/lines.csv` via `Text` | Completed | Lint rule 1 (hard-coded text) and rule 8 (every id used exists) pass; `test_readability.gd`, `test_shell.gd` and `test_mine.gd` assert no `[missing.id]` or `{placeholder}` is ever shown. |
| R5 | First-grade reading level, picture beside every instruction, tappable terms | Partially Completed | Sentence-length lint passes with 0 warnings; Word Gems work for every term (`test_word_gems.gd`). The "picture beside every instruction" check for abstract problems is a recorded open reading of rule 5 ("Needs Spiro", Sprint 5 decision). Andika is not imported (approval pending). |
| R6 | No `LineEdit`/`TextEdit` in child-facing scenes | Completed | Lint rule 2 and the scene tests; the only `LineEdit` is the nickname field in `dashboard.gd`. |
| R7 | Touch targets at least 64 dp via `UI.min_target_px()` | Completed | Every interactive control goes through `UI.make_touch_target()`; `test_shell.gd`, `test_mine.gd`, `test_readability.gd` and the input suites assert it. No hard-coded interactive sizes found. |
| R8 | Wrong answers never cost anything; no timers | Completed | `DigFlow` and `RewardsRules` are pure and tested for this (`test_dig_flow.gd`, `test_rewards_rules.gd`); the wind-down shows counts, never a clock; the lantern streak only grows. |
| R9 | Rewards earned and deterministic; no purchases | Completed | `RewardsRules` has no random call; milestones are mastery counts and zone completion; the garage is coins only. |
| R10 | Math correct: seeded tests plus an independent Python cross-check per generator | Completed | 13 generators, 13 checkers sharing no code; `run.py --all --n 10000` green (section 5). |
| A1 | A 20-minute session with no adult help | Pending (device step) | First run, placement hand-off and the wind-down are built and tested; the observed session is Charlie's. |
| A2 | Zero crashes across 5 playtest sessions | Pending (device step) | No runtime script errors in any suite or in the headless startup run. |
| A3 | Every generator passes its tests and the cross-check at n = 10,000 | Completed | Section 5. |
| A4 | Progress survives close, posture change, restart, update | Partially Completed | Automated in `test_hardening.gd` (posture change mid-rock, close mid-dig, pause mid-rock, update over the Sprint 3 fixture); a real device restart and airplane mode are device steps. |
| A5 | Dashboard mastered list matches an observer | Pending (device step) | `ProgressReport` and `Adaptive.mastered()` are unit-tested; the comparison is a human step. |
| A6 | Lint, GdUnit4, pytest and CI import green; release AAB on internal testing | Partially Completed | All checks green; the AAB needs the keystore on Spiro's machine. |

### 2.2 Sprint backlog items

| Item | Deliverable | Status | Notes |
|---|---|---|---|
| P1-S01-01/02/03/06 | Accounts, installs, ramp-up, internal testing track | Pending (device step) | Human steps; `.godot-version` pins 4.7.2 and CI downloads exactly that build. |
| P1-S01-04 | Hello rock | Completed | Built, then deleted in Sprint 4 as planned; the stylus diagnostic line moved to `DebugOverlay.describe_event`. |
| P1-S01-05 | Export presets: APK and AAB, arm64-v8a + x86_64, target SDK 36, Gradle, no INTERNET | Completed | `export_presets.cfg` matches; tested by `test_export_presets.py`. |
| P1-S01-07 | Device test findings recorded | Pending (device step) | `InputRouter`'s pen heuristic is explicitly marked unverified in `docs/decisions.md`. |
| P1-S02-01 | GDD | Completed | `docs/gdd.md`; Spiro's review and the math reviewer's sign-off are marked pending in the document. |
| P1-S02-02 | Skill map v1 (Zones 1–3 detailed, 4–12 outlined), vocabulary, BKT defaults | Completed | 45 detailed skills; 175 ids in total; `curriculum_check.py` and `test_skill_graph.gd` enforce the DAG and the names. |
| P1-S02-03 | Python curriculum tests | Completed | `tools/ci/test_curriculum.py`. |
| P1-S02-04 | CC0 art direction and Andika | Partially Completed | Direction chosen and credited sources listed; no pack or font imported (environment could not reach them; approval pending). Placeholder art is drawn in code instead (decision recorded). |
| P1-S02-05 | Paper prototype | Pending (device step) | Protocol and notes template are in the GDD. |
| P1-S03-01 | GdUnit4 in CI, input simulation helpers | Completed | `tests/helpers/` (`InputSim`, `TestWindow`, `PanelDriver`, `FakeClock`); CI runs the suites with `-c`. |
| P1-S03-02 | Shell, title, hub, settings, pause, fade, Escape | Defect Found & Fixed | Built and tested. Fix: the Shell and the pause menu now take the rebuilt theme after a posture change (issue 5). |
| P1-S03-03 | `Text` autoload | Completed | CSV loader, placeholder fill, `missing_line`, BBCode highlight and Word Gem links; `test_text.gd`. |
| P1-S03-04 | `InputRouter` and `UI` autoloads, theme | Completed | Theme is built in code (`ExplorerTheme`) rather than a `.tres`, a recorded decision; WCAG contrast is tested. |
| P1-S03-05 | `NumberPad` with keyboard support | Completed | `test_number_pad.gd`. |
| P1-S03-06 | Save system v1: atomic write, `.bak`, attempt log, schema, fixture | Defect Found & Fixed | Built and tested, including the kill-mid-write cases. Fix: `import_bundle` now honours the newer-build guard (issue 3). |
| P1-S03-07 | Lint rules and pytest in CI | Completed | Rules 1–9 (the plan listed 1–4 for Sprint 3; the rest were added in later sprints). |
| P1-S04-01 | Gray-box mine: wall, rocks, cart, Bolt | Defect Found & Fixed | Built and tested end to end. Fix: a cracked rock is paid when it cracks (issue 2); the answer panel sleeps under the Word Gem card (issue 1). |
| P1-S04-02 | Drag target and drag items through `InputRouter` | Defect Found & Fixed | Identical with finger, pen and mouse (tested). Fix: ignores the pointer while paused or hidden (issue 1). |
| P1-S04-03 | Choice buttons | Completed | Shuffled with the problem's rng; `test_choice_buttons.gd`. |
| P1-S04-04 | Dig sound effects on the SFX bus | Completed | Project-synthesized placeholders, credited; every action has a sound (`test_mine.gd`). |
| P1-S05-01 | `Skill`, `Problem`, `Attempt`, JSON loader | Completed | `JsonUtil.intify` keeps whole numbers as ints. |
| P1-S05-02/03 | Zone 1 generators | Completed | Counting, compare, place value, regroup; seeded tests and 10,000-seed invariants. |
| P1-S05-04 | Cross-checker | Completed | `export_problems.gd`, `run.py`, one checker per generator, in CI on every PR. |
| P1-S05-05 | Zone 1 lines and visual models | Completed | `VisualModel` draws seven model types with tested geometry. |
| P1-S06-01 | BKT | Completed | `test_bkt.gd` against hand-computed values. |
| P1-S06-02 | Scheduler: frontier, interleave, 70/30, spaced intervals | Completed | `test_scheduler.gd` with a fake clock. |
| P1-S06-03 | `Adaptive` autoload wired to the save and the mine | Completed | `test_adaptive.gd`, `test_adaptive_engine.gd`. The mastery rule adds a guessing guard beyond the plan's two conditions (recorded "Needs Spiro"). |
| P1-S06-04 | Hint rungs 1–2 | Completed | `test_mine.gd` rung tests. |
| P1-S06-05 | Placement quest with Charlie's seed set and the parent re-run | Completed | `test_placement.gd`; dashboard button. |
| P1-S06-06 | Simulated learners | Completed | Guesser never masters; fast learner masters Zone 1 by day 2 (budget 190 rocks, not the plan's 150: recorded "Needs Spiro"). |
| P1-S07-01/02 | Zone 2 generators | Completed | Addition, subtraction, fact family, missing part, balance. |
| P1-S07-03 | Word Gems | Defect Found & Fixed | Chips and underlined words open the card (tested). Fix: the panel under the card no longer takes the closing tap (issue 1). |
| P1-S07-04 | Explorer theme, Andika | Partially Completed | Theme and contrast done; Andika pending approval, engine font used meanwhile. |
| P1-S07-05 | All MVP lines | Completed | 313 lines, all referenced ids exist, 0 sentence-length warnings. |
| P1-S07-06 | Dig feel: squash-and-stretch, particles, cart bounce | Completed | `Rock.play_crack`, `Cart._on_gem_arrived`. |
| P1-S08-01 | `Rewards` autoload, streak pause | Completed | `test_rewards.gd`, `test_rewards_rules.gd`. |
| P1-S08-02 | Museum, 10 minerals | Completed | `test_workshop.gd`: every case opens from save data. |
| P1-S08-03 | Garage: 2 pickaxes, 3 headlamps | Completed | Purchases persist; the crack effect reflects the tool. |
| P1-S08-04 | Session timer and wind-down | Completed | Finishes the rock in hand; no countdown; `test_mine.gd`. The "one extra rock" question is left to Spiro (`EXTRA_ROCKS_AFTER_LIMIT = 0`). |
| P1-S08-05 | Hint rungs 3–4 | Completed | Worked example card; easier problem once per rock; flags the skill. |
| P1-S08-06 | Celebrations | Defect Found & Fixed | Mastery, mineral and lantern cards wait for a tap. Fix: the card's coroutine returns if the mine was freed during its one-frame wait (issue 6). |
| P1-S09-01/02 | Zone 3 generators, array model | Completed | Skip count, parity, arrays, multiplication. |
| P1-S09-03 | Parent gate with cooldown | Completed | `test_parent_gate_rules.gd`, `test_parent_area.gd`. |
| P1-S09-04 | Dashboard v1 | Completed | `ProgressReport` over the attempt log; numbers tested against a fixture log. |
| P1-S09-05 | Export and import, newest wins, `.bak` | Defect Found & Fixed | Round trip tested. Fix: issue 3. The native picker on Android is a device step (recorded). |
| P1-S10-01 | Placeholder art pass | Partially Completed | Coherent, drawn in code (backdrops per zone, icons, title art, ten mineral shapes); the CC0 import waits for Spiro's pick. |
| P1-S10-02 | Music and remaining SFX, volumes in settings | Completed | Two synthesized loops; `DeviceSettings` in `user://device_settings.cfg`. |
| P1-S10-03 | First run | Completed | Preset-name picker, no keyboard; hand-off to placement (`test_shell.gd`). |
| P1-S10-04 | Readability audit | Completed | Automated half in `test_readability.gd`; manual half documented in GDD section 12 with its last run. |
| P1-S11-01 | Bug bash on both devices | Pending (device step) | This review is the desk half of it. |
| P1-S11-02 | Posture, save, update and offline tests | Partially Completed | Automated in `test_hardening.gd`; restart and airplane mode on the devices. |
| P1-S11-03 | Perf check: no allocations in `_process`, OGG, size budget | Defect Found & Fixed | `perf_check.py` passes (1.8 MB of content). Fix: the debug overlay no longer formats a string per input event in release builds (issue 4). Profiler captures are a device step. |
| P1-S11-04 | CI debug APK artifact | Completed | `android-debug` job with a throwaway keystore and the `aapt2` permission check. |
| P1-S11-05 | Release AAB on internal testing; Charlie's session | Pending (device step) | Needs the keystore on Spiro's machine. |

### 2.3 Engine idioms and quality checks (what was looked for, and found sound)

| Check | Result |
|---|---|
| Lifecycle: `_ready` for wiring, `_process` unused, tweens for animation | No `_process` or `_physics_process` in game code; every animation is a `Tween` with `speed_scale` for tests; `perf_check.py` guards this. |
| `@onready` references resolve | Every `%UniqueName` used in a script exists in its scene; `test_readability.gd` instantiates every registered screen. |
| Signal decoupling | Screens emit `request_screen`/`pause_requested`; autoloads expose signals; lambdas connected to autoload signals capture `self`, so Godot disconnects them when the node is freed (checked for `Bolt`, `GarageScreen`, `MineScreen`). |
| Typed GDScript | `untyped_declaration=2`; the suites load every script without a warning. |
| Scene files hand-written | `ext_resource` ids are consistent; no `uid://` values invented; every `.gd` has its `.uid` file (143 of 143). |
| Null handling | Guarded accessors (`current_problem()`, `rock(index)`, `_panel != null` before use); the only unguarded post-`await` access was in `Celebration` (fixed). |
| Memory | No leaked nodes from game code: the 4 instances Godot reports at headless exit are the music stream still playing at quit (`AudioStreamOggVorbis` and its playback), which is engine shutdown order, not a script leak. |
| Save atomicity | Write `.tmp`, copy a valid `profile.json` to `.bak`, rename; read order profile → tmp → bak; every crash point is a test (`test_save_store.gd`). |
| Autoload order | `Text, UI, InputRouter, SaveSystem, Adaptive, Rewards` in `project.godot` matches the dependencies (`Adaptive._ready` uses `SaveSystem`; `Rewards._ready` connects to `Adaptive`). |
| Landscape, stretch, renderer | `sensor_landscape`, `canvas_items`/`expand`, GL Compatibility, as the decisions log records. |

---

## 3. Issues identified and remediation

Severity is from the child's point of view: **medium** can change what the child sees or earns in a session; **low** is an edge case, a release-build cost or a documentation error.

### Issue 1 (medium): drag inputs accepted taps that belonged to the pause menu or the Word Gem card

- **Where:** `scenes/input/build_board.gd`, `tile_board.gd`, `array_builder.gd`; `scenes/mine/mine.gd`.
- **What happened:** `InputRouter` turns every touch and mouse event into `pointer_down/move/up` signals from its `_input`, which Godot runs *before* GUI input, and the router runs with `PROCESS_MODE_ALWAYS` so Escape can close the pause menu. A signal is delivered to its listeners whether or not they are paused. So while the pause menu was up, a tap on "Keep digging" that happened to be over the pile of one-gems added a gem to the tray; and the recommended way to close the Word Gem card, tapping outside it, placed a piece or a tile if the tap landed on the board under the dimmer. The child's answer could change without the child seeing it.
- **Root cause:** the drag boards had no notion of "I am covered or paused"; they trusted every router signal. The pause test in `test_shell.gd` only checked the tree's pause flag, and the Word Gem test only checked that the rock's state did not change.
- **Fix:** each board accepts the pointer only while `is_visible_in_tree()` and `can_process()` (the engine's own check that the node is not paused), and drops a half-finished drag on `NOTIFICATION_PAUSED` so nothing is left hanging under the menu. The mine puts the answer panel to sleep (`AnswerPanel.set_enabled(false)`) when a Word Gem card opens and wakes it when the card closes if the rock is still awaiting an answer; `AWAIT_ANSWER` also respects an open card.
- **Why here and not in the router:** the router must keep routing while paused (Escape), and `can_process()` is the idiomatic Godot answer to "should a paused node react". Palm rejection (Phase 2) still has the router as its single home.
- **Tests:** `test_mine.gd` (`test_a_tap_that_closes_the_word_gem_card_never_reaches_the_board`, `test_a_tap_on_the_pause_menu_never_reaches_the_board`), `test_drag_and_build.gd`, `test_tile_board.gd`, `test_array_builder.gd` (one paused-board test each). All five failed before the fix and pass after it.

### Issue 2 (medium): a cracked rock was paid only when its gem landed

- **Where:** `scenes/mine/mine.gd`.
- **What happened:** `Rewards.pay_rock` and the "after every rock" save ran in `_on_gem_landed`, 0.45 s after the crack. Pausing during the flight and choosing "Back to the workshop" freed the mine before the gem landed: the attempt was already logged and the adaptive engine already updated, but the coins, the zone gem and today's lantern were never paid. A right answer that costs the child a reward breaks the spirit of rule 8.
- **Root cause:** payment was tied to the end of an animation rather than to the state machine's `crack_finished` step that already counts the rock.
- **Fix:** payment and the save moved to the `GEM_DROP` transition (`_pay_rock()`), which `DigFlow` reaches exactly once per rock. The cart counter, `flow.gem_dropped()` and the celebrations still wait for the landing, so nothing visible changed.
- **Test:** `test_mine.gd` `test_a_cracked_rock_is_paid_and_saved_before_its_gem_lands` slows the flight, checks the coins, the gem and the file on disk while the gem is in the air, then frees the mine and checks the rock was paid exactly once.

### Issue 3 (low): a progress import could overwrite a save from a newer build

- **Where:** `autoload/save_system.gd`.
- **What happened:** `load_profile()` sets `_read_only` when `profile.json` carries a newer `schema_version`, and `save_now()` honours it. `import_bundle()` wrote through `SaveStore.write_profile` directly, so a parent importing a bundle on a downgraded install replaced the newer save (kept once as `.bak`, then buried by the next save).
- **Root cause:** the guard lived in `save_now()` only.
- **Fix:** `import_bundle()` returns `ERR_UNAVAILABLE` with `last_import_report.error = "newer_version"` while read-only, before reading the bundle or touching the attempt log. The dashboard already shows `parent.dash.import_failed` for any non-OK result.
- **Test:** `test_save_system.gd` `test_importing_over_a_save_from_a_newer_build_is_refused`.

### Issue 4 (low): the debug overlay did per-event work in release builds

- **Where:** `scenes/shell/debug_overlay.gd`.
- **What happened:** `_input` built a description string for every input event, and `refresh()` was wired to `InputRouter.device_kind_changed` and `posture_changed`, in every build. A release build never shows the overlay (`visible = OS.is_debug_build()`), so this was allocation per touch event for nothing, against the "no allocations in hot paths" rule that `perf_check.py` cannot see because it only inspects `_process`.
- **Fix:** `set_process_input` follows `is_visible_in_tree()` (F3 toggles it in a debug build; a release build never turns it on), and the refresh timer and signal hookups are only made in debug builds.
- **Test:** `test_shell.gd` `test_the_debug_overlay_reads_input_only_while_it_is_shown`.

### Issue 5 (low): the theme went stale after a posture change

- **Where:** `scenes/shell/shell.gd`.
- **What happened:** `UI._on_window_size_changed` drops its cached theme and emits `metrics_changed`, but nothing re-read it. The Shell (whose theme reaches every screen through the tree) and the pause menu (in a `CanvasLayer`, styling itself) kept the old `Theme`, so button padding derived from `min_target_px()` stayed at the old size after the 2-in-1 was folded.
- **Fix:** the Shell connects `UI.metrics_changed` and reassigns `theme = UI.theme()` to itself and the pause menu.
- **Test:** `test_shell.gd` `test_a_posture_change_gives_the_shell_and_the_pause_menu_the_rebuilt_theme`.

### Issue 6 (low): `Celebration.celebrate` could run on a freed node

- **Where:** `scenes/mine/celebration.gd`.
- **What happened:** the coroutine awaits one frame (so the card has a size) and then positions the particles. If the mine was freed during that frame (a screen change), the code continued on a freed instance and logged an error.
- **Fix:** return after the `await` when `not is_inside_tree()`.
- **Test:** none practical (a one-frame race); covered by the read-through and the guard's simplicity.

### Issue 7 (doc): `docs/sdk-audit.md` claimed GdUnit4 is excluded from exports

- **What happened:** the audit row said the framework is "excluded from exports by the preset filter"; `export_presets.cfg` excludes `android/*, tools/*, tests/*, docs/*, private/*, *.md` and not `addons/gdUnit4/*`, as the Sprint 11 decision already notes.
- **Fix:** the row now states the real situation and points at the pending decision. The preset itself is unchanged because export settings need Spiro's approval (CLAUDE.md).

### Checked and found correct (no change)

`DigFlow` rejects out-of-order calls and never deducts; `RewardsRules` only subtracts coins on a purchase the child chose; `BKT.update` matches the plan's formulas; the guessing guard is a bounded likelihood ratio as the decision describes; `SkillRecord.is_due` compares ISO dates as strings (safe, same length); `Scheduler` never repeats a skill three rocks in a row while another is open; `Placement` only ever counts first tries; `SaveStore` keeps at least one valid copy through every crash point; `ProgressReport` caps idle gaps at 120 s; `GameClock.day_of` applies the local offset the way `Time.get_time_zone_from_system()` reports it; `Text.get_line_bbcode` escapes `[` before building links and never links inside a `{placeholder}`; `ChoiceButtons` shuffles only with the problem's rng; `GeneratorKit.add_distractor` drops a value equal to the answer, a duplicate, or a negative number; every generator uses only the rng it is given.

---

## 4. Technical debt and architectural notes before Phase 2

Ordered by how much they matter for the next sprints.

1. **Pointer events and overlays: make the contract explicit.** `InputRouter` reports every pointer event to whoever listens, so each consumer must gate itself (now: visible in tree, `can_process()`, and the panel asleep under a modal). The chalk slate (Sprint 14) will be a fourth consumer and will add palm rejection to the router. Write the rule into `input_router.gd`'s header ("listeners must ignore the pointer while paused or covered") and give `ChalkSlate` the same `_accepts_pointer()` guard from day one, or move the guard into one shared base class for the drag inputs.
2. **`export_presets.cfg` still packs `addons/gdUnit4/`** (about 3 MB of test framework with TCP/HTTP editor-integration code that is never run). Adding `addons/gdUnit4/*` to both presets' `exclude_filter` is a one-line change waiting on Spiro (export settings are his call).
3. **Open "Needs Spiro" decisions** in `docs/decisions.md` that Phase 2 builds on: the skill-id renames and the Zone 1–3 skill map (math reviewer), the BKT values and the 8 s fluency threshold, the guessing guard (`SkillRecord.EVIDENCE_TO_MASTER`), the two optional save fields without a schema bump, the fast learner's 190-rock budget, rule 5 for abstract problems, the `eq.inverse.check` sign give-away, the tap/drag mode edit on two skills, and "one extra rock" after the soft limit. Sprint 12's BKT fit and Sprint 13's handwriting assume these are settled.
4. **Assets still placeholder and unapproved:** Andika (SIL OFL) is selected but not imported, so the theme uses the engine font; no CC0 pack is imported; the app icon is a placeholder. All are tracked in `docs/sdk-audit.md`, `assets/CREDITS.md` and the GDD's open questions.
5. **Device findings are not recorded.** The pen heuristic in `InputRouter._looks_like_pen` (pressure strictly between 0 and 1, a tilt, or an inverted end) is a guess until the Sprint 1 device test is written up; the native file picker on Android and ChromeOS is unverified for the parent export. Both are flagged in `docs/decisions.md`.
6. **Scene files have no `uid="uid://..."` in their headers.** Godot 4.7 adds one the first time the editor saves each scene; expect a one-time diff of 24 `.tscn` files and commit it, as `CLAUDE.md` asks for `*.uid` files to be committed.
7. **Latency includes paused time.** `MineScreen` measures an attempt's latency with `Time.get_ticks_msec()` across a pause, so a fact skill's hidden fluency check can see a long "answer" after the child paused. It is never shown to the child and only delays mastery of a fact skill; pausing the latency clock on `NOTIFICATION_PAUSED` would be a small change.
8. **Export in read-only mode exports the in-memory fresh profile**, not the newer save on disk that the build cannot read. It is logged (`save_now` warns) and harmless, but a parent could be puzzled by an empty bundle; refusing the export like the import would be consistent.
9. **`Text._link_words` builds a regex from the term words without escaping them.** Fine for the current vocabulary (letters and spaces only); a term with `+`, `.` or parentheses would need escaping. Add it with the first such term.
10. **`Shell.play_music` starts a new fade tween without killing a running one** when screens change quickly. Both tweens target the same end value, so it is harmless; kill the old one if the fade is ever made longer.
11. **The attempt log is read whole** by `Adaptive.struggling()` and the dashboard (`SaveStore.read_attempts`), and merged whole on import. Linear in the number of answers; fine for the MVP and needed in full for the Phase 2 BKT fit, but a session-count cap or rotation should be designed before Phase 3's profiles multiply it by four.
12. **Scene tests are timing-sensitive by design** (they wait for `DigFlow` states with `animation_speed = 25`). They have been stable across this review's runs; if a device-class CI runner is ever slower, raise `_until`'s frame budget rather than the speed.
13. **The plan's `SessionTimer` node, `ProblemPanel` and `Shell`-hosted `WindDown` became `Adaptive.wind_down_due()`, `AnswerPanel` and a mine-owned `WindDown`.** These are improvements (fewer nodes, pure logic in `scripts/`), each recorded in `docs/decisions.md`; the plan text in `docs/phases/phase-1-ramp-up-to-mvp.md` still shows the original sketch and could be annotated to say the shipped files win.
14. **Phase 2 hand-off is ready as the plan asks:** `Problem.answer_modes` and `AnswerPanel.choose_input` are the slot for a `ChalkSlate` input; `attempts.jsonl` exports for `tools/bkt/fit.py`; schema v1 and its fixture are the migration baseline (`SaveMigrator.default_migrations()` is empty and documented); `flagged_for_review` already feeds the dashboard.

---

## 5. Verification record

All commands were run on the pinned Godot 4.7.2-stable Linux build after a clean `--headless --import`.

| Check | Before the review | After the fixes |
|---|---|---|
| `runtest.sh -c -a res://tests` (GdUnit4) | 675 tests, 58 suites, 0 failures | 684 tests, 58 suites, 0 failures (9 regression tests added) |
| `python -m pytest tools` | 533 passed, 15 skipped (no `GODOT` set) | 548 passed, 0 skipped (with `GODOT` set) |
| `python tools/ci/lint_content.py` | 0 errors, 0 warnings | 0 errors, 0 warnings |
| `python tools/ci/perf_check.py` | 0 problems, 1.8 MB exported content | 0 problems, 1.8 MB |
| `python tools/crosscheck/run.py --all --n 10000` | not run separately (no generator changed) | 45 skills checked, 450,000 problems, all passed |
| `godot --headless --quit-after 5` (main scene) | no script errors | no script errors |

The 15 pytest cases skipped in the baseline are the cross-check runner tests that need the `GODOT` environment variable; they were run with it set afterwards (see below). The cross-check was run once after the fixes (no generator was changed by this review), which is the state the table reports.

Files changed by this review: `autoload/save_system.gd`, `scenes/input/{build_board,tile_board,array_builder}.gd`, `scenes/mine/{mine,celebration}.gd`, `scenes/shell/{shell,debug_overlay}.gd`, the matching suites under `tests/`, `docs/sdk-audit.md`, `docs/decisions.md` and this report. No generator, curriculum file, text line, save schema, export setting or BKT value was changed.
