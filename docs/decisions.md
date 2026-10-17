# Architecture decisions

One entry per decision: date, decision, why, alternatives considered. Newest at the bottom. See CLAUDE.md "Record decisions".

## 2026-10-17: Pin Godot 4.7.2-stable, standard (non-.NET) build

- **Decision:** `.godot-version` holds `4.7.2-stable`. CI downloads exactly that build. Upgrades happen on purpose in a dedicated sprint (first scheduled check: Sprint 38), never mid-sprint, and only after asking Spiro.
- **Why:** 4.7.2 is the current stable release at planning time. Pinning keeps the editor, CI and export templates in step. GDScript (not C#) keeps the web export (Sprint 51) open.
- **Alternatives:** tracking latest 4.x (risk of mid-sprint breakage); Godot .NET (closes the web option, heavier).

## 2026-10-17: GL Compatibility renderer

- **Decision:** `rendering_method` and `rendering_method.mobile` are both `gl_compatibility`.
- **Why:** best fit for a 2D game that must hold 60 fps on mid-range ARM Chromebooks, Intel/AMD Chromebooks and older tablets, and it is the renderer the web export uses. ETC2/ASTC VRAM compression is enabled for Android.
- **Alternatives:** Forward+ / Mobile (Vulkan). Unneeded for 2D and narrower device support.

## 2026-10-17: Landscape only, 1920x1080 design resolution, `canvas_items` stretch with `expand` aspect

- **Decision:** design at 1920x1080, stretch mode `canvas_items`, aspect `expand`, handheld orientation `sensor_landscape` (value 4) so the app follows either landscape direction but never portrait.
- **Why:** the plan requires landscape only across 16:9, 16:10, 3:2 and 4:3 screens. `expand` keeps UI scale constant and reveals more canvas on wider or taller screens, so anchors and containers (never absolute positions) do the layout work. `sensor_landscape` handles the 2-in-1 being flipped in tablet posture.
- **Alternatives:** `keep` aspect (letterboxing on 4:3 and 3:2 screens); fixed `landscape` (does not follow a flipped device). Sprint 1's device test may revise this; record the outcome here.

## 2026-10-17: Untyped GDScript declarations are editor errors

- **Decision:** `debug/gdscript/warnings/untyped_declaration=2` in `project.godot`.
- **Why:** CLAUDE.md requires statically typed GDScript. Making the warning an error means the editor and headless runs catch untyped code the AI assistant produces before review does.
- **Alternatives:** warning only (level 1). Relax to 1 if third-party addons (GdUnit4) trip it; addon folders can be excluded with `debug/gdscript/warnings/exclude_addons` (verify in Godot docs).

## 2026-10-17: `text/lines.csv` is kept as a plain file, not imported as a translation

- **Decision:** `text/lines.csv.import` uses `importer="keep"`. The `Text` autoload reads the CSV at runtime with `FileAccess`.
- **Why:** Godot's default CSV importer treats every column after the first as a locale and produces warnings for `text`, `context` and `voice_version`. The text table is game data with stable line IDs, not a localization file.
- **Alternatives:** Godot's translation system (would force a locale-per-column layout and hide `voice_version`); JSON (harder for a non-developer reviewer to edit than a spreadsheet-friendly CSV).

## 2026-10-17: Audio buses Master → Music, SFX, Voice

- **Decision:** `default_bus_layout.tres` defines `Music`, `SFX` and `Voice` sending to `Master`.
- **Why:** the parent settings and the Phase 3 `Narration` autoload need independent volume control. Naming the buses now keeps every `AudioStreamPlayer` pointed at the right bus from the first scene.

## 2026-10-17: GdUnit4 6.2.2 installed as the Godot test framework (approved by Spiro)

- **Decision:** `addons/gdUnit4/` holds GdUnit4 v6.2.2 (MIT), copied from the `v6.2.2` tag with its own self-test folder (`addons/gdUnit4/test/`) removed. The plugin is enabled in `project.godot`. Headless runs need `--headless --ignoreHeadlessMode` (GdUnit4 refuses plain headless mode because `InputEvent`s are not delivered there); the editor and the Windows dev PC run it without those flags.
- **Why:** the plan and CLAUDE.md name GdUnit4. v6.2.x lists Godot 4.5–4.7.1 as supported, and the smoke suite passes on 4.7.2 headless. The self-test folder is 2.4 MB of framework tests that would be imported on every clone for no benefit.
- **Alternatives:** GUT (less active typed-GDScript support); Godot's built-in `--script` runner with hand-rolled assertions (no reports, no scene runner).
- **Consequence:** scene tests that need real input events (drag, tap) must simulate them through `InputRouter` helpers rather than rely on engine-delivered `InputEvent`s in CI.

## 2026-10-17: Android export presets "Android" (APK) and "Android AAB" (approved by Spiro)

- **Decision:** `export_presets.cfg` holds two Android presets with identical settings except the output format: **Android** (`gradle_build/export_format=0`, APK, runnable, for `adb install` and the emulator) and **Android AAB** (`export_format=1`, for Google Play). Both: Gradle build on, target SDK 36, min SDK left at Godot's default, ABIs `arm64-v8a` and `x86_64`, landscape handled by the project setting, immersive mode, `permissions/internet=false`, no custom permissions, `user_data_backup/allow=false`, package id `com.spiroganas.gemmine`, version `0.1.0` code 1. `android/`, `tools/`, `tests/`, `docs/`, `private/` and Markdown files are excluded from the export.
- **Why:** Godot refuses to write an `.aab` from a preset whose format is APK and vice versa, so one preset cannot serve both of CLAUDE.md's export commands. Keeping the two presets identical apart from the format keeps the permission surface (no `INTERNET`) in one reviewable file. Release signing comes from the `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables, so no secrets live in the file.
- **Package id:** `com.spiroganas.gemmine`, set by Spiro on 2026-10-17. It cannot change after the first Play upload. Launcher icons are empty until the icon is drawn (Sprint 10).
- **Verified:** Godot 4.7.2 headless loads both presets and reports only the missing export templates and Android SDK on the CI container, which are installed on the dev PC in Sprint 1.

## 2026-10-17: Development plan lives at `docs/development-plan.md`

- **Decision:** the plan was moved from `project_plan/` to the path CLAUDE.md names. Phase breakdowns live in `docs/phases/`.
- **Why:** CLAUDE.md, the README and the phase documents all link to `docs/development-plan.md`.

## 2026-10-17: `UI` autoload lands in Sprint 1 with only `min_target_px()` and `scale_factor()`

- **Decision:** the hello rock needs a touch-target size, and rule 7 forbids hard-coded pixel sizes, so the `UI` autoload is registered in Sprint 1 with just the sizing functions. The theme and posture handling planned for Sprint 3 are added to the same script later.
- **Why:** 64 dp has to be converted with the screen DPI and divided by the canvas stretch scale to measure correctly on both the 1920x1080 design canvas and the devices; putting that in one place from the first scene avoids a Sprint 3 retrofit. The function never returns less than 64 px so headless and desktop runs stay safe.
- **Alternatives:** a constant on the hello rock script (breaks rule 7 and would be copied).

## 2026-10-17: Hello rock is the main scene until Sprint 3

- **Decision:** `run/main_scene` points at `scenes/mine/hello_rock.tscn` so the Sprint 1 APK opens straight into the device test. Sprint 3's shell replaces it, and Sprint 4 deletes the hello rock scene, script, test and placeholder assets.
- **Why:** the Sprint 1 goal is confirming touch, stylus, trackpad, window and orientation behaviour on the real devices, and the overlay on this scene is where those findings are read. Record them under a new entry here (pen as mouse-with-pressure vs touch, DPI values, orientation codes).

## 2026-10-17: Skill map v1 file format, and two skill IDs renamed to three parts (Sprint 2)

- **Decision:** `curriculum/skills/zNN_<zone>.json` holds `{zone, zone_id, name, status, skills}`. Zones 1-3 are `"status": "detailed"` with full records (`id, name, prereqs, generator, params, representations, answer_modes, terms, bkt_type, is_fact_skill, misconceptions`); Zones 4-12 are `"status": "outline"` with only `id` and `name`, using the IDs from the Phase 2, 4 and 5 plans (175 skills in total). Two IDs that broke the `topic.subtopic.action` rule were renamed: `arr.build` is now `arr.rows_cols.build` (Zone 3) and `div.as_sharing` is now `div.sharing.equal_shares` (Zone 4). The plan documents were updated to match.
- **Why:** the format is what the math reviewer, the Godot `Skill` loader (Sprint 5) and the Python checks all read. The `misconceptions` field lists which named distractors a skill's generator may use, so a typo is caught by `tools/ci/curriculum_check.py` instead of at runtime. The rename is done now because no save file or code refers to either ID yet; skill IDs stored in saves cannot change later.
- **Alternatives:** relax the ID rule to allow two parts (rejected: CLAUDE.md states the three-part format and later tooling splits on it); keep outlines in a separate file (rejected: one file per zone is simpler to review).
- **Needs Spiro:** sign-off on the two renames and on the Zone 1-3 skill map (math reviewer).

## 2026-10-17: Word Gem text lives in `text/lines.csv`; `vocabulary.json` holds only line IDs

- **Decision:** the 21 Zone 1-3 terms each have two lines, `vocab.<term>.term` and `vocab.<term>.definition`, in the text table. `curriculum/vocabulary.json` maps each term id to those line IDs plus the zone that introduces it and a `picture` slot (null until Sprint 7).
- **Why:** rule 4 forbids child-facing text outside the text table, and a Word Gem definition is child-facing. Writing the 42 lines in Sprint 2 lets the math reviewer check the definitions together with the skill map.
- **Alternatives:** definitions inside `vocabulary.json` (breaks rule 4 and would not be narrated in Phase 3).

## 2026-10-17: BKT defaults and the allowed-misconceptions list (Sprint 2)

- **Decision:** `curriculum/bkt_defaults.json` holds literature-typical starting values for four skill types (`default`, `fact`, `procedure`, `concept`), `hint_weight` 0.5 and a fact-skill `fluency_ms` of 8000. `curriculum/misconceptions.json` names the 41 distractor misconceptions the Zone 1-3 skills use, each with a parent-facing description. Two names beyond the plan's table were added for symbol comparison (`thought_equal`, `thought_unequal`) so the "=" button can have honest distractors.
- **Why:** the Sprint 6 engine and Sprint 5 generators need these files to exist; the checks make sure every name used is in the list. Values are starting points to be fitted from Charlie's logs in Phase 2.
- **Needs Spiro:** the BKT values and the 8-second fluency threshold are new numbers; CLAUDE.md says not to change mastery thresholds without asking, so please review them before Sprint 6 consumes them.

## 2026-10-17: Explorer theme is built in code, not a `.tres` (Sprint 3)

- **Decision:** `scripts/ui/explorer_theme.gd` (`ExplorerTheme.build(target_px)`) builds the theme; `UI.theme()` caches it. There is no `assets/themes/explorer.tres`. `scripts/ui/` is a new folder beside `scripts/core/`.
- **Why:** every size and colour then lives in one reviewable file, button padding derives from `UI.min_target_px()`, and a WCAG contrast function is unit-tested against the palette (resting buttons and labels meet AAA, 7:1; pressed and disabled meet AA, 4.5:1). Hand-written `.tres` files are easy to corrupt without the editor, which CLAUDE.md warns about.
- **Alternatives:** a `.tres` generated by a script (a build artifact to keep in sync). Revisit if the artist wants to edit the theme visually (Phase 2).
- **Open:** the Andika font is not imported (awaiting approval, and the proxy blocks Google Fonts), so the theme uses the engine's default font. Setting `default_font` on the theme is a one-line change when it lands.

## 2026-10-17: Save system details that differ from the plan's sketch (Sprint 3)

- **Decision:** (1) `SaveSystem.load()` is named `load_profile()`, because `load` shadows GDScript's global `load()`. (2) `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_WM_CLOSE_REQUEST` are handled inside `SaveSystem`, not in `Shell`, so saving on pause works whatever screen (or none) is showing. `Shell` still saves when leaving a screen and on a posture change. (3) All JSON is read through `JsonUtil`, which turns whole-number floats back into ints. (4) `read_profile()` falls back from `profile.json` to `.tmp` to `.bak`, and a write copies `profile.json` to `.bak` only if it is itself valid. (5) A save from a *newer* schema version is refused and never overwritten. (6) `SaveStore.crash_after` is a test-only seam that stops a write at four points, so the "kill the app mid-write" requirement is an automated test.
- **Why:** (3) Godot's JSON parser returns every number as a float, which would silently turn coins and counts into floats and break typed `int` fields. (4) and (5) keep CLAUDE.md's "never break an existing save" true even when a file is corrupt or the app is downgraded. The mutation check (breaking each guard and watching the tests fail) was done by hand in Sprint 3.
- **No schema change:** schema v1 is exactly the plan's. The nickname defaults to an empty string until first-run (Sprint 10). Export/import bundles (`export_bundle`, `import_bundle`) are Sprint 9.

## 2026-10-17: Pen is treated as touch; the PEN heuristic is unverified (Sprint 3)

- **Decision:** `InputRouter` reports `DeviceKind.PEN` when a drag or motion event has a pressure strictly between 0 and 1, a tilt, or an inverted end, but every consumer treats PEN exactly like TOUCH. Mouse events with `device == InputEvent.DEVICE_ID_EMULATION` (Android's mouse-from-touch) are dropped so a tap is reported once. Only the first finger is honoured.
- **Why:** the Sprint 1 device findings (how a ChromeOS stylus arrives) are not recorded in this log yet. "Pen as touch for the MVP" is the plan's recommendation. Replace the heuristic with the recorded behaviour when the device test results are written up.

## 2026-10-17: GdUnit4 runs with `-c` (continue after failure) (Sprint 3)

- **Decision:** CI and the documented commands pass `-c` to `runtest.sh`.
- **Why:** by default GdUnit4's command line stops a suite at its first failure, so one failing test hides every later failure and the pass counts look smaller than they are. With `-c` the exit code is still 100 when anything fails (checked).

## 2026-10-17: Settings screen holds only the read-aloud switch until Sprint 10 (Sprint 3)

- **Decision:** the Settings screen has the read-aloud toggle (stored in `settings.read_aloud`, no effect until Phase 3) and a Back button. Volume controls arrive in Sprint 10 with the sound pass. The pause menu offers Keep digging, Back to the workshop and Settings; Settings' Back button always returns to the workshop.
- **Why:** schema v1 has no volume fields, and adding them is a save-schema change that needs Spiro's sign-off. The toggle exercises the whole read-modify-save path through the UI.

## 2026-10-17: Dig loop is a pure state machine; the mine scene only presents it (Sprint 4)

- **Decision:** `scripts/core/dig_flow.gd` (`DigFlow`) holds the loop's states (`PICK_ROCK, SHOW_PROBLEM, AWAIT_ANSWER, CRACK, GEM_DROP, WOBBLE, HINT, WALL_CLEAR`), the per-wall coin/gem tally and the hint rung. `scenes/mine/mine.gd` calls it as animations finish and draws what it reports. Out-of-order calls return false and change nothing (a double tap cannot pay twice). The tally follows Rewards v1 (1 coin per rock, 2 on the first try, 1 gem); Sprint 8 moves persistent totals into the `Rewards` autoload.
- **Why:** CLAUDE.md keeps game logic out of scene scripts. As a plain object it is unit-tested, including "wrong answers never cost anything" (twelve misses in a row change no tally and lock nothing) and a hand-run mutation check (deducting a coin on a miss fails two tests).
- **Stand-in:** `scripts/core/gray_box_problem.gd` is the single hard-coded `pv.tens_ones.build` problem. Sprint 5 replaced it with the real `Problem` and registry and deleted the file.

## 2026-10-17: Placeholder art is drawn in code and placeholder sounds are synthesized (Sprint 4)

- **Decision:** rocks, gems, the cart, Bolt and the drag pieces are drawn with `_draw()` (`GemArt` holds the gem shapes: quartz is a crystal point, garnet round, pyrite a cube, amethyst a prism). The nine sound effects come from `tools/sfx/generate_placeholder_sfx.py` (standard library plus `ffmpeg`; deterministic). The Sprint 1 hello-rock scene, its SVGs and its sound are deleted as `decisions.md` planned.
- **Why:** the plan said "licensed pack, credited", but the build environment cannot reach kenney.nl and an unreviewed download would need a credit and a license check per file. Project-made stand-ins keep `assets/CREDITS.md` simple and every action still has a sound. The Sprint 10 art pass swaps both for the CC0 packs.
- **Ported before deleting:** the stylus diagnostic line (event class, pressure, tilt, pen flag, device id) moved from the hello rock into the debug overlay, so the Sprint 1 device test can still be read on a device build.

## 2026-10-17: Drag and drop runs on InputRouter pointer signals; piles also accept a tap (Sprint 4)

- **Decision:** `BuildBoard` listens to `InputRouter.pointer_down/move/up` (the router is injectable for tests), never to Godot's built-in drag and drop. Drag from a pile into the tray to add a piece, drag a piece out and drop it anywhere else to remove it, and tapping a pile adds one piece without dragging. `DragItem` is at least one 64 dp target wide.
- **Why:** finger, stylus and mouse then share one code path, which the tests prove with synthetic events (touch, mouse and pen-with-pressure all give the same result). The tap-to-add shortcut helps small hands and trackpads; dragging remains the main interaction.

## 2026-10-17: The pause button is on screen, and Bolt's feedback never hides the problem (Sprint 4)

- **Decision:** `ShellScreen.pause_requested` lets any screen ask the Shell to pause; the mine has a Pause button (tablet posture has no Escape key). Bolt's bubble has a main line (the problem) and a note under it (feedback: "Not quite. Let's look again.", "That's it! Nice work."). The praise stays up after a rock until the next rock opens.
- **Why:** a first rendering of the screen showed the not-quite line *replacing* the prompt, so the child could no longer see which number to build. Found by rendering screenshots under a virtual display, not by a test; the regression is now a test.

## 2026-10-17: Layout tests run in a 1920x1080 window (Sprint 4)

- **Decision:** `tests/helpers/test_window.gd` (`TestWindow`) sets the root window to the design size for tests that check positions or hit areas, and restores it afterwards.
- **Why:** GdUnit4's headless runner opens a 64x64 window, so `UI.scale_factor()` is about 0.03 and every 64 dp target measures about 1,900 canvas pixels there. Relative checks (`>= UI.min_target_px()`) still pass in that window, but anything geometric is wrong.

## 2026-10-17: Problem generators are static functions found through a compile-checked table (Sprint 5)

- **Decision:** each generator is `static func generate(skill, params, rng) -> Problem` on a `class_name` script in `scripts/generators/` and uses only the `rng` it is given. `GeneratorRegistry.table()` maps the skill's `generator` string (`"CountingGenerator"`) to that function as a `Callable`; adding a zone's generators means one new file and one line in the table. `GeneratorRegistry.make_problem(skill, seed, overrides)` merges the overrides (for example `representation`, `difficulty`) over the skill's params, seeds a fresh `RandomNumberGenerator` and stamps the seed on the problem, so any problem can be rebuilt from `(skill, seed, overrides)`. The `"Class.method"` string form the plan floated is not supported; the four Zone 1 generators each have one entry point.
- **Why:** `CountingGenerator.generate` written without parentheses is a typed reference, so a typo in the table fails when the script loads instead of when a child opens a rock. A test (`tests/curriculum/test_skill_graph.gd`) also fails if any detailed skill names a generator that is neither registered nor listed as not built yet.
- **Alternatives:** `load("res://...").call()` by path (a typo fails mid-game); one big `match` in one file (every later zone edits it).

## 2026-10-17: `Problem.to_json()` is the contract with the Python cross-check (Sprint 5)

- **Decision:** a `Problem` carries `skill_id, seed, representation, prompt_line_id, prompt_params, answer, answer_modes, distractors, visual, hint_steps, params, meta`. `meta` holds facts the checker needs that are neither in the prompt nor the picture (which question was asked, a direction, a place); the child never sees it. `to_json()` is exactly what `tools/crosscheck/export_problems.gd` writes, one JSON line per problem, and what `tools/crosscheck/checkers/*.py` read.
- **Independence:** the checkers import nothing from the GDScript side. They re-derive the answer and every distractor from the exported facts only (digit swaps are done on the digit string, not by arithmetic), then also check the shape rules shared by all skills (no duplicate distractors, none equal to the answer, misconception names from `curriculum/misconceptions.json`, four hint rungs in order). `run.py --all --n 10000` exports 10,000 seeded problems per built generator through a headless Godot (exit code 3 means the project was not imported yet) and reports the first ten failures per skill.
- **Mutation check (done by hand):** deliberately breaking generator rules (a wrong answer, a distractor equal to the answer, a duplicate distractor, a missing hint rung) made the GdUnit4 invariants and the Python checker fail. One mutant turned out to be equivalent on the skill it was tried on and was re-tested on `pv.tens_ones.build`. The checker's own pytest suite (`tools/crosscheck/test_checkers.py`) feeds it good problems and tampered ones.
- **CI:** the cross-check runs in the `godot-import` job after the suites, on every push and pull request (about a minute), rather than nightly, because it is cheap and a nightly job would find a broken generator a day late.

## 2026-10-17: Every problem carries four hint rungs, built by its generator (Sprint 5)

- **Decision:** `hint_steps` always has four entries in the order of `Problem.HINT_KINDS`: `repeat_highlight` (say the prompt again and highlight), `visual_model` (the picture that shows the answer), `worked_example` (a *different* seeded problem of the same skill, shown solved) and `easier_problem` (the same skill one `difficulty` step down, via `GeneratorKit.eased_max`). `GeneratorKit.make_example` makes the worked example differ from the real problem in numbers, and, where only two answers are possible, in the answer.
- **Why:** the hint ladder needs the content before the engine that climbs it exists (Sprints 6 and 8 build the screens), and building the examples inside the generator keeps them correct by the same tests. `DigFlow.hint_rung()` already moves up one rung per miss and costs nothing.
- **Open:** nothing in the mine shows rungs 2 to 4 yet; a not-quite answer still shows only Bolt's "Not quite. Let's look again." and tries again.

## 2026-10-17: Abstract questions have no picture until the hint (Sprint 5)

- **Decision:** a problem whose `representation` is `abstract` (for example "6 tens and 8 ones. What number is that?") draws no picture. The concrete or pictorial version of the same question draws gem piles, a ten frame or a number line. The picture for an abstract question is its `visual_model` hint.
- **Why:** the concrete, then pictorial, then abstract steps are how the plan fades the supports away; an abstract problem with a picture is just the pictorial one. CLAUDE.md rule 5 asks for a picture beside every *instruction*, and each concrete step has one.
- **Needs Spiro:** confirm this reading of rule 5 when the hint screens exist (Sprint 8); the alternative is to always draw a small picture and drop the abstract step.

## 2026-10-17: Number strips and ordering are answered by tapping for now (Sprint 5)

- **Decision:** `count.to_120.fill_strip` and `cmp.to_100.order3` list `["tap", "drag"]` as answer modes (the skill map had `["drag"]`). `AnswerPanel` shows a tap-to-choose list of whole answers (the answer plus named-misconception distractors) when `tap` is listed and the problem has distractors. `BuildBoard` is the only drag input and it handles place-value pieces; a drag-to-fill-the-blanks and a drag-to-order input are not built.
- **Why:** with `["drag"]` alone these two skills had no input at all in Sprint 5, so the Zone 1 playtest could not reach them. `drag` stays in the list so the skill map still says what the plan wants.
- **Needs Spiro:** this edits the skill map after the math reviewer's pass, though not its prerequisites or skill list. Decide in Sprint 7 or 8 whether to build the drag inputs or make `tap` the permanent mode for these two.
- **Resolved (Sprint 7):** the drag tile board is built and listed first (see "Word Gems, the tile board and targeted hints").

## 2026-10-17: The mine reads problems from `ProblemSource` until the Adaptive engine arrives (Sprint 5)

- **Decision:** `scripts/core/problem_source.gd` picks the skills a wall draws from (the `skill_ids` export on `Mine`, default every playable Zone 1 skill) and makes each rock's problem with `GeneratorRegistry.make_problem`. It deliberately has no memory and no mastery; Sprint 6's `Adaptive.next_problem()` replaces it and `ProblemSource` is then deleted.
- **Why:** it lets every Zone 1 problem be seen and played on the real loop in Sprint 5 (the playtest the plan asks for) without building ahead.

## 2026-10-17: Zone 1 visuals are drawn in code (Sprint 5)

- **Decision:** `scenes/mine/visual_model.gd` draws the three visual models (`gem_piles`, `ten_frame`, `number_line`) from a problem's `visual` dictionary, with the layout maths in testable static functions (`pile_layout`, `frame_cells`, `line_x`, `minor_tick_step`, `centering_offset`). In a compare problem the piles are tappable and are the answer buttons. `AnswerPanel` shows the picture above the answer input and chooses `NumberPad`, `ChoiceButtons` (now a wrapping, centered `HFlowContainer`) or `BuildBoard` from the problem.
- **Why:** consistent with the Sprint 4 placeholder art decision, and every dimension can then derive from `UI.min_target_px()`.
- **Found by screenshots, not tests:** stretched gems in flow rows, answer buttons overflowing the panel, pictures floating at the top of the panel and tiny pile pieces. Each is now fixed and has a regression test (`tests/scenes/test_visual_model.gd`, `test_answer_panel.gd`).

## 2026-10-17: Skill files and problems are int-safe (Sprint 5)

- **Decision:** `Skill.from_json` reads every skill file through `JsonUtil.intify`, and `Problem.canonical()` compares `34` and `34.0` as equal.
- **Why:** Godot's JSON parser returns every number as a float; the same fix as the save system keeps `{min: 11, max: 99}` usable as `int` in typed generator code.

## 2026-10-17: Mastery also needs answers that beat guessing (Sprint 6) — Needs Spiro

- **Decision:** a skill is mastered when P(L) ≥ 0.95, it was answered right on 2 different days (both unchanged from the plan), the hidden fluency check passes for fact skills, **and** its first-try answers are at least 2,000 times more likely from a child who knows the skill than from one who is guessing. That last condition is a running log-likelihood ratio, `guess_evidence` in the skill record: each first try adds ln((1 − slip) / chance) when right and ln(slip / (1 − chance)) when wrong, where `chance` is how likely a blind guess was with the input the child actually got (one of two piles: 0.5; one of four buttons: 0.25; the number pad or the build board: 0.05). It never drops below ln(1/100), so early struggles do not hold back a child who has since learned. BKT's guess is also raised to that chance for the update (`BKT.with_chance`). The BKT values in `curriculum/bkt_defaults.json` are unchanged.
- **Why:** the plan's simulated-learner rule "a random guesser never masters anything in 2,000 rocks" fails with the plan's own BKT values. With learn 0.15–0.25, three right answers in a row take P(L) past 0.95 from almost anywhere (0.3 → 0.73 → 0.94 → 0.99), and a guesser on four buttons strings three together every day or two; the second-day rule does not help, because any earlier right answer already counts as a day. A scratch simulation of the plan as written had the guesser master a skill in 200 of 200 runs. With the guard (ln 2000) it mastered nothing in 1,000 runs; in the real engine (`tests/adaptive/test_simulated_learners.gd`) the guesser never leaves the first skill in 2,000 rocks. Because the guard is a likelihood ratio, Ville's inequality bounds a guesser's chance of ever passing it on a skill by 1/2000, however long the child plays.
- **Cost:** tap-only skills need more right answers before mastery: a two-pile skill about 13 first tries, four buttons about 6, typed or built answers 2–3 (the BKT condition usually decides those).
- **Alternatives:** lower the learn rates (changes the plan's BKT values); a "N right in a row" streak (no bound on lucky streaks over thousands of rocks); counting only free-response answers (Zone 1 is mostly tap).
- **Needs Spiro:** approve the guard and its level (ln 2000). It is one constant, `SkillRecord.EVIDENCE_TO_MASTER`.

## 2026-10-17: How the adaptive engine reads answers and opens skills (Sprint 6)

- **One rock, one opportunity.** The first answer on a rock is full evidence (BKT update, guessing evidence, a correct day, the latency for fact skills). A later right answer, after hints, is partial evidence: P(L) moves `hint_weight` (0.5) of the way to the full update. A later wrong answer adds nothing; the first miss already said "not yet". Every answer is still written to `attempts.jsonl` with its `hints_used`.
- **Secure skills open their successors.** The frontier is the plan's (prerequisites mastered or placement-passed) plus prerequisites that are *secure*: P(L) ≥ 0.95 and past the guessing guard, but not yet confirmed on a second day. Without this, mastery's two-day rule would let a child unlock only one layer of the skill graph per day, and the plan's "fast learner masters Zone 1 in 2 days" would take 7. A secure skill **rests** for the rest of the day it was won (more practice that day cannot confirm it) and returns the next day for its confirming answer.
- **Review and lapses.** On mastery the skill's first review is due the next day, then 3, 7, 21 and every 60 days after correct reviews. A missed review (or the fourth hint rung on one rock) sets `flagged_for_review`, clears `correct_days` and puts the skill back in practice, where flagged skills go first. `mastered_at` keeps the first mastery date, so winning a skill back is not a second "first mastery" (Rewards gives the amethyst once).
- **Scheduling.** Up to 3 frontier skills are interleaved, never the same skill three rocks in a row when another is open; reviews take 30% of a session's rocks while any are due, most overdue first. Representations follow P(L): a two-representation skill is concrete below P(L) 0.475 and abstract above; reviews use the most abstract one.
- **Days are the child's local calendar days** (`GameClock`, injectable; tests use `tests/helpers/fake_clock.gd`).

## 2026-10-17: Two optional fields in each saved skill record, no schema version change (Sprint 6) — Needs Spiro

- **Decision:** a skill record may now hold `placement_passed` (bool) and `guess_evidence` (float). Every reader treats a missing field as false / 0.0 (`SkillRecord.ensure`), so every schema v1 save, including `tests/save/fixtures/v1.json`, loads and plays unchanged; an older build ignores the extra keys. `schema_version` stays 1.
- **Why:** the plan's placement quest marks skills "placement_passed", which needs somewhere to live, and the guessing guard above must survive between sessions. Both are additive and optional, the case `SaveSchema.with_defaults` was written for.
- **Needs Spiro:** CLAUDE.md asks before any save-schema change. If you prefer a formal schema v2 with a migration, it is a small change: a `v1_to_v2.gd` that adds the two keys to each record plus a v2 fixture.

## 2026-10-17: The placement quest (Sprint 6)

- **Decision:** `scripts/adaptive/placement.gd` follows the plan (two problems per probed skill; both right passes it and every skill below it at P(L) 0.85, not mastered, and queues its successors; a miss queues its prerequisites; ten minutes at most). Details the plan left open: the seeds are probed first, then the queue in order (breadth first); only first tries count, so retries with hints never fail a probe twice; the quest also stops after 40 problems; placement answers are logged to `attempts.jsonl` but do not change BKT or the guessing evidence (they set P(L) directly). Charlie's seed `star_2026_09` maps to `count.to_120.read`, `pv.tens_ones.build`, `add.to_10.sums`; an unknown seed starts at `count.to_20.objects`.
- **Flow:** a profile whose `placement.done` is false starts the quest on its first Dig; Bolt says so, and says when it is done. A parent re-run (Sprint 9's dashboard) sets `done` back to false. Loading another profile drops an unfinished quest (`SaveSystem.profile_loaded`).

## 2026-10-17: The mine asks Adaptive for each rock's problem when the rock is picked (Sprint 6)

- **Decision:** `ProblemSource` and its test are deleted. A wall is just rocks; each rock's problem comes from `Adaptive.next_problem()` the moment the child taps it, so the choice reflects the answers just given. `MineScreen.skill_ids` still pins the skills for tests.
- **Inputs follow the skill's answer-mode order.** `AnswerPanel.choose_input` now takes the first mode in the skill's `answer_modes` that the problem can be answered with, as GDD section 4 says ("the game picks the first mode the device supports"). Zone 1 is unchanged; Zone 2's sums and differences (listed `number_pad` first) get the number pad, with their named distractors still used for misconception feedback. `AnswerPanel.chance_for` and `answer_mode_for` give the adaptive engine and the attempt log the guessing odds and the mode.

## 2026-10-17: Hint rungs 1 and 2 in the mine (Sprint 6)

- **Decision:** a not-quite answer now shows the rung for the rock's miss count (`HintLadder`). Rung 1: Bolt repeats the problem with its numbers bold in headlamp yellow (Bolt's main line is a `RichTextLabel`; `Text.get_line_bbcode` escapes the text and wraps the values) and adds "Here it is again. Look at these words." under "Not quite. Let's look again." Rung 2: the problem's picture model replaces a look-only picture, or is added (smaller) above tappable piles, the build board or a problem with no picture. Rungs 3 and 4 stay at rung 2 until Sprint 8 builds them.

## 2026-10-17: Simulated learners and the fast learner's rock budget (Sprint 6) — Needs Spiro

- **Decision:** `tests/adaptive/test_simulated_learners.gd` plays the real engine, generators and input odds with a fake clock. Outcomes asserted: the random guesser masters nothing in 2,000 rocks (3 seeds, 40 rocks a day); the fast learner (95%) masters all 17 Zone 1 skills by the end of day 2 and never on day 1 (5 seeds; 140–164 rocks, budget 190); the average learner (70% rising) masters Zone 1 (about 280 rocks over 8 days); the slow learner (50% rising) keeps progressing (all 17 within 40 days in the test seed, asserted at 5 or more); the forgetter's failed review pulls the skill back into practice.
- **Needs Spiro:** the plan said 150 rocks for the fast learner. The median is about 150, but the guessing guard makes tap-heavy skills take a few more answers, so the test allows 190.

## 2026-10-17: Word Gems, the tile board and targeted hints (Sprint 7)

- **Word Gems:** the terms of the problem on screen appear as chips under Bolt's bubble, and the same words in Bolt's line are underlined and tappable (`Text.get_line_bbcode` links whole words only, never inside a `{placeholder}`). Either opens the Word Gem card: the term, a small picture (each entry in `curriculum/vocabulary.json` now names a `visual`, checked by `curriculum_check.py`) and the kid-sized definition. Tapping outside the card closes it; nothing about the rock changes.
- **Tile board:** number strips (`count.to_120.fill_strip`) and ordering (`cmp.to_100.order3`) are now answered by dragging numbered tiles into slots, as the plan intended (Sprint 5 used taps as a stand-in). Their `answer_modes` changed from `["tap", "drag"]` to `["drag", "tap"]`, so the tile board comes first; prerequisites are untouched. The tiles come from `meta.tile_board` (the answer plus every distractor's numbers, scrambled deterministically by `GeneratorKit.tile_pool`), and a tap on a tile puts it in the first empty slot, so mouse and touch work the same.
- **Targeted hints:** every allowed misconception has a Bolt line, `bolt.misconception.<name>` (42 of them, enforced by `curriculum_check.py`). When a not-quite answer equals a named distractor, that line replaces the rung's own line under "Not quite. Let's look again." Bolt shows two note lines at most, so the bubble never pushes the answer off the screen.
- **Andika** is still not imported (waiting on the SIL OFL entry in `docs/sdk-audit.md`); the theme uses the engine font, and swapping is one line in `ExplorerTheme`.

## 2026-10-17: Rewards v1 (Sprint 8)

- **Rules** (`scripts/core/rewards_rules.gd`, pure and tested): a rock pays 2 coins on a first-try answer and 1 after a hint, plus one gem of its zone (quartz, garnet, pyrite). The first mastery of a skill pays an amethyst; winning a skill back after a lapse does not pay again. Museum minerals are milestones, never chance: calcite at 5 skills mastered, topaz at 15, obsidian at 30, and malachite, fluorite and hematite for finishing Zones 1, 2 and 3. Bolt's Garage sells the big pickaxe (50 coins: a bigger crack burst, nothing else) and green and gold headlamps (20 and 40). There is nothing to buy with money and nothing random.
- **Lantern streak:** the first rock of a day lights the lantern; the streak is the number of lit days, so a missed day pauses it and never resets it (CLAUDE.md rule 8).
- **Session limit:** after the parent's soft limit (default 20 minutes) the wind-down appears at the next rock boundary, so the rock in hand is always finished. It shows a recap of counts (rocks, gems, coins, skills practised), never a clock or a countdown.
- **Hint rungs 3 and 4:** rung 3 shows a solved friend of the problem (the generator's worked example) above the answer area; rung 4 swaps in an easier problem of the same skill and flags the skill for the dashboard (not during the placement quest). Celebrations wait for a tap; they never time out.

## 2026-10-17: Parent gate, dashboard and progress export (Sprint 9)

- **Gate:** a two-digit by one-digit multiplication (12–99 × 3–9) typed on the number pad. Three misses start a 30-second cooldown. It is a grown-up check, not security.
- **Time played** is worked out from `attempts.jsonl` (`ProgressReport`), so the save needed no new fields: within a session each answer adds the time since the previous one, capped at 120 seconds so a tablet left on the table is not play. The dashboard shows today and the last 7 days, the last 7 sessions (minutes, rocks, first-try percent), skills mastered and skills that need practice (flagged, or 3 misses in their last 5 first tries).
- **Settings:** session length 5–60 minutes in steps of 5, the nickname (the only `LineEdit` in the game, inside the parent area) and a placement re-run.
- **Export/import:** one JSON bundle (`format: "gem-mines-progress"`) holding the profile and the attempt log, written and read through Godot's `FileDialog` with the native picker. Import keeps whichever profile is newer, merges the two attempt logs without duplicates, and keeps the replaced profile as the `.bak`; a newer game's bundle is refused. **Unverified:** the native picker on Android and ChromeOS needs the device test.

## 2026-10-17: Zone 2 and Zone 3 generator choices (Sprints 7 and 9)

- **Counting by twos** (`skip.by_2.to_40`, concrete) shows the gems in pairs up to the strip's last number; the strip itself travels in `meta.strip` and the tile board draws it around the slots. `groups {n, 2}` was not used because groups stop at 10.
- **`wrong_step`** is read as "counted on by ones from the number before", including the child's own number when two blanks are side by side (10, _, _, 40 → 11, 12).
- **New misconception `parity_swapped`** ("Mixed up even and odd."), listed on both parity skills. On the rule skill the wrong word is named `used_tens_digit` when the tens digit points to it and `parity_swapped` otherwise; numbers are drawn uniformly from 10 to 100 so both happen often. This adds to the allowed list and to two skills' misconception lists; no prerequisite changed.
- **`sub.to_100.no_regroup`** now lists `added_instead` as well: without regrouping, `smaller_from_larger` equals the right answer, and `digit_swap` does not exist for answers such as 4 or 44, so some tap problems would otherwise have had no wrong answer.
- **Make ten** (`add.to_20.sums`) uses 6–9 plus 1–9 with sums 11–18 (single-digit addends cannot reach 19 or 20).
- **Needs Spiro:** in `eq.inverse.check`, an addition's only subtraction button is the right one, so the sign alone gives it away (the subtraction case is half as bad). Offering distractors with the right sign and wrong numbers would fix it; it changes what the skill asks, so it waits for the math reviewer.

## 2026-10-17: First run, placeholder art, music and the readability audit (Sprint 10)

- **First run:** Bolt says hello, the child picks a nickname from preset names (no keyboard; a parent can type one in the grown-up area) and the first Dig starts the placement quest. The title goes there whenever the save has no nickname.
- **Art:** still project-made and drawn in code: a cave backdrop per area (workshop and one tint per MVP zone), icons on the workshop buttons, a title picture and ten minerals that differ by shape as well as color. The Kenney CC0 import waits for Spiro's pick of packs (GDD section 11).
- **Music and volumes:** two calm placeholder loops (workshop and mine) synthesized by `tools/music/generate_placeholder_music.py`, on the `Music` bus. Music and sound volumes (0 for off, then 1 to 5) live in `user://device_settings.cfg`, not in the save: they belong to the device, and a progress export should not carry them.
- **Readability audit:** the checklist is GDD section 12; the automated half is `tests/scenes/test_readability.gd`. The screenshot pass fixed the overlays drawn in a corner, the rung-3 build board running off the screen (Done now sits beside the piles) and Bolt drawn stretched.

## 2026-10-17: MVP hardening, the perf check and the Android CI job (Sprint 11)

- **Automated:** `tests/scenes/test_hardening.gd` covers a posture change mid-rock (the rock and its problem stay, the game saves), the mine at 16:9, 16:10, 3:2 and 4:3, closing mid-dig and starting again from the disk, the app pausing mid-rock, an update over the Sprint 3 save fixture (every screen opens and a rock pays onto the old totals), and a long dig of 8 walls across all 45 skills that climbs every hint rung with no missing line. Lint rule 9 fails on any network class, `OS.shell_open` or web address in game code. `tools/ci/perf_check.py` fails on allocations in `_process`/`_physics_process` (the game has none: everything animates with tweens), non-OGG audio, or exported files over 60 MB (they are 1.8 MB now; the engine for two ABIs adds about 70 MB, well under the 150 MB limit). The debug overlay's refresh timer is off in release builds.
- **CI:** a new `android-debug` job builds the debug APK on every merge to `main` (and on demand), with a throwaway debug keystore made in the job, checks with `aapt2` that the APK asks for no `INTERNET` permission, and uploads it as an artifact. Verified with a manual run on the PR branch: the APK is about 60 MB for both ABIs and `aapt2` lists no permissions at all. Two quirks it works around: `--install-android-build-template` only works on the export command itself, and Godot 4.7.2 aborts while shutting down after that export (exit 134, its file-system scan of the new template cut short) when the APK is already written, so the job checks the APK (present, holds `classes.dex`, readable by `aapt2`) instead of trusting the exit code.
- **Still for the devices (P1-S11-01 to -05):** the two-day bug bash with touch, stylus and mouse; a real device restart and an airplane-mode session; 60 fps profiler captures on both devices; the release-signed AAB to internal testing (the keystore stays on Spiro's machine); Charlie's first full session alone.
- **Needs Spiro:** the export presets' `exclude_filter` does not exclude `addons/gdUnit4/`, so the test framework (which contains TCP and HTTP client code for its editor integration) is packed into the APK. It is never run and the app has no `INTERNET` permission, but adding `addons/gdUnit4/*` to both presets' `exclude_filter` keeps it out of the store build. Export settings are Spiro's call (CLAUDE.md), so the preset is unchanged.

## 2026-10-17: Peer review 01 of the Phase 1 code (findings and fixes)

- **Scope:** a full read of every autoload, script, scene and test against `docs/development-plan.md`, `docs/phases/phase-1-ramp-up-to-mvp.md` and CLAUDE.md, with the headless import, the GdUnit4 suites, pytest, the lint, the perf check and the 10,000-problem cross-check run as the baseline (all green before the review). The report is `peer_review_01.md` at the repository root.
- **Drag inputs now ignore the pointer while paused or covered.** `InputRouter` translates every event before the GUI sees it, and a signal still reaches a paused node, so a tap on the pause menu or on the Word Gem card's dimmer also reached the `BuildBoard`, `TileBoard` or `ArrayBuilder` underneath (a tap on "Keep digging" over the pile of one-gems added a gem to the tray). Each board now accepts the pointer only while `is_visible_in_tree()` and `can_process()`, drops a half-finished drag on `NOTIFICATION_PAUSED`, and the mine puts the answer panel to sleep while the Word Gem card is open (`AnswerPanel.set_enabled(false)`, back on when the card closes if the rock is still awaiting an answer). Chosen over gating inside `InputRouter` because the router must keep routing Escape while paused, and the boards are the only pointer consumers; `can_process()` is the engine's own "am I paused" check.
- **A cracked rock pays when it cracks, not when its gem lands.** `Rewards.pay_rock` and the after-rock save ran in `_on_gem_landed`, so pausing and leaving for the workshop during the 0.45 s flight lost coins and a gem the child had earned (the attempt was already logged and the engine already updated). The payment and the save now happen on the `GEM_DROP` transition; the cart counter and the celebrations still wait for the landing.
- **An import is refused while the save on disk is from a newer build.** `SaveSystem.import_bundle` wrote through `SaveStore` directly and so bypassed the `_read_only` guard that `save_now()` honours; a parent importing a bundle on a downgraded install would have replaced the newer save (kept once as `.bak`, then buried by the next write). It now returns `ERR_UNAVAILABLE` with `last_import_report.error = "newer_version"`.
- **Smaller fixes:** the debug overlay only reads input while it is visible (`set_process_input` follows `visible`) and wires its refresh only in debug builds, so a release build no longer formats a string per input event; the Shell and the pause menu take the rebuilt theme on `UI.metrics_changed` (before, a posture change rebuilt the theme but every screen kept the stale one); `Celebration.celebrate` returns after its one-frame wait if the mine was freed meanwhile; `docs/sdk-audit.md` no longer claims the export excludes `addons/gdUnit4/` (it does not, see the Sprint 11 entry above).
- **Not changed (needs Spiro or a later sprint):** the open "Needs Spiro" items above; the `export_presets.cfg` exclusion of `addons/gdUnit4/*`; Andika and the CC0 art; the device-only hardening steps. The technical-debt list in `peer_review_01.md` has the rest.

## 2026-10-17: Spiro's decisions on the open items from peer review 01

Spiro resolved every "Needs Spiro" item above and the review's open settings in one pass. Each earlier entry stands as written; this entry records the outcome.

- **Export presets exclude the test framework.** `addons/gdUnit4/*` is now in both presets' `exclude_filter`, and `tools/ci/test_export_presets.py` fails if it is ever dropped. Nothing in the game references the addon; the editor-plugin entry in `project.godot` applies only inside the editor. Reason: the framework's TCP/HTTP editor-integration code has no business in a children's app, even unused.
- **Andika is the game's font.** Andika 6.200 Regular and Bold (SIL International, SIL Open Font License 1.1) live in `assets/fonts/andika/` with `OFL.txt`; `ExplorerTheme.build` sets the theme's `default_font` and the `RichTextLabel` fonts (Bold for the highlighted numbers in Bolt's bubble). The SDK audit row is approved and the credits carry the three files. The font came from the project's GitHub release because software.sil.org is not reachable from the build environment.
- **The Kenney CC0 art pass is approved and waits on a download.** The build environment's network policy denies kenney.nl, itch.io and opengameart.org, so no pack could be fetched. The pass runs as soon as the zips are on the dev PC (or the host is allowed): UI pack for buttons and panels, interface/impact audio for the twelve sound effects, and rock or gem sprites only where they keep the rule that gems differ by shape as well as color (most Kenney gem sprites share one shape, so the code-drawn gem shapes may stay).
- **Approved as recommended:** the BKT starting values and the 8-second fluency threshold (to be refitted from Charlie's logs in Sprint 12); the guessing guard at ln 2000 (`SkillRecord.EVIDENCE_TO_MASTER`); the fast learner's 190-rock budget; the two optional skill-record fields without a schema bump (a formal v2 comes with the first non-optional field in Phase 2); the rule 5 reading that an abstract problem has no picture until hint rung 2; the two skill-id renames and the tap fallback on the two tile skills; `EXTRA_ROCKS_AFTER_LIMIT` stays 0 for Charlie's first weeks.
- **`eq.inverse.check` distractors** (right operation, wrong numbers, so the sign no longer gives the answer away) are approved as a Sprint 12 item for the math reviewer, not built now.
- **Device-only steps** (stylus findings, the native file picker on Android and ChromeOS, a real restart, an airplane-mode session, profiler captures, the release AAB, Charlie's first session) stay on Spiro's device checklist; nothing to approve.
