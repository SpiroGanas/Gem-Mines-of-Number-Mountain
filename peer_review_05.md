# Peer review 05: Phase 5 (Sprints 41–52) code audit

**Date:** 2026-10-21
**Scope:** everything built for Phase 5 of `docs/development-plan.md` (section 8.6) and `docs/phases/phase-5-deep-mountain.md`, on top of the Phase 1–4 code that `peer_review_01.md` and `peer_review_02.md` audited and the Phase 3–4 work merged since: Zone 10 Clockwork Depths (three generators, the circular track, the clock lock, the mixing table, the Clockwork Vault build), Zone 11 Cipher Vault (five generators, the cipher wheel, the coin puzzle, the Euclid machine, the toy lock door, the secret message and the letter pad, the Vault Door build), Zone 12 The Infinite Core (four generators, `Proof`, `ProofLoader`, `ProofValidator`, the proof builder, the journal, the proof pages, the number rings and the Unsolved Mysteries rooms), the Master Miner ranks, Scholar mode part 2 (notation levels, the set symbols, the formal Word Gem definitions, keyboard entry everywhere), the four new badges, the Web export preset and its workflow, the three guides, the Python checkers and every test suite. Phase 5's human, device and store rows (`status.md` section 5) were not built and are marked pending, not audited.
**Method:** `status.md` first, then the Phase 5 plan, the 2026-10-19 and 2026-10-20 sections of `docs/decisions.md` and the two earlier reviews. A clean headless import, then the whole verification set run **before any change** as the baseline: the full GdUnit4 tree, pytest, the content lint, the static perf check, the curriculum check, the SDK audit check, the 10,000-problem Python cross-check of all 176 skills at difficulty 0 and 2,000 at −1 and −2, and the main scene run headless for three frames. Then a full read of the Phase 5 code in four parallel passes (Zone 10; Zone 11; Zone 12; ranks, Scholar part 2, export, CI, docs and the shared-scene diffs), each claim traced end to end before it was counted, with headless probes and Python brute force where a claim was about every reachable parameter. Fixes were made test-first: each defect got a regression test, the test was shown to fail against the unfixed source and pass with the fix, and the whole set was re-run at the end.

---

## 1. Executive summary

**The Phase 5 codebase is in good shape and, after this review, stable: it does what `status.md` and the Phase 5 plan say it does, in the shape the plan describes, and the architecture rules of `CLAUDE.md` hold throughout.** The baseline was green before the review: **1572 GdUnit4 tests in 160 suites, 1241 pytest tests (3 skipped by design), lint 0/0, perf 0, curriculum 0, SDK audit complete, cross-check 176/176 at all three difficulties, headless startup clean** (the same benign exit-time audio report as note A of peer review 02). The Phase 5 generators are pure and seeded, the checkers share no code with them, every child-facing word comes from the text table, every interactive control is a registered touch target, no scene reaches into another, nothing is saved by the new rooms, the secret message keeps nothing, no preset asks for the network, and no dependency was added.

**Twenty-one issues were found and fixed** (section 3), with a regression test for each code change. Four matter for a child's session:

1. **The proof builder's "Why?" button took the step back.** It was wired like a second tap on the slot, so a child who followed the builder's own How line ("Tap a step to place it. Then tap Why and pick a reason.") watched the step they had just placed slide back to the tray. Every proof in Zone 12 goes through this button.
2. **The proof builder's Hint could loop forever while counting hints.** The hint ladder read only the slots up to the first empty one, so a step sitting past a gap (which a hint itself could create by taking a wrong step back) was offered as "the next step", refused by `place()` because it was already on the board, and offered again on every press, each press adding to the hint count that reaches the adaptive engine.
3. **The toy RSA lock was degenerate.** With primes 3, 5 and 7 every public key is its own private key (on the loops of 8, 12 and 24 every unit squares to 1), so in every `rsa.toy.decrypt` problem d equalled e, the "used the public key" wrong answer was never shown, and two of the three locks changed nothing at all (5 on the loop of 15 and 7 on the loop of 21 leave every number where it was, so "Raise 11 to the power 5 and wrap on a loop of 15" had the answer 11). The idea the zone exists to teach, that a different key unlocks, was never shown. The lock door offered the same keys.
4. **Two Unsolved Mysteries cases could not be solved.** 4 and 6 are only 2 + 2 and 3 + 3, and a second tap on a picked prime let it go instead of picking it twice.

The rest: the larger twin prime got the wrong Bolt hint for 35 of 189 start values (it was dropped behind the cousin prime that equals it); the code-cracking and affine generators ignored the difficulty, so hint rung 4 and the Vault Door's "easier first code" were no easier; the clock lock's Set handed in the untouched 0; the group checker never recomputed a worked example's answer; `Skill.notation_level` contradicted `NotationRules` and the Scholar-only set symbols ℤ ℚ ℝ had no producer in the game; the web deploy would have published the privacy policy's draft header and fill-ins on the first release tag, and the policy claimed a browser download that no code makes; a Word Gem with a missing formal line would show "[its.id]"; the circular track rebuilt its picture dictionary on every frame of a ride; the decisions log described a circular-track layout that never shipped and left Zone 10 and 11 deviations unlisted; the narration folder, the README, the SDK audit and the three guides had stale sentences. All fixed; the suite is green again (section 5).

**Not verifiable here** and still pending, as `status.md` section 5 lists: the math reviewer's sign-off on Zones 6–12 (now including the changed lock parameters and the twin-prime wrong answers), the web build in a real browser, the device matrices and the tablet-density layout pass, the closed test and the Play submission, and Spiro's open decisions. They are marked pending in the matrix, not as defects. Two design gaps are recorded for Spiro and the reviewer rather than built (section 4): the plan's back-substitution ladder for the extended Euclid machine, and a browser download for the web version's progress file.

---

## 2. Phase 5 compliance matrix

Status values: **Completed** (built and verified by tests or by this read), **Partially Completed** (built, with a documented gap or a pending decision), **Defect Found & Fixed** (built, a defect was found by this review and fixed), **Pending (device/human step)** (a step the plan schedules that cannot be run in this environment), **Dropped (decision)** (removed from scope by a recorded decision).

