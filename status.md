# Status: Gem Mines of Number Mountain

**Read this first in every session.** It is the one-page handoff: where the project is, what changed recently, and what to do next. `CLAUDE.md` holds the rules; this file holds the state. Keep it short and keep it current (see "Maintaining this file" at the end).

**Last updated:** 2026-10-20 · **Branch at update:** `claude/charming-davinci-v0hqey` (Phase 5 finished in code: Zone 12, ranks, Scholar part 2, the Web preset and the guides, on top of `main` with Zones 10-11) · **Phase:** 1-5 built in code; human, device and store work next

---

## 1. Where we are (one paragraph)

Phases 3 and 4 are **built in code**, ahead of their 2027 calendar, on top of Version 1.0 (Phase 2). Spiro decided on 2026-10-19: **no narration or AI voice** (Sprint 22 and read-aloud dropped) and **phones are supported**. Phase 3 added up to four child profiles (save schema v3), parent onboarding, grade-seeded placement, a stronger gate, the mouse-only path, phone layouts, the compliance package, the store listing and the release and closed-test docs. Phase 4 added Zones 6-9 (135 skills in all, every generator cross-checked), their mechanics and builds, Scholar mode part 1 and saved Fib poems (save schema v4). **What remains is human, device and store work** (section 5).

On 2026-10-20 Spiro confirmed **Phase 5** and then asked for all of it. It is **built in code**: Zone 10 Clockwork Depths and Zone 11 Cipher Vault (30 skills), Zone 12 The Infinite Core (11 skills: a proof builder with the guided proofs of Euclid's infinitely many primes and the square root of 2, the Mathematician's Journal, the number rings room, the Unsolved Mysteries), the Noether, Ramanujan, Fermat and Euclid's Proof badges, Master Miner ranks (derived, not saved), Scholar mode part 2, the single-threaded Web export preset with its Pages workflow, and the three guides (`docs/build-and-release.md`, `docs/how-to-add-a-zone.md`, `docs/curriculum-data-guide.md`). 176 skills in all. No voice (decided 2026-10-19), code-drawn art, plan deviations in the 2026-10-20 sections of `docs/decisions.md`.

## 2. Architecture snapshot

