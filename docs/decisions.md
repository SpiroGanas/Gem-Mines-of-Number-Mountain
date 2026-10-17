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