### 2.1 Non-negotiable rules (CLAUDE.md) and the Phase 5 exit criteria

| # | Requirement | Status | Evidence |
|---|---|---|---|
| R1 | No network access in the shipped game | Completed | `permissions/internet=false` in both Android presets, no permission key in the Web preset and nothing in it may add one (`test_export_presets.py`, 4 Web tests); lint rule 9; the CI APK job checks the built manifest; the web landing page carries no script and no external request; the game makes no request after the page loads. |
| R2 | No data leaves the device except a parent-gated export; no handwriting images | Completed | The secret message keeps its note only in Label text while the screen is open (lint rule 12 bans `LineEdit`, clipboard, `shell_open`, `FileAccess`, `JavaScriptBridge` and screenshots in it; a test asserts the save is unchanged). The journal and rooms save nothing. On the web the dashboard offers no progress file at all (issue 14). |
| R3 | No new dependency without approval; `docs/sdk-audit.md` complete | Completed | `addons/` holds GdUnit4 only; the Web preset uses Godot's own single-threaded template with no service worker; the set symbols and the ≡ sign are drawn in code, so no fallback font; the music loops are synthesized by the project's own script. The audit now carries the dated Phase 5 reconfirmation the plan asked for (P5-S52-07). |
| R4 | Every child-facing string from `text/lines.csv` via `Text` | Defect Found & Fixed | Lint rules 1 and 8 pass; every `z10.`, `z11.`, `z12.`, `rank.`, `badge.` and `notation.` id the scenes use resolves. Fixed: a Word Gem whose formal line is missing no longer shows "[its.id]" in Scholar mode (issue 17). |
| R5 | First-grade reading level; a picture alongside every instruction; tappable terms | Defect Found & Fixed | Sentence-length and term lints pass; Zone 12 lines are written at the Scholar level the plan sets for ages 11+. Fixed: the two `mystery.*` skills were labelled pictorial but carried no picture (issue 10). |
| R6 | No `LineEdit`/`TextEdit` in child-facing scenes | Completed | Lint rules 2 and 12; `LetterPad` is A–Z, Space, Delete and Clear buttons; the only `LineEdit`s are the parent area's. |
| R7 | Touch targets at least 64 dp via `UI.min_target_px()` | Completed | Every station, mark, cell, chip, tile, key and button in the new inputs goes through `UI.make_touch_target` (checked by the Zone 10–12 panel suites, the phone-layout suite and this read). The Zone 10 station test now asserts a full touch target instead of the 28 dp of a layout that never shipped (issue 19). |
| R8 | Wrong answers never cost anything; no timers | Defect Found & Fixed | A decoy slides back, an out-of-order step is marked and left, a wrong dial, wheel, coin count or ring costs nothing (tests). Fixed: the Hint ladder's loop inflated `hints_used`, which lowers the evidence a correct proof gives (issue 2). |
| R9 | Rewards earned, deterministic; no purchases | Completed | Four new badges from mastery only (`Rewards.earn_badges` on every mastery); ranks are derived from mastered skills and finished zones and never saved; no new gem; nothing random for value. |
| R10 | Math correct: seeded tests plus an independent cross-check per generator | Defect Found & Fixed | 12 Phase 5 generators, 12 checkers, 41 skills, 10,000 problems each at difficulty 0 and 2,000 at −1 and −2, green before and after. No wrong answer was found; the defects were a degenerate lock (issue 3), a wrong-answer order (issue 5), ignored difficulty (issue 6) and a checker that did not recompute examples (issue 8). |
| E1 | Zones 10, 11 and 12 live on Google Play | Pending (device/human step) | Built in code; the store work is `status.md` section 5. |
| E2 | Web build published on Pages, loads on a school Chromebook, keeps progress, no network after load | Partially Completed | The preset, the workflow (export on `main`, deploy on a `v*` tag, size budget) and the landing page exist and a headless export succeeded; the browser smoke checklist is manual and pending. Fixed: the deploy would have published a draft policy (issue 13) and the policy claimed a web export that does not exist (issue 14). |
| E3 | Every Zone 10–12 generator passes its suite and cross-check at 10,000; every proof fixture test passes | Completed | Section 5; `test_proof_validator.gd` walks every topological order of the partial proof and every decoy. |
| E4 | Scholar mode meets every row of its table; Explorer shows no notation beyond + − × ÷ = | Partially Completed | Keyboard entry on every number skill, formal definitions, the notation levels and the set symbols are built and tested. The recorded deviation stands (fractions, powers, roots and the congruence sign stay in Explorer with words; **Needs Spiro**). Fixed: the levels in the data contradicted the rules and the set symbols were unreachable (issues 11 and 12). The narration row is dropped (decision 2026-10-19). |
| E5 | All mathematician badges and Master Miner ranks exist and unlock deterministically | Completed | Noether, Ramanujan, Fermat and Euclid's Proof in `badges.json` with the plan's unlock skills; `RankRules` picks the highest rank whose conditions hold (boundaries, Master Miner's Zone 10 condition and Core Keeper's every-zone condition are tested); the hub and the dashboard show it. |
| E6 | Narration 100% | Dropped (decision) | No narration or AI voice (Spiro, 2026-10-19). |
| E7 | Math reviewer sign-off on Zones 10–12 and the proof wording | Pending (device/human step) | Packets `docs/reviews/math-review-packet-z10.md` … `-z12.md`; z11 and z12 were regenerated after this review's generator changes. |
| E8 | Full regression matrix executed and recorded | Pending (device/human step) | `docs/releases/v2.0-regression.md` does not exist yet; the automated half is section 5. |
| E9 | Saves from every prior version migrate | Completed (unchanged) | Phase 5 made no schema change (v4 stands; the secret-message counter and the Cipher Keeper gem that would need v5 were not built, **Open (Spiro)**); the v1–v4 fixtures still load through the whole system. |
| E10 | The three guides exist and were exercised by someone else | Partially Completed | They exist and every command and path they name now matches the repository (issue 20). Nobody but the author has followed them. |
| E11 | No new SDK, plugin or permission since Phase 3; no `INTERNET` | Completed | As R1 and R3; the reconfirmation entry is dated 2026-10-21. |
| E12 | `CLAUDE.md` "Current phase" reads Maintenance | Partially Completed (by design) | It names the human, device and store work as next and maintenance after that, which is the true state. |

