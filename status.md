# Status: Gem Mines of Number Mountain

**Read this first in every session.** It is the one-page handoff: where the project is, what changed recently, and what to do next. `CLAUDE.md` holds the rules; this file holds the state. Keep it short and keep it current (see "Maintaining this file" at the end).

**Last updated:** 2026-10-18 · **Branch at update:** `main` @ `578d083` (PR #8 merged) · **Phase:** 2 done in code, Phase 3 next

---

## 1. Where we are (one paragraph)

Version 1.0 (private, for Charlie) is **built in code**: Zones 1-5 (72 skills, every generator cross-checked at 10,000 problems), handwriting answers via a GDScript digit network, workshop crafting and builds, cross-device progress by parent export/import, badges and Word Gems, CC0 + code-drawn art, synthesized music, parent dashboard v2. The sprints were built ahead of their calendar dates (plan dates are 2027; code was written Oct 2026). **What remains for 1.0 is human/device work, not code.** Phase 3 (public release readiness) is the next code work, starting with Sprint 22 narration.

## 2. Architecture snapshot

| Layer | Where | Notes |
|---|---|---|
| Engine | Godot 4.7.2 (`.godot-version`), typed GDScript | Android export, landscape, arm64 + x86_64, no `INTERNET` |
| Autoloads | `autoload/` | `Text`, `SaveSystem`, `Adaptive`, `Rewards`, `InputRouter`, `UI`. **Not yet:** `Narration`, `Profiles` (Phase 3) |
| Pure logic | `scripts/` | generators (one per skill family), adaptive (BKT, scheduler, placement, hints), save (schema, migrations), core rules (`DigFlow`, `RewardsRules`, `MotivationRules`, `SaveMerge`, `ProgressReport`), workshop rules |
| Scenes | `scenes/` | shell, mine, input widgets (`NumberPad`, `ChalkSlate`, `BoulderSplit`, `SieveGrid`, `FactorTree`), workshop, zones, parent area |
| Data | `curriculum/`, `text/lines.csv` | Skills, recipes, builds, badges, vocabulary, misconceptions as JSON; ~600 lines of text with stable IDs |
| Save | `scripts/save/` | **Schema v2** (one v1→v2 migration). Phase 3 profiles = **v2→v3** |
| Handwriting | `scripts/input/`, `assets/handwriting/digit_net.json` | No plugin; trained offline in `tools/handwriting/`; confirm below 0.9 confidence |
| Tools | `tools/` | crosscheck, ci (lint, perf, curriculum), bkt, handwriting, music, sfx, qa. `tools/voice/` is **empty** (Sprint 22) |
| CI | `.github/workflows/ci.yml` | import, GdUnit4, pytest, crosscheck, lint, export-preset checks |

Key docs: `docs/development-plan.md` (master plan), `docs/phases/phase-3-public-release-readiness.md` (current phase plan), `docs/decisions.md` (all decisions, newest at bottom), `docs/phases/phase-2-retrospective.md`, `docs/qa/release-1.0.md`.

## 3. Active goals

1. **Ship Version 1.0 (private)** to Google Play internal testing. Blocked on Spiro and the devices (section 5).
2. **Phase 3, Sprints 22-28:** turn 1.0 into a public Google Play release: AI-voice narration (22), up to 4 child profiles and read-aloud (23), Families Policy compliance (24), broad devices incl. mouse-only Chromebooks (25), store listing (26), closed test (26-27), launch (28).

Out of scope until Phase 4: Zones 6-12, Scholar mode, web export, live TTS, any cloud sync.

## 4. Recent changes (newest first)

- **PR #8 (Phase 2, Sprints 16-21):** save schema v2; workshop crafting/builds and balance elevator (opens Zone 4); cross-device `SaveMerge` with backups, checksum and log; Zone 5 (11 skills, sieve, factor tree, rare-gem museum); badges, Word Gems glossary, Deep Dig, Challenge Door, family points; Bolt's six poses, per-zone music cross-fade, aspect-ratio screenshots; dashboard v2; math review packet; release checklist; Phase 3 hand-off docs.
- **PR #7 (Sprints 12-15):** BKT refit, GDScript digit network, `ChalkSlate`, Zone 4 (16 skills, `BoulderSplit`), rare gems from rare numbers, `MathUtil`.
- **Earlier:** Phase 1 MVP (Zones 1-3) and `peer_review_01.md` (7 defects fixed; Spiro resolved all open items).

## 5. Open items (not code; do not try to "finish" these)

Owned by Spiro, the devices or a reviewer. Full steps in `docs/qa/release-1.0.md`.

- Human math review and sign-off on Zones 1-5 (`docs/reviews/2027-04-math-review.md`); AI pre-review is done but is not a substitute.
- Sign-off on Zone 4 and Zone 5 prerequisites, Word Gems and misconception names (`docs/decisions.md`, Sprints 15 and 18).
- Charlie's play logs and the decision gate; his digits against the 97% handwriting bar.
- Device matrices: save migration, postures × input (touch/stylus/mouse), cross-device round trip, airplane mode, frame times on the ARM Chromebook.
- Android version code/name, release-signed AAB, `v1.0.0` tag.
- MNIST licence question (CC BY-SA on training data) before the **public** release.

## 6. Immediate next steps (for the next coding session)

Start of Phase 3, Sprint 22 (`docs/phases/phase-3-public-release-readiness.md`, "Sprint 22"):

1. **Update `CLAUDE.md` "Current phase"** to Phase 3 if Spiro confirms Phase 3 has started.
2. **P3-S22-01** `docs/voice-provider-shortlist`: shortlist 2-3 TTS providers (licence, rights after cancellation, training terms); decision entry in `docs/decisions.md`. Research only, no paid calls.
3. **P3-S22-02** `feat/voice-pipeline`: build `tools/voice/` (segmenter, numbers, postprocess, timing, manifest, `generate.py --dry-run`) with pytest. `--dry-run` must list every Zone 1-5 line and a cost estimate.
4. **P3-S22-04** `feat/narration-manager`: `autoload/narration.gd` against a fixture manifest and silent OGG stubs in `tests/fixtures/narration/`; `speak()` is a no-op when `read_aloud = false`.
5. Add the `text_hash` column to `text/lines.csv` per plan section 3.1.

**Stop and ask Spiro before:** any paid voice API call (P3-S22-03, -06), adding a provider SDK as a dependency, the v2→v3 save migration design (Sprint 23), and any export/permission change.

## 7. Health check (last known)

- All GdUnit4 suites, pytest, the 72-skill crosscheck, `lint_content.py`, `curriculum_check.py` and `perf_check.py` were green at the end of PR #8.
- Not verified in a cloud session: anything needing a device, a renderer or the keystore.
- If a fresh session finds something red, record it here under a "Known issues" heading.

---

## Maintaining this file

- **Update `status.md` in the same commit/PR as any change that alters project state:** a finished backlog item, a new decision, a schema bump, a closed open item, a new blocker.
- Update the header (date, branch, commit), then sections 4-6. Move done items from "Next steps" to "Recent changes"; keep "Recent changes" to about the last 5 entries (older history lives in git and `docs/decisions.md`).
- Keep it under about 150 lines. Link to docs instead of copying them.
- This file records state, not rules. Rules go in `CLAUDE.md`; decisions go in `docs/decisions.md`.
