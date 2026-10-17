# Gem Mines of Number Mountain

An educational mining-and-crafting adventure, built in **Godot 4.7 (GDScript)** and shipped as an **Android app** for touchscreen Chromebooks and tablets. Players dig into a mountain where every rock is a number: prime numbers are unbreakable gems, composite boulders break apart when you find their factors, and the gems you collect pay for tools, machines and a museum of real minerals. The math runs from counting and place value (age 6) down to modular arithmetic, ciphers and proof (age 12), paced by an adaptive engine rather than by grade level.

The game was designed for Charlie, a gifted first grader, with a public release for other families planned after the private version.

## Status

**Pre-development.** This repository holds the plan, the conventions and an empty Godot project scaffold. Phase 1 (Sprint 1) starts **November 2, 2026**. No gameplay code exists yet.

| Milestone | Target |
|---|---|
| MVP (Zones 1–3, text-based, adaptive, on both of Charlie's devices) | Jan 29, 2027 |
| Version 1.0 private (Zones 1–5, handwriting, cross-device progress) | Apr 9, 2027 |
| Public launch on Google Play | ~early June 2027 |
| Version 1.5 (Zones 1–9) | Aug 20, 2027 |
| Version 2.0, the full game (all 12 zones, web version) | Nov 12, 2027 |

## Documents

| Document | What it is |
|---|---|
| [`docs/development-plan.md`](docs/development-plan.md) | The master software development plan: game overview, the 12 zones, learning design, tech choices, all 52 sprints, testing, risks, budget. |
| [`docs/phases/phase-1-ramp-up-to-mvp.md`](docs/phases/phase-1-ramp-up-to-mvp.md) | **Phase 1 (Sprints 1–11, committed):** architecture, Zone 1–3 skill map, generators, BKT adaptive engine, save system, rewards v1, parent dashboard v1, MVP acceptance. |
| [`docs/phases/phase-2-version-1-0.md`](docs/phases/phase-2-version-1-0.md) | Phase 2 (Sprints 12–21): handwriting recognition, Zones 4–5, crafting and engineering projects, cross-device progress, badges, art. |
| [`docs/phases/phase-3-public-release-readiness.md`](docs/phases/phase-3-public-release-readiness.md) | Phase 3 (Sprints 22–28): AI-voice narration pipeline, child profiles, Families Policy compliance, broad device support, store listing, closed test, launch. |
| [`docs/phases/phase-4-middle-mountain.md`](docs/phases/phase-4-middle-mountain.md) | Phase 4 (Sprints 29–40): Zones 6–9 as content updates, Scholar mode part 1, the yearly Android platform update. |
| [`docs/phases/phase-5-deep-mountain.md`](docs/phases/phase-5-deep-mountain.md) | Phase 5 (Sprints 41–52): Zones 10–12 (modular arithmetic and groups, ciphers, proof), Scholar mode complete, web version, documentation, maintenance mode. |
| [`CLAUDE.md`](CLAUDE.md) | Conventions for the AI coding assistant and for humans: non-negotiable rules, content rules, tech stack, repository layout, commands, architecture, workflow, current phase. |
| [`docs/decisions.md`](docs/decisions.md) | Architecture decision log (date, decision, why, alternatives). |
| [`docs/sdk-audit.md`](docs/sdk-audit.md) | Every dependency, plugin and SDK, for Google Play's Families Policy review. |
| [`docs/gdd.md`](docs/gdd.md) | Game design document (stub until Sprint 2). |

Each phase document has the same shape: overview and dates, entry criteria, architecture and design (file paths, GDScript signatures, data schemas, scene trees), a sprint-by-sprint backlog with branch names and "done when" criteria, testing, exit criteria, risks, decisions for the product owner, and a hand-off to the next phase. They are written so that an experienced developer working with an AI coding agent can implement each phase.

## Non-negotiables (short version)

The full list is in `CLAUDE.md`. The ones that shape everything:

- **No network access in the shipped game.** No analytics, ads, accounts or live AI. AI is used at build time only.
- **No data leaves the device** unless a parent exports it from the parent-gated area. Handwriting strokes are never stored.
- **Every child-facing string comes from `text/lines.csv`** through the `Text` autoload, so narration can be added later without reworking screens.
- **Wrong answers never cost anything.** No timers, no game-over, no lost gems. Rewards are earned, never random.
- **Math must be correct.** Every problem generator has a seeded automated test and an independent Python cross-check.
- Touch targets are at least 64 dp; no `LineEdit` on child-facing screens; landscape only.

## Getting started

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Godot Engine | **4.7.2-stable**, standard build (not .NET) | Pinned in `.godot-version`. Do not upgrade without asking. |
| Android Studio + SDK | API 36 | Needed from Sprint 1 for Android export, emulators and Logcat. |
| JDK | 17 (Eclipse Temurin) | For the Android Gradle build. |
| Python | 3.12 | Offline tools under `tools/` (cross-checker, lint, voice pipeline, BKT fitting). |
| Git | any recent | The dev machine is Windows; scripts use forward slashes and run in Git Bash. |

### Open the project

1. Clone the repository.
2. Open Godot 4.7.2, choose **Import**, and select `project.godot`.
3. Press **F5** (Run Project). You should see the placeholder title screen. That is the whole game today.

### Headless commands

Set `GODOT` to your Godot 4.7.2 executable (for example `export GODOT="/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"` in Git Bash).

```bash
# Import assets (after a fresh clone or a new asset; required before headless tests)
"$GODOT" --headless --path . --import

# Run the main scene headless for a few frames (what CI does today)
"$GODOT" --headless --path . --quit-after 3
```

Commands that arrive with Phase 1 (GdUnit4 tests, the Python cross-check, the content lint, Android export) are listed in `CLAUDE.md` under **Commands**.

### Continuous integration

`.github/workflows/ci.yml` runs on every push to `main` and every pull request. Today it checks that `.godot-version` matches the CI version, downloads Godot 4.7.2, imports the project headless and runs the main scene for three frames. Phase 1 adds GdUnit4, pytest, the content lint and a debug Android build.

## Repository layout

```
project.godot            Godot project (4.7, GL Compatibility, 1920x1080 landscape, canvas_items stretch)
.godot-version           Pinned engine version (4.7.2-stable)
default_bus_layout.tres  Audio buses: Master, Music, SFX, Voice
icon.svg                 Placeholder app icon
autoload/                Singletons: Text, SaveSystem, Adaptive, Rewards, InputRouter, UI (Phase 1); Narration, Profiles (Phase 3)
scenes/
  shell/                 title, hub, pause, settings, parent_area/      (title.tscn placeholder exists)
  mine/                  rock wall, rock, cart, Bolt
  input/                 NumberPad, ChalkSlate, DragTarget
  workshop/              crafting, museum, builds/
  zones/                 z01_pebble_meadow … z12_infinite_core
scripts/
  generators/            one file per skill family; pure logic, no nodes
  adaptive/              bkt.gd, scheduler.gd, placement.gd, hint_ladder.gd
  save/                  save_system.gd, migrations/
  core/                  Problem, Skill, Attempt resource classes
curriculum/              skill graph JSON (one file per zone), vocabulary.json, bkt_defaults.json
text/lines.csv           every child-facing line: id, text, context, voice_version
narration/audio/         generated narration (Phase 3); never hand-edited
assets/                  art, fonts, sfx, music; every file credited in assets/CREDITS.md
addons/                  GdUnit4 (Sprint 3), digit_ink (Phase 2)
android/plugins/digit_ink/   Kotlin handwriting-recognition plugin (Phase 2)
tests/                   GdUnit4 suites mirroring scripts/ and scenes/
tools/                   Python: crosscheck/, ci/, bkt/, handwriting/, voice/
docs/                    development-plan.md, phases/, decisions.md, sdk-audit.md, gdd.md
private/                 gitignored: exported play logs and handwriting samples; never committed
```

Folders that are empty today hold a `.gitkeep` so the layout from `CLAUDE.md` exists from the first commit.

## How to work on it

- Read `CLAUDE.md` first, then the current phase document and the relevant section of `docs/development-plan.md`.
- One backlog item per branch, named `type/scope-summary` (for example `feat/z1-regrouping-generator`). Commit messages use `type(scope): summary`.
- Generators, the adaptive engine and save migrations are written test-first.
- Before calling a task done: the relevant GdUnit4 suites, the cross-check for any generator touched, and `python tools/ci/lint_content.py` (all arrive in Phase 1).
- Architecture choices go in `docs/decisions.md`. New dependencies, save-schema changes, BKT threshold changes, curriculum prerequisite changes, export or permission changes, paid API calls and Godot upgrades all need the product owner's approval first.

## License

MIT. See [`LICENSE`](LICENSE). Third-party assets are credited in `assets/CREDITS.md` with their own licenses.