### 2.2 Sprint backlog items

| Item | Deliverable | Status | Notes |
|---|---|---|---|
| P5-S41-01 … -07 | Zone 10 skill graph, `ModularGenerator`, `GroupGenerator`, `DivisibilityWhyGenerator`, checkers, lines and Word Gems, the `posmod` decision | Defect Found & Fixed | 15 skills, three generators, three checkers, 10,000 problems each; `posmod` everywhere a value can be negative; every rejection loop bounded with a valid fallback; the distractor rules hold for every reachable parameter (brute force). Fixed: the group checker's worked-example checks did not recompute (issue 8); the unlisted parameter deviations are now in the decisions log (issue 18). |
| P5-S42-01, -02, -03 | Circular track, clock lock, mixing table | Defect Found & Fixed | Tap-to-pick inputs (a recorded deviation from the plan's drag), one touch target per station, mark or cell, keyboard digits and Enter. Fixed: Set handed in the untouched 0 (issue 7); the ride rebuilt its picture every frame (issue 16); the decisions log described a chord-shrunk circle of buttons that never shipped (issue 19). |
| P5-S42-04 | Divisibility lens | Completed (recorded deviation) | The existing `digits` picture with the `last_three` focus; no separate scene. |
| P5-S42-05, -06, -07 | Zone integration, the Clockwork Vault, rewards | Completed | Music, palette and banner for Zone 10; the vault is three `mod.add.wrap` dials that open the Zone 11 door; no gear gems (gems come from the rock's number, a recorded choice). |
| P5-S43-01 … -04 | Zone 10 art, voice, polish, release | Partially Completed | Code-drawn art and a synthesized loop are in and credited; voice is dropped; the release is a store step. |
| P5-S44-01 … -07 | Zone 11 skill graph, `CipherGenerator`, `ModInverseGenerator`, `EuclidGenerator`, checkers, the word list, lines and Word Gems | Defect Found & Fixed | 15 skills; the word list has no Caesar-shift partners, so `caesar_crack` is always unique; `extended_gcd` and the x answer are well-defined; the checkers use `%`, `pow(a, -1, n)`, `divmod`, `math.gcd` and brute force. Fixed: crack and affine ignored the difficulty (issue 6). |
| P5-S45-01, -02, -04 | Cipher wheel, Euclid machine, coin puzzle | Partially Completed | Built with buttons (Back/Forward, More/Less), one touch target each, tested with the panel driver. The Euclid machine's back-substitution ladder for the extended algorithm is **not built** and is now recorded as such (section 4, item 1). |
| P5-S45-03 | `DiophantineGenerator` and its checker | Completed | The answer is unique (the total is below the least common multiple and the coins are never multiples; proved and brute-forced over every pair the generator can pick); the "decide" bound agrees with brute force over the whole domain. |
| P5-S45-05, -06 | `RsaGenerator` with `pow_mod`, its checker, the toy lock door | Defect Found & Fixed | Issue 3: every lock whose keys are in play is now a real lock, the locked number is one the lock changes, the decrypt key is capped at 23 so the power can be done by hand, and the door offers only real locks (primes up to 13). |
| P5-S45-07, -08 | `LetterPad`, the secret message | Completed (recorded deviation) | No `LineEdit`, 64 dp keys, A–Z and space, nothing persisted, copied, shared or exported; the plan's counter and Cipher Keeper gem are not built (a schema change, **Open (Spiro)**). |
| P5-S45-09 | Zone 11 integration, the Vault Door | Completed | Three cracked codes on the wheel open the Zone 12 door; the affine lock the plan named is **Open (Spiro)**. |
| P5-S46-01 … -04 | Zone 11 art, voice, polish, release | Partially Completed | As Sprint 43. |
| P5-S47-01, -02, -03 | Zone 12 skill graph, `Proof`/`ProofLoader`/`ProofResult`, `ProofValidator` | Defect Found & Fixed | The validator matches the plan's rules exactly (complete, partial against strict order, every error kind, decoys, duplicates, `next_valid_tiles`); the loader rejects every malformed file the plan lists. Fixed: `next_valid_tiles` could offer a tile already sitting past a gap (issue 2). |
| P5-S47-04 | `ProofStepsGenerator` (the plan's `ProofGenerator`) and its checker | Completed | Mini proofs from `curriculum/mini_proofs.json`; the checker walks every topological order with its own `itertools`. |
| P5-S47-05 | The proof builder scene | Defect Found & Fixed | Issues 1 and 2, with a new Bolt line for a hint that takes a step back (issue 4). |
| P5-S47-06, -07 | Journal, practice proof | Completed | The journal links to every page and room; "Even plus even" completes end to end. Fixed: the proof page no longer dereferences a null proof for an unknown id (issue 21). |
| P5-S48-01, -02 | Euclid's and the square-root-of-2 proofs | Completed | 7 and 6 steps, 2 decoys each; the canonical walk, every valid order and every decoy are fixture-tested. `even_square_not_even` is listed for the √2 skill but no decoy uses it (a reviewer note, harmless). |
| P5-S48-03, -04 | `NumberSetsGenerator`, the number rings room | Defect Found & Fixed | Fractions never reduce to a whole, decimals always end, perfect-square roots are integers; the room judges for free. Fixed: the rings now wear ℤ ℚ ℝ in Scholar mode (issue 12). |
| P5-S48-05 | Zone 12 lines and the six Word Gems | Completed | Lint passes; formal definitions present. |
| P5-S48-06 | Core Crystal for a hint-free proof | Dropped (open decision) | Not built; recorded in the decisions log; **Open (Spiro)**. |
| P5-S49-01, -02 | `MysteryGenerator`, the Unsolved Mysteries room | Defect Found & Fixed | Issues 4, 5 and 10. |
| P5-S49-03 … -06 | Zone 12 art, voice, polish, release | Partially Completed | As Sprint 43. |
| P5-S50-01, -02 | Notation rendering, `notation_level` per skill | Defect Found & Fixed | Composed-Label notation, the congruence and set displays drawn in code; issues 11 and 12. |
| P5-S50-03, -04 | Keyboard everywhere, formal glossary | Completed | A test enforces `keyboard` on every number-answer skill in Zones 1–11; all 90 terms have both lines (lint rule 13); the card shows the formal line in Scholar mode only. |
| P5-S50-05, -06, -07 | Badges, ranks, the Scholar decisions entry | Completed | As E5; the entry exists and was corrected (issue 11). |
| P5-S51-01, -02, -09 | Web preset, Pages deploy, the policy's web section | Defect Found & Fixed | Issues 13 and 14. |
| P5-S51-03 … -06 | Web saves, handwriting fallback, audio gate, size budget | Partially Completed | The size budget is in the workflow (43 MB measured); the rest is the manual smoke checklist. The plan's "handwriting fallback on web" no longer applies: recognition is GDScript, so the slate works wherever the browser reports a touch screen and the existing no-touch fallback covers the rest. |
| P5-S51-07, -08 | Full regression, reviewer package for Zones 10–12 | Pending (device/human step) | The packets exist (z11 and z12 regenerated here); the matrix is a device step. |
| P5-S52-01 | Hardening, performance pass, save-migration test | Partially Completed | This review is the hardening pass; frame times are a device step; every fixture migrates. |
| P5-S52-02, -03, -04 | The three guides | Defect Found & Fixed | Issue 20 (stale and incomplete sentences). Nobody but the author has followed them. |
| P5-S52-05, -06, -07 | Maintenance runbook, Version 2.0 release, SDK audit reconfirmation | Partially Completed | The runbook is in `docs/build-and-release.md`; the release is a store step; the audit reconfirmation was missing and is now dated (issue 15). |

### 2.3 Engine idioms and quality checks (what was looked for, and found sound)

- **Godot 4 only.** No `yield`, `emit_signal`, `onready`/`export` without `@`, `.method()` super calls, `File.new()` or `instance()` anywhere outside `addons/`; every script is statically typed and the suites pass with `untyped_declaration` as an error.
- **Lifecycle.** No `_process` or `_physics_process` in the game scenes; the Phase 5 widgets build their nodes in code (no `@onready` against a `.tscn` that could drift; the `.tscn` files are one-node roots with consistent resource ids and `uid://` values, checked by a script over every scene); every `create_tween` is guarded by `is_inside_tree()`; the only tweened redraws are the ride and the dial swing, both bounded.
- **Signals.** Every connection in the new scenes is a bound method or a lambda that touches `self`; the one autoload-free lambda pattern that bit peer review 02 does not recur. The answer panel wires the six new inputs through the same `_on_value_given` as every other input, so the panel never judges an answer.
- **Purity.** No `randi()`, `randf()`, `shuffle()`, `pick_random()` or `randomize()` outside the passed `rng` anywhere in `scripts/`; `make_example` seeds its sub-rng from the passed rng; the proof tray order is seeded from the proof id.
- **Checkers.** The twelve Phase 5 checkers import nothing from the generators and use different algorithms (walking a loop one stop at a time, brute-force undo partners and keys, `pow(a, -1, n)`, `fractions.Fraction`, `math.isqrt`, their own sieve, `itertools` over proof orders); `VISUAL_TYPES` is the same 33-element set in GDScript, in `common.py` and in `curriculum_check.py`.
- **Save points and schema.** Unchanged (v4); the new rooms and screens write nothing; the ranks are derived.
- **Content rules.** Electric light only; no banned theme in any new line, word or picture (lint rules 3 and 12; the word list is screened).

---

## 3. Issues identified and remediation

### Issue 1 (high): the proof builder's "Why?" button took the just-placed step back

- **Where:** `scenes/zones/z12_infinite_core/proof_builder.gd` (`_make_slot`, `select`, `place`).
- **Trigger:** tap a step tile, then tap "Why?" on its slot, as the builder's How line says to do.
- **Root cause:** the Why button was connected to `select.bind(slot)`; `place()` sets `selected` to the slot it filled, and `select()` treats "the picked slot tapped again while filled" as a take-back. So the first thing the How line asks for undid the placement. The same happened after a hint placed a step. The tests pressed the chip buttons directly and never the Why button.
- **Fix:** a separate `pick_why(slot)` that picks a filled slot (so its chips show) and never takes a step back; the slot button keeps the tap-again-to-take-back behaviour.
- **Test:** `test_zone12_answer_panel.gd::test_why_keeps_the_step_and_opens_the_reason_chips`. Fails against the old wiring.

### Issue 2 (high): the Hint ladder could repeat itself forever while counting every press

- **Where:** `proof_builder.gd` (`hint`), `scripts/core/proof_validator.gd` (`next_valid_tiles`), `scenes/mine/mine.gd` (adds `hints_used` to the attempt).
- **Trigger:** Euclid's proof: place s1, s3, s2 (a simple swap) and press Hint. The hint takes s3 back (a gap at slot 1, s2 at slot 2); from then on `next_valid_tiles`, which only knew the slots before the gap, returned s2 as "next"; press 1 lit it (its tray button is hidden), every later press called `place()`, which refused a tile already on the board, while Bolt said "Here is the next step." and `hints_used` grew. Also reachable with the strict proof by picking a later slot before tapping a tile. The child was not hard-stuck, but the ladder never recovered and the inflated count reached the attempt (partial evidence for a proof finished by hand).
- **Root cause:** the hint read a prefix of the board instead of the whole board, and the validator's candidate list ignored tiles sitting past the gap.
- **Fix:** `next_valid_tiles` never offers a tile that is anywhere on the board (strict proofs: the next step of the chain unless it is on the board). `hint()` validates the whole board: a decoy, a duplicate or an out-of-order step anywhere goes back; a wrong reason is set right; a placed step with no reason gets it; then the next step for the first empty slot is lit and placed; when nothing fits the gap because a later step blocks it, that step goes back. A press that finds nothing to do is not counted.
- **Tests:** `test_proof_validator.gd::test_next_valid_tiles_skips_steps_already_on_the_board_past_a_gap`; `test_zone12_answer_panel.gd::test_hints_recover_from_a_gap_and_a_wrong_step_without_looping` (no two presses leave the same board, the proof completes, the count is bounded). Both fail against the old code.

### Issue 3 (medium/high): the toy RSA lock was degenerate: the private key equalled the public key and two locks changed nothing

- **Where:** `scripts/generators/rsa.gd` (`_lock`), `curriculum/skills/z11_cipher_vault.json` (`rsa.toy.*` params), `tools/crosscheck/checkers/rsa.py`, `scenes/zones/z11_cipher_vault/rsa_door.gd`.
- **Trigger:** any `rsa.toy.decrypt` problem (primes 3, 5, 7; keys 3, 5, 7): t is 8, 12 or 24, where every unit is its own inverse, so d = e in 3,000 of 3,000 exported problems and the `used_e_not_d` wrong answer was filtered out every time; 1,841 of 3,000 had the answer equal to the given number (for n = 15 with e = 5 and n = 21 with e = 7 every number is a fixed point). `rsa.toy.encrypt`: 1,155 of 3,000 answers equalled m and 1,795 had d = e. `rsa.toy.keygen` "find d": 978 of 1,531 had d = e. The lock door with 3 and 5 showed "Lock 2 … is 2. Unlock 2 … is 2."
- **Root cause:** `_lock` accepted any e coprime to t; nothing required a different private key or a lock that changes numbers; the decrypt primes were chosen for small keys without noticing that no real key exists below 11.
- **Fix:** `RsaGenerator.is_real_key(e, p, q)` (e below t and coprime, a private key that is a different number, and e not 1 on the loop of lcm(p − 1, q − 1), which would make m^e = m for every m); `real_locks(primes, e_choices, max_d)` lists every real lock in a fixed order; the "find d", lock and unlock questions draw from it (the "find t" question still uses any two primes); the locked number is always one the lock changes; a negative difficulty keeps the locks with the smaller exponent in use and smaller numbers. Params: encrypt keys {3, 5, 7, 13}; decrypt primes {3, 5, 11}, keys {3, 7}, `max_d` 23 (33 with d = 3 or 7, 55 with d = 23, by hand with square-and-multiply). The checker requires a real lock wherever keys are in play, the cap, and an answer that differs from the given number. The door lists primes up to 13, offers only real keys and its Less/More buttons skip pairs with none.
- **Tests:** `test_cipher_vault.gd` (`_assert_real_lock` on every lock in play; `test_real_keys_are_told_apart_and_easier_locks_use_smaller_powers`, incl. 13 on the loop of 48 being a non-key although d ≠ e); `test_checkers_zone11.py::test_a_lock_whose_keys_are_in_play_must_be_a_real_lock` (tampered fixtures); `test_zone11_answer_panel.gd` (the door never lands on a pair without a real lock, every pair shows two different keys and a number that changes). The old fixtures with d = e now fail the checker, as intended.
- **Reviewer item:** the changed parameters and the regenerated `docs/reviews/math-review-packet-z11.md`.

### Issue 4 (medium): the Unsolved Mysteries room could not make 4 or 6

- **Where:** `scenes/zones/z12_infinite_core/mysteries.gd` (`tap_prime`).
- **Trigger:** Goldbach case, number 4 or 6 (the stepper allows 4): the only pairs are 2 + 2 and 3 + 3, and a second tap on a picked prime un-picked it.
- **Fix:** a second tap on a picked prime counts as the pair p + p when 2p is the number; otherwise it lets the prime go as before.
- **Test:** `test_zone12_screens.gd::test_the_mysteries_room_makes_four_and_six_from_one_prime_twice`.

### Issue 5 (low/medium): the larger twin prime got the wrong Bolt hint for 35 of 189 start values

- **Where:** `scripts/generators/mystery.gd` (`_twin`), `tools/crosscheck/checkers/mystery.py`.
- **Trigger:** "Find the next twin primes after 10": the answer is 11; the cousin prime (first prime c > 10 with c + 4 prime) is 13, which is also the larger twin. `gap_not_two` was added first, so `gave_larger_prime` (13) was dropped as a duplicate and a child who answered 13 heard "Twin primes are exactly 2 apart." (The same for p in 3–4, 7–10, 13–16, 37–40, 97–100, 103–106 and 179–190.) The checker mirrored the order, so the cross-check could not see it.
- **Fix:** `gave_larger_prime` is added first in the generator and the checker.
- **Tests:** `test_infinite_core.gd` (the first wrong answer of every twin problem is the larger twin; after 10 it is 13), `test_checkers_zone12.py` fixtures.

### Issue 6 (low/medium): the code-cracking and affine generators ignored the difficulty

- **Where:** `scripts/generators/cipher.gd` (`_crack`, `_affine`), `curriculum/builds.json` (the Vault Door's first code is `difficulty: -1`), hint rung 4.
- **Trigger:** `cipher.caesar.crack` at difficulty −1 produced the identical problem to difficulty 0 for 2,000 of 2,000 seeds; `_affine` called `eased_max(1, 3, d, 2)`, whose minimum span floored the result at 3, its own maximum.
- **Fix:** crack eases the word length (3–8 letters at 0, at most 6 at −1 and 4 at −2) and the shift (at most 18 and 12); affine keeps the smaller multipliers of its ordered list and a smaller shift b.
- **Consequence fixed with it:** at −2 a cracking problem could find no worked example, because "the same problem" was judged by prompt parameters and picture alone and a cracking prompt names only the word's length. "The same problem" now also means the same answer, in `GeneratorKit.make_example`, `GeneratorChecks` and `common.py`.
- **Test:** `test_cipher_vault.gd::test_cracking_and_affine_problems_get_easier_at_a_lower_difficulty`; the shared checks at −1 and −2 pass again.

### Issue 7 (low): the clock lock's Set handed in the untouched 0

- **Where:** `scenes/zones/z10_clockwork_depths/clock_lock.gd`.
- **Trigger:** press Set (or Enter) before tapping a mark: 0 was handed in as an attempt, right whenever a + b wraps to 0. The mixing table's Done waits for a choice; the lock did not.
- **Fix:** Set and Enter wait for the first tap on a mark (`pointed_once`).
- **Test:** `test_zone10_answer_panel.gd` (Set is disabled and `submit()` emits nothing before a tap).

### Issue 8 (medium, checker): the group checker never recomputed a worked example's answer

- **Where:** `tools/crosscheck/checkers/group.py` (`_identity`, `_inverse`, `_closure`, `_table`, `_cyclic`).
- **Trigger:** an exported `group.*` problem whose rung-3 example carried a wrong answer passed the cross-check: `_identity` computed the example's op and never used it, `_inverse` checked only the parameter names, `_closure` had no example check, `_table` compared a value the generator sets from the answer with the answer (a tautology), `_cyclic` only required `j` to equal the stated answer. The modular and divisibility checkers recompute every example; this one did not.
- **Fix:** each example's answer is recomputed with the checker's own helpers (the do-nothing number, the undo partner, the wrapped cell, the jump count; for closure the yes/no against the biggest raw value of a table of the example's size, which is all the example records).
- **Test:** `test_checkers_zone10.py::test_a_group_worked_example_with_a_wrong_answer_is_caught` (five tampered examples).

### Issue 9 (low): a hint that took a wrong step back said "Here is the next step."

- **Where:** `proof_builder.gd` (`hint`), `text/lines.csv`.
- **Fix:** a new line `z12.builder.hint_back` ("Let's take that step back. It does not fit yet.") for every take-back a hint makes.
- **Test:** `test_zone12_answer_panel.gd::test_a_hint_takes_a_decoy_back_with_its_own_words`.

### Issue 10 (low, rule 5): the `mystery.*` skills were labelled pictorial and carried no picture

- **Where:** `scripts/generators/mystery.gd`, `tools/crosscheck/checkers/mystery.py`.
- **Fix:** a pictorial Goldbach problem shows the number line to n with n marked (the rung 2 model); a pictorial twin problem shows the model's window with only p marked (the model adds the pair, so the picture never reveals the answer). The checker requires both.
- **Test:** `test_infinite_core.gd`, `test_checkers_zone12.py` fixtures.

### Issue 11 (medium, spec): `Skill.notation_level` contradicted `NotationRules`

- **Where:** `curriculum/skills/z10_clockwork_depths.json`, `z12_infinite_core.json`, `scripts/core/skill.gd`, `tools/ci/curriculum_check.py`, `docs/decisions.md` (Scholar part 2 entry), `tests/scenes/test_scholar_part2.gd`.
- **Trigger:** the data and two comments put the congruence sign at level 2 (Scholar-only), while `NotationRules` (the only thing the screens consult) and the recorded deviation keep it in Explorer mode at level 1; the skill's level is read by nothing at runtime, so the two could drift unnoticed.
- **Fix:** the data follows the rules: `mod.congruence.*` are level 1; the three `sets.*` skills, which carry the set symbols, are level 2; the comments and the decisions entry say so; a test asserts that only `sets.*` skills are level 2.

### Issue 12 (medium, spec): the Scholar-only set symbols ℤ ℚ ℝ had no producer in the game

- **Where:** `scenes/zones/z12_infinite_core/core_art.gd`, `scenes/ui/math/set_symbol_display.gd`.
- **Trigger:** no generator, scene or vocabulary picture emitted the `set` notation form; `SetSymbolDisplay` was reached only by a test, so the Scholar-mode payoff the decisions log and the plan's completion table name was unreachable.
- **Fix:** `SetSymbolDisplay.draw_strokes` paints the double-struck strokes on any canvas; `CoreArt` draws ℤ, ℚ and ℝ beside their rings in every `number_card` picture with rings (the `sets.*` problems, their hint models, the number rings room) when `CoreArt.set_symbols_shown()` (Scholar mode with math notation on); Explorer mode keeps the words on the buttons and in the lines.
- **Test:** `test_scholar_part2.gd::test_the_number_rings_wear_their_symbols_only_in_scholar_mode` (the mode switch, the symbol boxes inside their bands and apart, the picture drawing in both modes).

### Issue 13 (medium, compliance): the web deploy would have published the privacy policy's draft header and fill-ins

- **Where:** `.github/workflows/web-deploy.yml`, `tools/web/render_policy.py`, `docs/privacy-policy.md`.
- **Trigger:** the policy still carries "draft, not yet published", bracketed fill-ins for the effective date, the developer name and the contact email, and a publishing note; the renderer had no guard and no blockquote handling, so the first `v*` tag would have published them verbatim on the public page of a children's app.
- **Fix:** `draft_problems()` names every draft mark and fill-in; the renderer prints them and, with `--strict`, refuses to render; the workflow passes `--strict` on a version tag (the only ref it publishes) and only warns on `main`; `> ` notes render as blockquotes.
- **Tests:** `tools/web/test_render_policy.py` (a draft is named and refused when strict, rendered with a warning otherwise; the real policy's state matches the renderer's verdict).

### Issue 14 (medium, compliance): the policy and the build guide claimed a web progress export that no code makes

- **Where:** `docs/privacy-policy.md` (the web section), `docs/build-and-release.md`, `scenes/shell/parent_area/dashboard.gd`.
- **Trigger:** both said a parent exports or imports a progress file "through the browser's own download and file-open dialogs"; the dashboard uses Godot's `FileDialog` with `use_native_dialog`, which has no native dialog on the web platform, so the fallback dialog browses the engine's virtual file system: a file written there never reaches the computer's disk and one on the disk cannot be opened. No `JavaScriptBridge` code exists.
- **Fix:** on the web (`DashboardScreen.is_web()`, `OS.has_feature("web")`) the dashboard shows a parent line, `parent.dash.web_no_transfer`, instead of Export and Import; the policy and the guide say progress stays in that browser and the app is the way to move it. A browser download is recorded as an open item for Spiro (section 4).
- **Test:** `test_dashboard_v2.gd::test_the_web_version_offers_no_progress_file`.

### Issue 15 (low, docs): the SDK audit had no Phase 5 reconfirmation and said "both presets"

- **Fix:** a dated reconfirmation entry (plan item P5-S52-07) and "every preset, Android, Android AAB and Web"; `check_sdk_audit.py` and its tests pass.

### Issue 16 (perf, low): the circular track rebuilt its picture dictionary on every frame of a ride

- **Where:** `scenes/zones/z10_clockwork_depths/circular_track.gd` (`_LoopPicture._draw`).
- **Trigger:** the Ride button tweens `cart` for up to 2.4 s, and every redraw called `ModularGenerator.clock_track`, allocating a new dictionary (plus the arrow array and the station strings in `ClockArt`). `perf_check.py` scans `_process` and literal allocations in `_draw`, so an allocation behind a static call is invisible to it.
- **Fix:** the picture is built once in `setup()` and the ride only writes `cart` into it. The remaining per-station strings in the painters are a section 4 note.

### Issue 17 (low): a Word Gem whose formal line is missing showed "[its.id]"

- **Where:** `autoload/text.gd` (`term_definition`). Lint rule 13 catches the data error in CI; this is robustness for a hand-edited table.
- **Fix:** `scholar_text` is empty when the listed line is not in the table.
- **Test:** `test_text.gd::test_a_missing_formal_definition_line_gives_no_placeholder`.

### Issue 18 (low, docs): Zone 10 and 11 deviations and misconception names missing from the decisions log

- **Fix:** the Zone 10 entry lists the smaller loops (`mod.add.wrap` n ≥ 3, `mod.mul.wrap` n ≥ 4, inverse and table n ≥ 3, cyclic n ≥ 4, remainder a ≥ n, the representation changes); the Zone 11 entry lists `forgot_minus_one` and `used_e_as_d`, the plan's three unused names, the `modinv.*` loop sizes, the affine shift from 1, the wheel's buttons and the ladder that is not built.

### Issue 19 (low, docs): the decisions log described a circular-track layout that never shipped

- **Where:** `docs/decisions.md` (Zone 10 entry), `tests/scenes/test_zone10_answer_panel.gd`.
- **Trigger:** the entry said the stations are buttons "on a circle sized so neighbours do not touch (a loop of 12 needs about 310 dp square; on phones the buttons shrink to the chord, not below 28 dp)". The code, from the first Zone 10 commit, puts them in an `HFlowContainer` row under the picture, each a full touch target that never shrinks; the test's "at least 28 px" was a vestige of the draft.
- **Fix:** the entry describes the row; the test asserts one full touch target per station.

### Issue 20 (low, docs): stale sentences in the guides, the README, the narration folder and three comments

- `docs/curriculum-data-guide.md`: the packets now cover Zones 6 to 12; the answer modes include the two handwriting modes; the formal `scholar_definition` line is named for the reviewer; the proof order flag is named (`orderings`). `docs/how-to-add-a-zone.md`: a new music loop must first be added to the generator's `TRACKS` dictionary. `docs/build-and-release.md`: the `-c` sentence; the Web preset has no permission keys. `README.md` and `narration/README.md` described the dropped `Narration` autoload and `tools/voice/`. `scripts/core/mode_gate.gd`, `tests/generators/test_modular.gd`, `scripts/generators/group.gd` and `scenes/zones/z11_cipher_vault/cipher_wheel.gd` carried comments that overstated or misdescribed the code.

### Issue 21 (low): the proof page dereferenced a null proof for an unknown id

- **Where:** `scenes/zones/z12_infinite_core/proof_page.gd`. Only the journal's three fixed ids reach it today.
- **Fix:** an unknown id logs an error and builds the frame with the journal's title and a Back button instead of crashing.

### Checked and found correct (no change)

- `ProofValidator` against every rule in the plan (completeness, partial versus strict order, every error kind, decoys anywhere, a tile placed twice, a chip on an empty slot, extra entries); Euclid's proof has exactly two valid orders and both the GdUnit walk and the Python `itertools` walk find them.
- Every Zone 10 and 11 distractor rule for every reachable parameter (brute force in Python by the reviewers): no wrong answer equals the answer or another after the shared filtering; the Caesar word list has no shift partners; the affine multipliers are all coprime to 26; the extended-Euclid x is unique; the coin puzzle's answer is unique and its "decide" bound is exact; `pow_mod`, `private_key` and the round trip for every m.
- Every Zone 12 generator: Goldbach answers are prime pairs with at least two invalid wrong pairs for every even n; the next twin is the first after p; fraction cards never reduce, decimals always end, perfect squares are integers; mini-proof chains start with an assumption and end with "previous"; the scrambled order is never the identity.
- Ranks: the boundaries, Master Miner's Zone 10 condition, Core Keeper's every-zone condition, nothing saved; the hub label is rebuilt with the hub (the shell re-instantiates every screen) and the dashboard refreshes it.
- Badges: the four new entries, awarded on every mastery, idempotent; `BadgeArt` draws the new emblems including `infinity`.
- Scholar part 2: `ModeGate` (explorer off, scholar on, auto by grade), the Word Gem card's formal line in Scholar mode only, lint rules 13 and 14 and their tests, every term with both lines, keyboard on every number skill.
- The Web preset's filters and settings, the workflow's first-party actions, permissions, tag gating and size budget, the landing page without scripts.
- The secret message: nothing persisted, copied, shared, exported or captured; lint rule 12; the museum gates the two Zone 11 screens and the journal on mastery; the shell routes every new screen.
- The shared-scene diffs of Phase 5 (`mine.gd`, `answer_panel.gd`, `shell.gd`, `backdrop.gd`, `museum.gd`, `workshop_art.gd`, `build_site.gd`, `rewards.gd`, `text.gd`, `problem.gd`, `skill.gd`): no changed default, signal signature or saved field; `LAST_PALETTE_ZONE` is 12 and every palette is exercised.

### Noted, not changed (see section 4)

- The mirror cell of a commutative mixing table shows the answer of "fill the box" (`group.table.complete`, `mod.mul.wrap` pictorial) whenever row ≠ column.
- Hint rung 2 for the three starter proof skills lights the asked card, which is the answer, one rung before the worked example (consistent with "hints are partial evidence", but worth a deliberate decision).
- `used_composite` can name 1 in a pair ("1 + 19"); its Bolt line says "not prime", which is true, so wording only.
- The `addons/digit_ink/*` entry in the Web preset's exclude filter names a folder that does not exist (harmless; an export-setting change needs Spiro).
- The extended-Euclid ladder and the web download (section 4).

---

## 4. Technical debt and architectural notes before the human and device steps

1. **The extended Euclid ladder is the one Phase 5 mechanic the plan describes that is not built.** `euclid.extended.coeffs` asks for the x the backward run gives, but nothing draws the backward run: `VaultArt.ladder_lines` writes only the forward rows and the lock door states d. The child is never shown how x or d is found. It is now recorded as such in the decisions log; a `ladder` picture (the back-substitution rows under the forward ones, one step per tap in `EuclidMachine`) is a contained addition for the reviewer and Spiro to call.
2. **The web version's progress file.** The dashboard now offers none on web and the policy says so. If families on school Chromebooks need it, `JavaScriptBridge.download_buffer` for the export is about twenty lines; the import would need a file-input shim and is the larger half. Decide before the web build is announced.
3. **Hint evidence for the proof builder.** Every hint press counts one, including the three presses that light, place and justify one step, so a fully hinted seven-step proof records about twenty hints against a rock whose ladder elsewhere caps at four. `Bkt.update_with_hints` treats any hint as partial evidence, so the count only matters if it is ever weighed; keep it in mind if the BKT fit (`tools/bkt/fit.py`) is run on Zone 12 attempts.
4. **The mirror cell gives the answer away** in the two "fill the box" pictures on commutative tables. Blanking the mirror cell too needs the `cayley` picture to carry a second blank (format, both validators, the painter, the checkers); a small change, but a format change, so it is a reviewer item first.
5. **`perf_check.py` cannot see allocations behind a static call in `_draw`.** Issue 16's dictionary was invisible to it, and `ClockArt` still builds a string per station on every redraw of a ride or a dial swing (bounded at 2.4 s and 0.25 s). A rule that a `_draw` reachable from a tweened property setter may not call a `*Generator.*` picture builder would catch the next one; precomputing the station labels in the painters' callers would remove the strings.
6. **Simulated learners do not cover Zones 10–12.** The plan's Phase 5 testing section asks for fast, average and random learners through the Zone 10–12 graphs; `test_simulated_learners.gd` runs the random guesser over the whole catalog (so Zones 10–12 are included there) but the fast and average learners over Zone 1 only. A fast-learner run limited to one zone needs its prerequisites pre-mastered (the scheduler's `limit_to` does not do that), so it is a small helper plus three tests.
7. **The Web export is not in PR CI.** `web-deploy.yml` exports only on `main` and tags, so a pull request can break the export or the 150 MB budget without a red check. The export templates are a large download; a weekly or a label-triggered job would keep PR time flat.
8. **Lambdas in static functions.** `_real_lock` first used a `sort_custom` lambda and was replaced by a plain ordering function when its behaviour was in doubt; the ordering was in fact right and the doubt was the reviewer's arithmetic, but the plain version is clearer and the generator rule "no lambdas over locals" (peer review 02, section 4) is easier to check when there are none.
9. **The guided proofs assume a lemma.** `proof.sqrt2.irrational` uses "if a square is even, the number is even" without a page of its own, and the √2 skill lists `even_square_not_even` although no decoy uses it. The reviewer may want the lemma as a fourth practice proof.
10. **Reviewer packets are snapshots.** `docs/reviews/math-review-packet-z11.md` and `-z12.md` were regenerated here; the z12 one needs `--samples 30` to match its first version, which the packet header does not record. Adding the sample count to the header line would make regeneration reproducible.

---

## 5. Verification record

All runs are in this environment (Godot 4.7.2 stable Linux headless, Python 3.13); nothing needing a device, a renderer, the Android SDK or the keystore was run.

| Check | Baseline (before any change) | After the fixes |
|---|---|---|
| Headless import | clean | clean |
| Main scene, 3 frames headless | clean (exit-time audio report, as peer review 02 note A) | clean |
| GdUnit4 (`runtest.sh -c -a res://tests`) | 1572 tests, 160 suites, 0 failures, 0 orphans | **1582 tests, 160 suites, 0 failures, 0 orphans** (10 new tests) |
| pytest (`tools`, with `GODOT` set) | 1241 passed, 3 skipped | **1246 passed, 3 skipped** (5 new tests) |
| `lint_content.py` | 0 errors, 0 warnings | 0 errors, 0 warnings |
| `perf_check.py` | 0 problems, exported 4.9 MB | 0 problems, exported 5.0 MB |
| `curriculum_check.py` | 0 problems | 0 problems |
| `check_sdk_audit.py` | 2 dependencies, 0 missing | 2 dependencies, 0 missing |
| Cross-check, 176 skills × 10,000 | all passed | **all passed** (generators changed: `rsa.gd`, `cipher.gd`, `mystery.gd`, `generator_kit.gd`) |
| Cross-check, 176 skills × 2,000 at difficulty −1 | all passed | **all passed** |
| Cross-check, 176 skills × 2,000 at difficulty −2 | all passed | **all passed** |
| Regression tests vs. the unfixed sources | — | the proof builder and validator tests were run against the reverted sources (3 validator failures, 48 panel assertions) and pass with the fix; the checker tamper tests fail without the recomputation; the lock fixtures with d = e fail the new checker |

The 3 pytest skips are the handwriting trainer (needs PyTorch and the MNIST download) and the private-digit loader (no `private/`).

---

## 6. Status synchronization

`status.md` was updated in this change: the header (date, branch, commit), a "Recent changes" entry for this review, the health check with the numbers above, and section 5 gains the two open items this review surfaced (the extended-Euclid ladder picture; a web download for the progress file). The open items that were already there are unchanged: none was closed by code. `docs/decisions.md` has the review's entry and the corrected Phase 5 entries (Zone 10 layout and deviations, Zone 11 lock and names, Scholar levels, Zone 12 after the review, the web dashboard and the strict policy page). `docs/reviews/math-review-packet-z11.md` and `-z12.md` were regenerated.
