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