| Layer | Where | Notes |
|---|---|---|
| Engine | Godot 4.7.2 (`.godot-version`), typed GDScript | Android export, landscape, arm64 + x86_64, every screen size (phones too), no `INTERNET`; target SDK pinned in `.android-target-sdk` |
| Autoloads | `autoload/` | `Text`, `SaveSystem`, `Profiles`, `Adaptive`, `Rewards`, `InputRouter`, `UI`. No `Narration` (dropped) |
| Pure logic | `scripts/` | generators (one per skill family, Zones 1-12), `Proof`/`ProofLoader`/`ProofValidator` (Zone 12), `RankRules`, `NotationRules`, adaptive, save (schema v4, migrations v1→v2→v3→v4, `ProfileIndex`), core (`Rational`, `Notation`, `ModeGate`, `ScholarMode`, `Profile`, ...), zones (`gear_train`, `crystal_shards`, `vault_lock`, `proof_fit`, `fib_poem`, ...), workshop |
| Scenes | `scenes/` | shell (title with profile tiles, onboarding, profiles, how-it-teaches), mine (room levels on phones), inputs (`NumberPad` wide/minus, `ChalkSlate` fraction/decimal, `FractionPad`, `PowerPad`, `KeyboardEntry`), zone mechanics for Zones 5-11 (`scenes/zones/z10_clockwork_depths/`, `z11_cipher_vault/`), the letter pad, `scenes/ui/math/` notation |
| Data | `curriculum/`, `text/lines.csv` | 176 skills in Zones 1-12 (`curriculum/wordlists/cipher_words.json` for Zone 11's ciphers, `curriculum/mini_proofs.json` and `curriculum/proofs/*.json` for Zone 12, `curriculum/ranks.json`); `lines.csv` has a `mode` column for Scholar variants; `placement_priors.json`, `poem_words.json`, `proof_diagrams.json` |
| Save | `scripts/save/` | **Schema v4**. One save document per child in `user://save/profiles/<id>/` |
| Tools | `tools/` | crosscheck (Zones 1-12), web (landing page, privacy-policy page), ci (lint, perf, curriculum, manifest, SDK audit, presets incl. Web, listing), music (`--track`), qa (`math_review_packet -- --zones N`, phone captures), marketing render |

Key docs: `docs/decisions.md` (newest at bottom; the 2026-10-19 and 2026-10-20 sections cover all of this work), `docs/build-and-release.md`, `docs/how-to-add-a-zone.md`, `docs/curriculum-data-guide.md`, `docs/release-checklist.md`, `docs/qa/closed-test-plan.md`, `docs/platform-update.md`, `docs/compliance/`, `docs/privacy-policy.md`, `marketing/listing.md`, `docs/releases/v1.5.md`, `docs/reviews/math-review-packet-z6.md` … `-z9.md`.

## 3. Active goals

1. **Ship Version 1.0 (private)**, then the **public 1.0** on Google Play (Phase 3 store work), then **Version 1.5** (Zones 6-9) as content updates. All blocked on the human and device items below.
2. Phase 5's exit work, which is human: reviewer sign-off on Zones 6-12, a browser check of the web build (`docs/build-and-release.md` smoke checklist), the regression matrix, someone other than the author following the three guides, then Version 2.0 and maintenance.

## 4. Recent changes (newest first)

- **Phase 5, the rest, Oct 20:** Zone 12 The Infinite Core (11 skills, four generators with seeded GdUnit4 suites and independent Python checkers; `statements` and `number_card` pictures; `Proof`, `ProofLoader`, `ProofValidator`; the `ProofBuilder` input and `proof.*` data in `curriculum/proofs/`; the journal, proof page, number rings and mysteries screens, reached from the museum; the Euclid's Proof badge; palette, banner and `mine_z12` loop). Master Miner ranks (`Rewards.rank_for`, hub and dashboard, not saved). Scholar mode part 2 (`notation_level`, formal Word Gem definitions, keyboard on every number skill, set symbols drawn in code, lint rules 13-14). The "Web" export preset (single-threaded), `web-deploy.yml`, the landing page and the three guides.
- **Phase 5, Zones 10 and 11, Oct 20:** 30 skills, eight generators with seeded GdUnit4 suites and independent Python checkers (`modular`, `group`, `divisibility_why`, `cipher`, `modinv`, `euclid`, `diophantine`, `rsa`), six new pictures (`clock_track`, `cayley`, `cipher`, `euclid`, `coins`, the congruence card), five new inputs (`CircularTrack`, `ClockLock`, `MixingTable`, `CipherWheel`, `CoinPuzzle`) plus `LetterPad`, `EuclidMachine`, the secret message and lock door screens (from the museum), the Clockwork Vault and Vault Door builds, the Noether, Ramanujan and Fermat badges, two palettes and two music loops, rule 12 of the content lint. Plan deviations and open questions: `docs/decisions.md` (the two 2026-10-20 sections).
- **Zone 9 waits for Zone 8 (Spiro, Oct 19):** `seq.arith.next_term` needs `exp.square.numbers` and `exp.powers_of_two.list`, so Zone 8's banner and music get their turn (`docs/decisions.md`).
- **Phase 4 (Zones 6-9, Scholar mode part 1), Oct 19:** Gear Works (GCF/LCM, gears, simplest form, Conveyor Sync build opens it), Crystal Shards (fractions, decimals, percents, ratio, negatives; fraction handwriting, `FractionPad`, Alloy Mixer build), Power Tower (exponents, roots, bases, scientific notation; vault lock, tower, lever, Counterweight Elevator build), Pattern Grotto (sequences, figurate numbers, Fibonacci, Gauss, proof without words, Fib poems; save v4; Gauss Staircase badge). Scholar mode: keyboard entry after the first key press, Label-composed notation, explorer/scholar/auto on the dashboard. The fraction preview skills moved into Zone 6; cross-zone prerequisites set (all "Needs reviewer").
- **Phase 3, Oct 19:** profiles (save v3, onboarding, switcher, per-child export/import), generic placement, gate (two three-digit products, doubling lockout, a 1,000-random-tap test), `DeviceCaps` mouse-only path, phone support and the phone layout pass, compliance docs, `check_manifest.py`, `check_sdk_audit.py`, store listing and icons, release checklist, closed-test plan, platform-update procedure, the peer review 02 CI follow-ups.
- **Spiro's decisions, Oct 19:** no narration or AI voice; phones supported; save v3 and v4 approved; plan recommendations accepted (`docs/decisions.md`).
- **Earlier:** peer review 02 (13 Phase 2 defects fixed), Phase 2 (PR #7, #8), Phase 1 MVP and `peer_review_01.md`.

## 5. Open items (not code; do not try to "finish" these)

Owned by Spiro, the devices or a reviewer. Details in the 2026-10-19 and 2026-10-20 sections of `docs/decisions.md`.

- **Math reviewer:** sign-off on Zones 1-5 (`docs/reviews/2027-04-math-review.md`) and Zones 6-12 (`docs/reviews/math-review-packet-z6.md` … `-z12.md`; Zone 12 adds the mini proofs, the Euclid and square-root-of-2 proof wording and order, 27 misconception names and 6 Word Gems; the 90 formal Word Gem definitions; Zones 10 and 11 add their cross-zone prerequisites, 56 misconception names, the Euclid-machine question `euclid.extended.coeffs` and the coin-puzzle uniqueness rule), including the new prerequisites, misconception names and the "equal forms count, except simplest-form skills" rule.
- **Spiro's open decisions (Phase 5):** tap-to-pick stations, marks and proof steps instead of dragging the cart, dial and tiles; the "Core Crystal" gem for a hint-free proof (needs art and a rule, not built); Explorer mode keeps fractions, powers, roots and the congruence sign (the plan said only + − × ÷ =); the **Web export preset** (a changed export setting) and switching Pages to "GitHub Actions"; the secret message's counter and "Cipher Keeper" gem (a save schema v5 change, not built); an affine lock for the Vault Door instead of the cipher wheel; the toy lock's prime limit (11, not 13). **Earlier:** the Conveyor Sync gate; `negative.depth.read` and `exp.repeated_mult.read` extra prerequisites; the grade-based Scholar "auto" rule; the vault lock's running total; a second Gauss badge; the syllable counts in `curriculum/poem_words.json`; placement priors; the gate's strength for ages 9-12; the privacy-policy URL, effective date and contact email; the rung-3 worked-example layout.
- **Devices:** the real dpi and window size of the 2-in-1 and the tablet. At a real 10-inch tablet density some screens overflowed already before this work (pads and slates, factor tree, museum, four-child title, build screens, Challenge Door); a layout pass needs those numbers (the Zone 10-11 loops, dial, table, wheel and coin pad are checked on the 20:9 and small-phone shapes by `tests/scenes/test_phone_layout.gd`, not on a real tablet). Plus the device matrices, the save migration v2→v4 on Charlie's real devices, airplane mode, frame times.
- **Store and release:** Play Console device catalog (no phone exclusion), Families Policy live checks (`docs/compliance/families-self-check.md`), screenshots and trailer, the closed test (12+ testers, 14 days), the Android version code/name, the release-signed AAB, tags.
- Still open from Phase 2: Charlie's logs and the decision gate, his digits against the 97% bar, the MNIST licence before the public release.

## 6. Immediate next steps (for the next coding session)

1. Act on Spiro's answers to section 5, each as its own small branch.
2. Run the web smoke checklist in a real Chrome (`docs/build-and-release.md`), the full regression matrix (`docs/phases/phase-5-deep-mountain.md`, Testing and quality) and have someone follow the three guides; then Version 2.0 and maintenance mode.
3. The tablet-density layout pass once the real device metrics are known (`tests/scenes/test_phone_layout.gd` already takes a dpi; add the real tablet and 2-in-1 sizes); the Zone 12 proof builder and rooms are checked on the phone shapes only.
4. Small follow-ups noted in `docs/decisions.md`: a half-set vault lock, crystal, clock lock, cipher wheel, coin puzzle or proof is not saved mid-rock; Scholar variants of the Zone 10-12 hint lines; cursor feedback on drags and focus neighbours for a full keyboard-only pass.

**Stop and ask Spiro before:** any prerequisite, BKT or save-schema change, any export or permission change, any new dependency.

## 7. Health check (last known)

- 2026-10-20, headless Linux (Godot 4.7.2): cross-check of all 176 skills at 10,000 problems each passed (difficulty 0 only; the eased -1/-2 passes ran in the GdUnit4 suites); GdUnit4 generators, workshop, core, curriculum and Zone 12 panel suites 642 cases green, the other suites (adaptive, autoload, input, rewards, save, scenes, ui, zones, handwriting) 1150 cases with 3 failures fixed afterwards (Zone 12 catalog count, phone layout of the proof builder and number rings) and the phone-layout suite re-run green; the full `res://tests` was not run as one single pass. `pytest tools` 1241 passed, 3 skipped; `lint_content.py`, `curriculum_check.py`, `perf_check.py` (5.0 MB exported) and `check_sdk_audit.py` clean. Web export: a headless `--export-release "Web"` succeeded (about 43 MB).
- Parallel Godot test runs on one machine share `user://`; set `XDG_DATA_HOME` per run to keep them apart.
- Not verified in a cloud session: anything needing a device, a renderer, the Android SDK or the keystore.

---

## Maintaining this file

- **Update `status.md` in the same commit/PR as any change that alters project state:** a finished backlog item, a new decision, a schema bump, a closed open item, a new blocker.
- Update the header (date, branch, commit), then sections 4-6. Move done items from "Next steps" to "Recent changes"; keep "Recent changes" to about the last 5 entries (older history lives in git and `docs/decisions.md`).
- Keep it under about 150 lines. Link to docs instead of copying them.
- This file records state, not rules. Rules go in `CLAUDE.md`; decisions go in `docs/decisions.md`.
