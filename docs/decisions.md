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
