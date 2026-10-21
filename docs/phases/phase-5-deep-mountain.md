# Phase 5: Deep Mountain (Sprints 41–52)

> **Status (2026-10-20):** Phase 5 is built in code, without the voice, art-commissioning and Play-release rows: Zones 10, 11 and 12, Scholar mode part 2, Master Miner ranks, the Web export preset and workflow and the three guides. What changed from this plan is recorded in the 2026-10-20 sections of `docs/decisions.md`. What remains is human, device and store work (`status.md` section 5): reviewer sign-off, browser and device checks, the closed test and the releases.

Detailed implementation plan for the final content phase of *Gem Mines of Number Mountain*. This document expands section 8.6 and 8.7 of the master plan (`docs/development-plan.md`). Read `CLAUDE.md` first: its non-negotiable rules, content rules and "ask Spiro before" list apply to every item below. The previous phase is `docs/phases/phase-4-middle-mountain.md`.

Godot idioms used in this document are explained the first time they appear, since the product owner is new to Godot.

---

## Overview

| Item | Value |
|---|---|
| Phase | 5 of 5: Deep mountain |
| Sprints | 41–52 (12 one-week sprints; Sprint 43 is a 4-day holiday week) |
| Dates | August 23 – November 12, 2027 |
| Status | Provisional. Confirmed at the Phase 4 review (end of Sprint 40, August 20, 2027). |
| Milestone | **Version 2.0, the full game**, end of Sprint 52 (Friday, November 12, 2027) |
| Entry gate | Version 1.5 (Zones 1–9) is live on Google Play; Phase 4 exit criteria met |
| Zones | 10 Clockwork Depths, 11 Cipher Vault, 12 The Infinite Core |
| Also | Scholar mode complete, remaining mathematician badges, Master Miner ranks, web version, developer documentation, maintenance mode |

**Outcome.** By the end of this phase the mountain is complete. A player who has reached Zone 10 learns modular arithmetic and discovers that the clock numbers ℤₙ form a group, using the vocabulary of a college course. Zone 11 turns that into ciphers, the Euclidean algorithm and a toy version of RSA, and lets the child encode a secret message for a parent to decode on paper. Zone 12 is the Mathematician's Journal, where the child assembles real proofs (Euclid's infinitely many primes, the irrationality of √2) from drag tiles, then visits the Unsolved Mysteries room. Scholar mode is finished, every mathematician badge exists, a web build serves families with locked-down school Chromebooks, and three guides let a future developer (or a future Spiro) build, release and extend the game.

**Explicitly out of scope for Phase 5:**

- Any zone beyond 12, or any new math topic not listed in section 2.3 of the master plan.
- Cross-device sync changes (the Phase 2 approach stands).
- New third-party SDKs or plugins (the web build uses only Godot's own export template).
- Multiplayer, chat, sharing to social networks, or any feature that sends data off the device. The secret-message feature is on-screen only.
- Live AI of any kind in the shipped game.
- Changing BKT thresholds, curriculum prerequisites for Zones 1–9, or the save schema without the Phase 2 migration process and Spiro's sign-off.

---

## Entry criteria

Phase 5 starts only when all of these hold at the end of Sprint 40:

1. **Version 1.5 is public.** Zones 1–9 are released on Google Play with narration coverage of 100% of child-facing lines, and the Sprint 38 target-API update is live.
2. **Scholar mode part 1 exists** (Sprint 37): keyboard entry through `InputRouter`, on-screen math notation for exponents and fractions, and the per-feature switch (`Profiles` setting plus reading checks) described in section 3.3 of the master plan.
3. **The zone pipeline is proven.** Each Phase 4 zone shipped with the three-sprint pattern (curriculum and generators, mechanic and project, art/voice/polish/release), and `docs/decisions.md` records the pattern.
4. **The generator contract is stable.** `static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem` is unchanged since Phase 1, every Zone 1–9 generator has a GdUnit4 suite and a Python cross-checker, and `python tools/crosscheck/run.py --all --n 10000` passes.
5. **The voice pipeline is routine.** `python tools/voice/generate.py --changed` produces audio for new lines and number clips 0–1,000 exist.
6. **Save schema** is at the version shipped in 1.5, with fixtures for every prior version in `tests/save/fixtures/`.
7. **Math reviewer** has signed off Zones 1–9.
8. **CI** (GitHub Actions) runs `--import`, GdUnit4, pytest, `lint_content.py` and a debug Android export on every merge.

If an item is missing, the first days of Sprint 41 close the gap before Zone 10 work starts; do not build Zone 10 on an unstable pipeline.

---

## Architecture and design

### Zone 10: Clockwork Depths

**Theme.** The deepest working level of the mine. Everything here rotates: circular cart tracks with n stations, gear clocks, and vault locks whose dials only have the numbers 0 to n−1. A cart that goes "12 stations forward on a 7-station loop" ends at station 5. That picture is modular arithmetic.

**Mechanics (new in this zone).**

| Mechanic | Scene | Description |
|---|---|---|
| Circular track | `scenes/zones/z10_clockwork_depths/circular_track.tscn` | A loop of n stations (n from 2 to 12). Bolt's cart starts at station 0; the child drags the cart or taps a station to answer "where does the cart stop?" |
| Clock lock | `scenes/zones/z10_clockwork_depths/clock_lock.tscn` | A dial with n positions. The child rotates it by dragging (through `InputRouter`, so finger, pen and mouse all work) to set a remainder. |
| Mixing table | `scenes/zones/z10_clockwork_depths/mixing_table.tscn` | A Cayley table for (ℤₙ, +) or (ℤₙ, ×). Cells are tap targets; the child fills a cell or finds the identity, an inverse, or a row that proves closure. |
| Divisibility lens | `scenes/zones/z10_clockwork_depths/divisibility_lens.tscn` | Shows why a rule works: for 9, the digits light up and their sum appears on a 9-station loop. |

**Skills.** File: `curriculum/skills/z10_clockwork_depths.json`. Skill IDs follow `topic.subtopic.action`. Prerequisites must keep the skill graph acyclic (the existing graph test enforces it). The Zone 9 prerequisites named below are the IDs used in `docs/phases/phase-4-middle-mountain.md`; if Phase 4 shipped different IDs, use those.

| Skill ID | Prerequisites | Generator | Params | Representations | Distractor misconceptions |
|---|---|---|---|---|---|
| `mod.remainder.find` | `div.facts.by_6_10` (Z4) | `ModularGenerator.remainder` | `n: [2,12]`, `a: [0,99]` | concrete (track), pictorial (number line with loops), abstract (`a mod n`) | `gave_quotient`, `forgot_mod_wrap`, `off_by_one` |
| `mod.track.stop` | `mod.remainder.find` | `ModularGenerator.track_stop` | `n: [3,12]`, `steps: [1,60]` | concrete, pictorial | `forgot_mod_wrap`, `counted_start_station` |
| `mod.track.backward` | `mod.track.stop` | `ModularGenerator.track_stop` with `direction: -1` | same | concrete, pictorial | `negative_remainder`, `forgot_mod_wrap` |
| `mod.congruence.check` | `mod.remainder.find` | `ModularGenerator.congruence_check` | `n: [2,12]`, `a,b: [0,120]` | pictorial, abstract (`a ≡ b (mod n)`) | `compared_quotients`, `compared_raw_values` |
| `mod.congruence.notation` | `mod.congruence.check` | `ModularGenerator.notation_read` | as above | abstract | `swapped_mod_and_value`, `read_as_equals` |
| `mod.add.wrap` | `mod.track.stop` | `ModularGenerator.mod_add` | `n: [2,12]` | concrete (dial), abstract | `forgot_mod_wrap`, `subtracted_instead` |
| `mod.mul.wrap` | `mod.add.wrap` | `ModularGenerator.mod_mul` | `n: [2,12]` | pictorial (table), abstract | `forgot_mod_wrap`, `added_instead` |
| `group.identity.find` | `mod.add.wrap` | `GroupGenerator.identity` | `n: [2,12]`, `op: add/mul` | pictorial (mixing table) | `picked_one_for_add`, `picked_zero_for_mul` |
| `group.inverse.find` | `group.identity.find` | `GroupGenerator.inverse` | `n: [2,12]`, `op: add` | pictorial, abstract | `gave_negative_raw`, `gave_same_value`, `forgot_mod_wrap` |
| `group.closure.verify` | `group.inverse.find` | `GroupGenerator.closure_row` | `n: [2,9]` | pictorial | `left_cell_blank`, `wrote_value_ge_n` |
| `group.table.complete` | `group.closure.verify` | `GroupGenerator.table_fill` | `n: [2,7]`, `missing: [1,4]` | pictorial | `forgot_mod_wrap`, `row_col_swap` |
| `group.cyclic.generate` | `group.table.complete` | `GroupGenerator.generator_orbit` | `n: [3,12]` | concrete (track), abstract | `stopped_early`, `skipped_identity` |
| `div.rule.explain_3_9` | `mod.remainder.find`, `pv.tens_ones.digit_value` (Z1) | `DivisibilityGenerator.digit_sum_rule` | `base: 3 or 9`, `a: [10,999]` | pictorial (lens), abstract | `used_last_digit`, `summed_wrong` |
| `div.rule.explain_2_5_10` | `mod.remainder.find` | `DivisibilityGenerator.last_digit_rule` | `base: 2,5,10` | pictorial | `used_first_digit`, `used_digit_sum` |
| `div.rule.explain_4_8` | `div.rule.explain_2_5_10` | `DivisibilityGenerator.last_digits_rule` | `base: 4 or 8` | pictorial, abstract | `used_last_digit_only` |

The `mod.track.backward` skill introduces `(−3) mod 7 = 4`. The generator returns the non-negative canonical remainder; GDScript's `%` keeps the sign of the dividend, so the generator must use `posmod()` (confirm in the Godot docs). The cross-checker must use Python's `%`, which is already non-negative for positive n. The two implementations differ, which is the point of an independent check.

**Generator signatures.** All generators live in `scripts/generators/`, hold no node references and no globals, and use only the passed `rng`.

```gdscript
# scripts/generators/modular_generator.gd
class_name ModularGenerator
extends RefCounted

## Pure problem generators for Zone 10 modular arithmetic.
## Never call randi(); always use rng so tests reproduce by seed.

static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	match skill.generator:
		"remainder": return remainder(skill, params, rng)
		"track_stop": return track_stop(skill, params, rng)
		"congruence_check": return congruence_check(skill, params, rng)
		"notation_read": return notation_read(skill, params, rng)
		"mod_add": return mod_add(skill, params, rng)
		"mod_mul": return mod_mul(skill, params, rng)
	push_error("Unknown generator %s" % skill.generator)
	return null

static func remainder(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func track_stop(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func congruence_check(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func notation_read(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func mod_add(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func mod_mul(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
```

```gdscript
# scripts/generators/group_generator.gd
class_name GroupGenerator
extends RefCounted

static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func identity(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func inverse(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func closure_row(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func table_fill(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func generator_orbit(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem

## Builds the full Cayley table for (Z_n, op). Used by problems and by the
## mixing_table scene for display. Returns rows of length n.
static func cayley_table(n: int, op: StringName) -> Array[Array]
```

```gdscript
# scripts/generators/divisibility_generator.gd
class_name DivisibilityGenerator
extends RefCounted

static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func digit_sum_rule(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func last_digit_rule(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func last_digits_rule(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
```

**`Problem` additions.** The Zone 10 `Problem.representation` payload for the track and table is a `Dictionary` with keys `n`, `op`, `start`, `steps`, `highlight_cells`. No new fields on the `Problem` resource class; if one proves necessary, log it in `docs/decisions.md` and bump nothing in the save schema (problems are never saved, only attempts).

**Answer modes.** `tap` (station, cell), `drag` (cart, dial), `number_pad`, `keyboard` (Scholar mode). Handwriting via `ChalkSlate` for single-digit remainders.

**Vocabulary (Word Gems).** `remainder`, `modulo`, `congruent`, `identity`, `inverse`, `closure`, `group`, `cyclic`. Each gets an entry in `curriculum/vocabulary.json` with a kid-sized definition and a picture; "group" is explained as "a set of numbers and a way to mix them, where every mix stays inside the set, there is a do-nothing number, and every number has an undo partner."

**Text lines.** Zone 10 line IDs use the prefix `z10.` (for example `z10.track.prompt_where_stops`, `z10.table.prompt_find_identity`). Numbers are placeholders (`{n}`, `{a}`, `{b}`). The notation `a ≡ b (mod n)` is rendered by the Scholar-mode notation renderer, never baked into a line.

### Zone 11: Cipher Vault

**Theme.** A vault of locked doors. Each door is a cipher, and opening it means understanding the math behind it: shift (Caesar), multiply-and-shift (affine), the modular inverse that undoes it, and the Euclidean algorithm that finds the inverse.

**Mechanics.**

| Mechanic | Scene | Description |
|---|---|---|
| Cipher wheel | `scenes/zones/z11_cipher_vault/cipher_wheel.tscn` | Two concentric rings of A–Z. Dragging the outer ring sets the shift. Letters map through `(x + k) mod 26`; the affine version adds a multiplier dial. |
| Euclid machine | `scenes/zones/z11_cipher_vault/euclid_machine.tscn` | Animated basic algorithm: two bars of lengths a and b; the shorter is laid along the longer; the leftover becomes the new short bar. The extended version shows the back-substitution as a ladder. |
| Coin puzzle | `scenes/zones/z11_cipher_vault/coin_puzzle.tscn` | Diophantine equations `ax + by = c` as "pay exactly c with coins worth a and b." Drag coins into a tray. |
| Toy RSA door | `scenes/zones/z11_cipher_vault/rsa_door.tscn` | Small primes only (p, q ≤ 13). The child chooses p and q, the door computes n and φ(n) on screen step by step, the child picks e and finds d with the Euclid machine. |
| Secret message | `scenes/zones/z11_cipher_vault/secret_message.tscn` | See below. |

**Skills.** File: `curriculum/skills/z11_cipher_vault.json`.

| Skill ID | Prerequisites | Generator | Params | Representations | Distractor misconceptions |
|---|---|---|---|---|---|
| `cipher.caesar.encode` | `mod.add.wrap` | `CipherGenerator.caesar_encode` | `shift: [1,25]`, `len: [1,6]` | concrete (wheel), abstract | `forgot_mod_wrap`, `shifted_backward` |
| `cipher.caesar.decode` | `cipher.caesar.encode` | `CipherGenerator.caesar_decode` | same | concrete, abstract | `shifted_forward`, `forgot_mod_wrap` |
| `cipher.caesar.crack` | `cipher.caesar.decode` | `CipherGenerator.caesar_crack` | `len: [3,8]` (word from a kid word list) | pictorial | `off_by_one_shift` |
| `cipher.affine.encode` | `cipher.caesar.encode`, `mod.mul.wrap` | `CipherGenerator.affine_encode` | `a` coprime to 26, `b: [0,25]` | abstract | `used_non_coprime_a`, `forgot_mod_wrap`, `added_before_multiply` |
| `cipher.affine.decode` | `cipher.affine.encode`, `modinv.find.small` | `CipherGenerator.affine_decode` | same | abstract | `used_a_not_inverse`, `forgot_subtract_b` |
| `modinv.exists.decide` | `gcf.find.by_listing` (Z6) | `ModInverseGenerator.exists` | `n: [2,26]` | pictorial (table) | `thought_always_exists`, `used_gcd_not_inverse` |
| `modinv.find.small` | `modinv.exists.decide`, `group.inverse.find` | `ModInverseGenerator.find_small` | `n: [2,13]` | pictorial, abstract | `gave_additive_inverse`, `used_gcd_not_inverse` |
| `euclid.basic.gcd` | `gcf.find.by_listing` | `EuclidGenerator.basic` | `a,b: [2,200]` | concrete (bars), abstract | `stopped_one_step_early`, `gave_last_quotient` |
| `euclid.steps.count` | `euclid.basic.gcd` | `EuclidGenerator.step_count` | same | abstract | `off_by_one` |
| `euclid.extended.coeffs` | `euclid.basic.gcd` | `EuclidGenerator.extended` | `a,b: [2,60]` | pictorial (ladder), abstract | `swapped_coeffs`, `sign_flip` |
| `dioph.linear.solve` | `euclid.extended.coeffs` | `DiophantineGenerator.coin_puzzle` | `a,b: [2,12]`, `c` a multiple of gcd | concrete (coins), abstract | `ignored_gcd_condition`, `negative_coins_when_disallowed` |
| `dioph.linear.decide` | `euclid.basic.gcd` | `DiophantineGenerator.solvable` | same | abstract | `ignored_gcd_condition` |
| `rsa.toy.keygen` | `modinv.find.small`, `pf.tree.build` (Z5) | `RsaGenerator.keygen` | `p,q ∈ {3,5,7,11,13}` | pictorial (door) | `used_n_not_phi`, `e_not_coprime` |
| `rsa.toy.encrypt` | `rsa.toy.keygen` | `RsaGenerator.encrypt` | `m < n` | abstract | `forgot_mod_wrap`, `used_d_not_e` |
| `rsa.toy.decrypt` | `rsa.toy.encrypt` | `RsaGenerator.decrypt` | same | abstract | `used_e_not_d` |

**Generator signatures.**

```gdscript
# scripts/generators/cipher_generator.gd
class_name CipherGenerator
extends RefCounted

const ALPHABET_SIZE: int = 26

static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func caesar_encode(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func caesar_decode(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func caesar_crack(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func affine_encode(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func affine_decode(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem

## Shared pure helpers, also used by the secret-message scene.
static func shift_text(text: String, shift: int) -> String
static func affine_text(text: String, a: int, b: int) -> String
static func is_coprime_26(a: int) -> bool
```

```gdscript
# scripts/generators/euclid_generator.gd
class_name EuclidGenerator
extends RefCounted

static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func basic(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func step_count(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func extended(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem

## Returns [gcd, x, y] with a*x + b*y == gcd. Pure; used by the Euclid machine
## animation and the RSA door.
static func extended_gcd(a: int, b: int) -> Array[int]

## Each step is {a, b, q, r}. Used to drive the animation one step at a time.
static func steps(a: int, b: int) -> Array[Dictionary]
```

`ModInverseGenerator`, `DiophantineGenerator` and `RsaGenerator` follow the same shape in `scripts/generators/mod_inverse_generator.gd`, `diophantine_generator.gd` and `rsa_generator.gd`. RSA exponentiation uses a pure `pow_mod(base: int, exp: int, n: int) -> int` with square-and-multiply so intermediate values stay small; the Python cross-checker uses `pow(base, exp, n)`.

**Secret-message feature (Sprint 45).** Design constraints come straight from CLAUDE.md rule 1 and rule 2: no network, no data leaves the device unless a parent exports it.

- The child types a short note using the on-screen `LetterPad` (a new child-safe input in `scenes/input/letter_pad.tscn`; never `LineEdit`, which would pop up the system keyboard). Letters A–Z and space only, maximum 40 characters.
- The child picks a cipher (Caesar shift, or affine once `cipher.affine.encode` is mastered) and sees the encoded text in large Andika letters, plus a "key card" (the shift, or a and b).
- Bolt says: "Show this to a grown-up. Can they crack it on paper?" The parent copies it by hand. There is no share button, no clipboard copy, no screenshot helper and no file export from the child-facing screen.
- Nothing is persisted except a counter `secret_messages_made` in the rewards save data (an integer, never the text). Messages are not stored.
- Rewards: the first message earns the "Cipher Keeper" gem; no per-message rewards, so it is not a grind.
- `tools/ci/lint_content.py` gains a check that `secret_message.tscn` contains no `LineEdit`, `TextEdit`, `DisplayServer.clipboard_set` or `OS.shell_open`.

**Vocabulary.** `cipher`, `key`, `encode`, `decode`, `coprime`, `modular inverse`, `Euclidean algorithm`, `public key`, `private key`.

### Zone 12: The Infinite Core (proof builder)

**Theme.** The glowing center of the mountain. Instead of rocks, the child finds the Mathematician's Journal, and each page is a proof to assemble. This is where the game teaches what a proof is: a chain of statements where each one is justified by something already known.

**Mechanics.**

| Mechanic | Scene | Description |
|---|---|---|
| Journal | `scenes/zones/z12_infinite_core/journal.tscn` | The hub for Zone 12: pages for each guided proof, the number-sets room and the Unsolved Mysteries room. |
| Proof builder | `scenes/zones/z12_infinite_core/proof_builder.tscn` | A column of empty slots on the left (the proof), a tray of tiles on the right. Drag tiles into slots. Each slot asks "why?" and offers justification chips. |
| Proof tile | `scenes/zones/z12_infinite_core/proof_tile.tscn` | One statement, rendered from a line ID, with a small picture when one exists. Tiles can be decoys. |
| Number sets room | `scenes/zones/z12_infinite_core/number_sets.tscn` | Nested rings: integers inside rationals inside reals. Drag numbers (−3, 1/2, √2, 0.75) to the smallest ring they belong to. |
| Unsolved Mysteries | `scenes/zones/z12_infinite_core/mysteries.tscn` | Display cases for Goldbach and twin primes. Interactive: "find two primes that add to {n}" for even n up to 100; "find the next twin-prime pair after {p}." The case says nobody has proven it works for every number, and that is the mystery. |

**Proof data model.** Guided proofs are data in `curriculum/proofs/*.json`, loaded by a small `ProofLoader` and validated by a pure `ProofValidator` in `scripts/core/`. No proof logic lives in scene scripts.

```json
{
  "schema_version": 1,
  "id": "proof.euclid.infinite_primes",
  "title_line_id": "z12.proof.euclid.title",
  "intro_line_id": "z12.proof.euclid.intro",
  "mode": "guided",
  "steps": [
    {
      "id": "s1",
      "line_id": "z12.proof.euclid.s1",
      "justification": "assumption",
      "depends_on": []
    },
    {
      "id": "s2",
      "line_id": "z12.proof.euclid.s2",
      "justification": "definition.product",
      "depends_on": ["s1"]
    },
    {
      "id": "s3",
      "line_id": "z12.proof.euclid.s3",
      "justification": "theorem.fta",
      "depends_on": ["s2"]
    },
    {
      "id": "s4",
      "line_id": "z12.proof.euclid.s4",
      "justification": "arithmetic.remainder_one",
      "depends_on": ["s2", "s3"]
    },
    {
      "id": "s5",
      "line_id": "z12.proof.euclid.s5",
      "justification": "contradiction",
      "depends_on": ["s1", "s4"]
    }
  ],
  "decoys": [
    { "id": "d1", "line_id": "z12.proof.euclid.d1", "misconception": "assumes_conclusion" },
    { "id": "d2", "line_id": "z12.proof.euclid.d2", "misconception": "n_plus_one_is_prime" }
  ],
  "justifications": ["assumption", "definition.product", "theorem.fta", "arithmetic.remainder_one", "contradiction"],
  "orderings": "partial",
  "scaffold_levels": 3
}
```

Rules the validator enforces:

- A proof is complete when every step in `steps` is placed, no decoy is placed, every placed step appears after all of its `depends_on` steps, and each placed step has the correct justification chip.
- `orderings: "partial"` means any topological order of `depends_on` is accepted; `"strict"` requires the listed order. Euclid's proof is partial; √2 is strict because its steps are a chain.
- A placed decoy is not "wrong" in the punishing sense (rule 8: no cost). Bolt says the configured feedback line for its `misconception` ("Not quite. Does that step use what we are trying to show?") and the tile slides back to the tray.
- `scaffold_levels` drives the hint ladder: level 1 highlights the next correct tile, level 2 fills in the next step, level 3 fills in the justification. Hint use is partial evidence for `Adaptive`, as for every other skill.

```gdscript
# scripts/core/proof.gd
class_name Proof
extends Resource

@export var id: StringName
@export var title_line_id: StringName
@export var intro_line_id: StringName
@export var steps: Array[ProofStep]
@export var decoys: Array[ProofDecoy]
@export var justifications: Array[StringName]
@export var strict_order: bool = false
@export var scaffold_levels: int = 3

# scripts/core/proof_validator.gd
class_name ProofValidator
extends RefCounted

## placement: ordered list of tile ids placed in slots, with the chosen
## justification per slot. Returns a result with .complete, .errors (one per
## slot, by kind: "decoy", "order", "justification", "missing").
static func validate(proof: Proof, placement: Array[Dictionary]) -> ProofResult
static func next_valid_tiles(proof: Proof, placement: Array[Dictionary]) -> Array[StringName]
```

`Resource` is Godot's data-container class: a `Proof` loaded from JSON becomes a typed object the scene can read, like a dataclass, and `@export` makes its fields visible in the editor inspector.

**Skills.** File: `curriculum/skills/z12_infinite_core.json`. Proof skills use the same BKT model: each completed proof without hints is a correct attempt; a hint-assisted completion is partial evidence.

| Skill ID | Prerequisites | Generator or source | Representations | Distractor misconceptions |
|---|---|---|---|---|
| `proof.parts.identify` | `sieve.find.primes_to_100` (Z5) | `ProofGenerator.identify_parts` (given a 3-step mini-proof, tap the assumption / the conclusion) | pictorial | `picked_conclusion_as_assumption` |
| `proof.order.chain` | `proof.parts.identify` | `ProofGenerator.order_chain` (3–4 steps, strict order) | pictorial | `reversed_chain` |
| `proof.justify.step` | `proof.order.chain` | `ProofGenerator.pick_justification` | abstract | `circular_reasoning` |
| `proof.euclid.infinite_primes` | `proof.justify.step`, `pf.tree.build` | `curriculum/proofs/euclid_infinite_primes.json` | guided | `assumes_conclusion`, `n_plus_one_is_prime` |
| `proof.contradiction.recognize` | `proof.euclid.infinite_primes` | `ProofGenerator.spot_contradiction` | abstract | `missed_contradiction` |
| `proof.sqrt2.irrational` | `proof.contradiction.recognize`, `simplify.fraction.gcf` (Z6) | `curriculum/proofs/sqrt2_irrational.json` | guided | `forgot_lowest_terms`, `even_square_not_even` |
| `sets.integer.classify` | `negative.depth.read` (Z7) | `NumberSetsGenerator.classify` | concrete (rings) | `negative_not_integer` |
| `sets.rational.classify` | `sets.integer.classify`, `fraction.equivalent.build` (Z7) | `NumberSetsGenerator.classify` | concrete | `decimal_not_rational`, `integer_not_rational` |
| `sets.real.classify` | `sets.rational.classify`, `proof.sqrt2.irrational` | `NumberSetsGenerator.classify` | concrete | `sqrt_always_rational` |
| `mystery.goldbach.find_pair` | `sieve.find.primes_to_100` | `MysteryGenerator.goldbach_pair` (even n in [4,100]) | pictorial | `used_composite`, `sum_off` |
| `mystery.twin.next_pair` | `sieve.find.primes_to_100` | `MysteryGenerator.next_twin` (p < 200) | pictorial | `gap_not_two`, `not_both_prime` |

**Guided proofs shipped in Phase 5:** Euclid's infinitely many primes (Sprint 47–48), √2 is irrational (Sprint 48). Each has 5–7 steps, 2–3 decoys, and lines in `text/lines.csv` with prefix `z12.proof.`. Every line is a short sentence (Scholar-mode reading level, since Zone 12 players are roughly 11+, but still one idea per line).

### Scholar mode completion

Scholar mode part 1 (Sprint 37) delivered keyboard entry and notation for exponents and fractions. "Complete" (Sprint 50) means every row below is done and recorded in `docs/decisions.md`:

| Feature | Explorer mode | Scholar mode, complete | Switch rule |
|---|---|---|---|
| Problem text | ≤ 12 words, picture first | Full sentence, notation inline, picture optional | Reading check passed (existing from Phase 3) or parent setting |
| Notation | Words ("3 groups of 4") | Symbols: `×`, `÷`, exponents, fractions, `≡`, `(mod n)`, `√`, `gcd(a, b)`, set symbols ℤ ℚ ℝ | Per skill: `skill.notation_level` |
| Answer input | Tap, drag, `NumberPad`, `ChalkSlate` | Adds keyboard through `InputRouter`; `NumberPad` stays available | Device has a keyboard (laptop posture) and profile allows |
| Narration | Read-aloud on by default for young profiles | Off by default; replay button still present on every screen | Profile setting |
| Hint ladder | 4 steps with visuals | Same 4 steps; the worked example uses notation | Same |
| Glossary | Word Gems with pictures | Word Gems plus the formal definition line | Per term, `vocabulary.json` gains `scholar_definition_line_id` |

Notation rendering: build a small `MathLabel` control in `scenes/shell/math_label.tscn` that composes `RichTextLabel` BBCode for superscripts, a `VBoxContainer` for fractions, and Unicode for `≡`, `√`, ℤ, ℚ, ℝ. Andika covers the Latin letters; confirm in the Godot docs that font fallback for the double-struck set symbols works with the project's `Theme` (`theme/default_font` fallbacks), and add a fallback font with a `LICENSE` entry in `assets/CREDITS.md` if needed. Do not add a LaTeX or MathML add-on: that is a new dependency and needs Spiro's approval.

### Badges and Master Miner ranks

**Remaining mathematician badges (Sprint 50).** Phase 2 shipped the first four (Eratosthenes, Euclid, Gauss, Sophie Germain, per the Phase 2 plan). Phase 5 adds the rest from section 4 of the master plan and ties each to Zone 10–12 skills:

| Badge | Unlock | Story line ID (30-second narrated story) |
|---|---|---|
| Pierre de Fermat | Master `rsa.toy.keygen` and `modinv.find.small` (Fermat's little theorem is the idea behind the toy RSA door) | `badge.fermat.story` |
| Srinivasa Ramanujan | Master `fig.triangular.build` (Z9) and `group.cyclic.generate` | `badge.ramanujan.story` |
| Emmy Noether | Master `group.closure.verify` and `group.inverse.find` | `badge.noether.story` |
| Euclid (second badge: "Euclid's Proof") | Complete `proof.euclid.infinite_primes` without hints | `badge.euclid_proof.story` |

Badge data lives in `curriculum/badges.json` (existing file from Phase 2); add entries, never rename IDs. Stories are written in `text/lines.csv` and generated by the voice pipeline (paid call: ask Spiro before running `generate.py` without `--dry-run`).

**Master Miner ranks.** A deterministic rank from mastered-skill count and zones completed, shown on the hub and the parent dashboard. Ranks: Apprentice (0–20 mastered), Digger (21–60), Surveyor (61–100), Engineer (101–140), Master Miner (141+ and Zone 10 complete), Core Keeper (every zone complete). Stored as a derived value, computed by `Rewards.rank_for(profile)`; not saved, so no schema change.

### Web version

**Why.** Families with locked-down school Chromebooks cannot install Android apps. Godot's web export runs in Chrome without installation, which is why the game uses GDScript and not C#.

**Plan (Sprint 51).**

- **Export preset:** add a "Web" preset to `export_presets.cfg` (ask Spiro before changing export settings, per CLAUDE.md). Threads: Godot 4 web builds default to the multi-threaded template, which requires the hosting page to be served with cross-origin isolation headers (`Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`) so `SharedArrayBuffer` is available. GitHub Pages cannot set custom response headers. Two options: (a) the single-threaded web export option (`variant/thread_support = false` in the preset; verify the exact setting name in the Godot 4.7 docs), which runs without those headers; or (b) a small service worker that injects the headers (the "coi-serviceworker" technique). Recommendation: option (a), because it adds no third-party code. Record the choice in `docs/decisions.md`.
- **Hosting:** GitHub Pages from a `gh-pages` branch, published by a GitHub Actions job that runs the headless export. The privacy policy already lives there (Phase 3).
- **No network calls by the game itself.** The page loads the engine files once; after that the game makes no requests. Document this in `docs/privacy-policy.md` as a note for the web version, since the hosting provider sees ordinary HTTP access logs that the app itself never reads.
- **Saves:** `user://` on the web maps to the browser's IndexedDB. `SaveSystem` already writes atomically; test that a page reload keeps progress and that `NOTIFICATION_WM_CLOSE_REQUEST` behaves (on web it may not fire, so the "after every rock" save point carries the load).
- **Handwriting:** the `digit_ink` Android plugin does not exist on web. The existing "plugin unavailable → `NumberPad`" fallback handles it. Add an explicit test.
- **Audio:** browsers block audio until the first user gesture. The title screen's "Tap to start" already provides one; verify narration starts after it.
- **Input:** mouse and touch both work through `InputRouter`. Keyboard works in Scholar mode. No multi-finger gestures.
- **Size:** the web download must stay under the same 150 MB budget. Narration audio for 12 zones is the risk; if it exceeds budget, ship the web build with Explorer-mode narration for Zones 1–5 only and Scholar text elsewhere, and say so on the landing page. Decide in Sprint 51 with real numbers.
- **Not supported on web:** install-time features (nothing), cross-device sync (manual export/import still works through a parent-gated file download; confirm `FileAccess` on web triggers a browser download via `JavaScriptBridge.download_buffer`; verify in the Godot docs).

### Documentation deliverables

Written in Sprint 52, in `docs/`. Each is a Markdown file a new developer can follow without Spiro present.

**`docs/build-and-release.md`**

1. Prerequisites (Godot 4.7.x pinned in `.godot-version`, JDK 17, Android SDK API 36, Python 3.12, ffmpeg)
2. Fresh clone to running game (import, tests, lint)
3. Debug APK and install with `adb`
4. Release AAB: keystore environment variables, version code bump, Play Console upload to internal testing
5. Web build and GitHub Pages publish
6. Voice regeneration (when, cost, `--dry-run` first)
7. Yearly target-API update checklist
8. Rollback: how to re-release the previous AAB

**`docs/how-to-add-a-zone.md`**

1. The three-sprint pattern and what each sprint produces
2. Curriculum file: skill record fields, ID rules, prerequisite DAG test
3. Generator: contract, `rng` rule, distractor rules, GdUnit4 test template, Python cross-checker template
4. Text lines and vocabulary: ID format, reading level, Word Gems, narration regeneration
5. Scene layout: `scenes/zones/zNN_name/`, how the mine scene loads a zone, hub map entry
6. Rewards: gems, badges, build projects
7. Math reviewer hand-off
8. Release checklist (lint, tests, cross-check, device matrix, content update notes)

**`docs/curriculum-data-guide.md`** (for the math reviewer, who does not read code)

1. What a skill is and how to read a skill record
2. How prerequisites work and how to propose a change (needs Spiro's sign-off)
3. How to sample problems from a generator (`python tools/crosscheck/run.py --skill <id> --n 20 --print`)
4. Representations and distractors: what to check
5. Vocabulary and Word Gems
6. Proof files (Zone 12)
7. How BKT mastery is decided (plain language), and why thresholds are not to be changed casually

### Maintenance mode

After Sprint 52 the project moves to 2–4 days per month. Runbook in `docs/build-and-release.md` section 7 plus the cadence in the final section of this document. Nothing in maintenance mode may add network access, SDKs or data collection.

---

## Sprint plan

Sprint dates follow the master plan. Branch names follow `type/scope-summary`; commit messages follow `type(scope): summary`. Every item's "Done when" includes the CLAUDE.md definition of done (device postures, text table, generator checks, saves, lint, tests), which is not repeated per row.

### Sprint 41 (Aug 23–27): Zone 10 curriculum and generators

**Goal.** The Zone 10 skill graph and all modular-arithmetic generators exist, are tested, and are cross-checked, before any scene work.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S41-01 | `content/z10-skill-graph` | `curriculum/skills/z10_clockwork_depths.json` with the 15 skills above | DAG test passes; math reviewer has the file |
| P5-S41-02 | `feat/z10-modular-generator` | `ModularGenerator` (6 functions) | GdUnit4 suite with fixed seeds, 10,000-problem run, cross-check passes |
| P5-S41-03 | `feat/z10-group-generator` | `GroupGenerator` (5 functions plus `cayley_table`) | As above; `cayley_table` tested for n = 2..12 and both ops |
| P5-S41-04 | `feat/z10-divisibility-generator` | `DivisibilityGenerator` (3 functions) | As above |
| P5-S41-05 | `test/crosscheck-z10` | `tools/crosscheck/z10_modular.py`, `z10_group.py`, `z10_divisibility.py` | pytest passes; checker shares no code with generators |
| P5-S41-06 | `content/z10-lines` | Zone 10 prompt, hint and feedback lines (about 60) in `text/lines.csv`; 8 Word Gems in `vocabulary.json` | `lint_content.py` passes; reading level checked |
| P5-S41-07 | `docs/z10-decisions` | Record `posmod` choice and negative-remainder convention in `docs/decisions.md` | Entry exists with date, decision, why, alternatives |

**Implementation notes for the agent**

- Start each generator with its test file (`tests/generators/test_modular_generator.gd`), listing edge cases first: n = 2, a = 0, a = n, a = n − 1, steps = multiple of n, negative steps.
- `track_stop` answer is `posmod(start + direction * steps, n)`. Never use `%` for a value that may be negative.
- Distractors: build from the misconception name, then filter: never equal to the answer, no duplicates, always in range `[0, n)` except `negative_remainder`, which is deliberately out of range and shown only in abstract representation.
- `congruence_check` is a yes/no problem; `Problem.answer_modes` is `["tap"]` with two targets. Distractors are not needed for a two-choice problem; set `distractors` to an empty typed array and make the test assert that.
- The `Skill` record's `representations` list controls which scene renders the problem; the generator only fills the payload.

**Tests**

- Seeded reproducibility: same seed, same problem, for every function.
- 10,000-problem runs: answer in range, distractors valid, params respected.
- `cayley_table(n, &"add")` is a Latin square for every n; `cayley_table(n, &"mul")` row 0 is all zeros.
- Cross-check: Python recomputes every answer with `%`, `pow`, and digit sums from the exported JSON.
- DAG test over all skill files including Zone 10.

**Playtest focus.** Charlie is about 7 and in Zone 3–5 territory; Zone 10 is ahead of him. Spiro walks through 20 generated problems per skill with `--print` and checks wording. If a tester family has a child aged 10+, offer the paper version of the circular track.

### Sprint 42 (Aug 30–Sep 3): Zone 10 mechanics and the cyclic group

**Goal.** The circular track, clock lock, mixing table and divisibility lens play end to end in the mine scene, with the "why divisibility rules work" explainer.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S42-01 | `feat/z10-circular-track` | `circular_track.tscn` and script: n stations, drag cart or tap station, 64 dp targets via `UI.min_target_px()` | Works with finger, pen and mouse; resize safe |
| P5-S42-02 | `feat/z10-clock-lock` | `clock_lock.tscn`: rotating dial, snap to position, `InputRouter` drag | As above |
| P5-S42-03 | `feat/z10-mixing-table` | `mixing_table.tscn`: Cayley table from `GroupGenerator.cayley_table`, tap-to-fill cells, highlight identity row/column and inverse pairs | Table for n ≤ 12 fits every supported aspect ratio |
| P5-S42-04 | `feat/z10-divisibility-lens` | `divisibility_lens.tscn`: digits light up, sum shown on a loop | Animates with `create_tween()`; no allocations in `_process` |
| P5-S42-05 | `feat/z10-zone-integration` | Zone entry on the hub map, mine scene loads Zone 10 skills, hint ladder visuals for each representation | Full dig session in Zone 10 on both devices |
| P5-S42-06 | `feat/z10-vault-build` | Mine-engineering project: "Clockwork Vault" (set three dials so the lock opens, each dial a congruence) | Unlocks Zone 11 door on completion |
| P5-S42-07 | `content/z10-rewards` | Gem types for Zone 10 (gear gems); rank-related display on hub | Deterministic drops; no chance-based value |

**Implementation notes for the agent**

- A **tween** is Godot's way to animate a property over time without writing per-frame code: `create_tween().tween_property(node, "rotation", target, 0.3)`. Use it for dial snapping and cart motion.
- The mixing table is a `GridContainer` of `Button` nodes built in code (`UI.min_target_px()` for size). For n = 12 the table is 13 × 13 cells; test on a 4:3 screen and let the container scale the font down to a floor, not below readable size.
- Keep all game logic (which cell is the identity, which pairs are inverses) in `GroupGenerator`, called from the scene; the scene only lights cells.
- `InputRouter` exposes a drag stream with pointer type; the dial listens to it and ignores additional touch points while a pen stroke is active (palm rejection is already handled centrally).
- Save point after every rock applies; the vault build saves at each dial.

**Tests**

- Scene load tests for each `.tscn` (GdUnit4 `scene_runner`), asserting no missing resources after `--import`.
- Input tests: simulate a drag on the dial through `InputRouter` and assert the snapped position.
- Hub map shows Zone 10 locked until the Zone 9 project is done; unlocks after.
- Save: close mid-vault-build, reopen, dial states restored.

**Playtest focus.** Spiro and a second adult play Zone 10 with mouse and with touch on the tablet. Question to answer: is the mixing table self-explanatory with Bolt's lines, or does it need a worked example first?

### Sprint 43 (Sep 7–10, 4 days, Labor Day): Zone 10 art, voice, polish, release

**Goal.** Zone 10 ships to Google Play as a free content update.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S43-01 | `content/z10-art` | Zone 10 art batch (commissioned or CC0) integrated: background, track, dials, gear gems; electric light sources only, no smoke | `assets/CREDITS.md` updated for every file |
| P5-S43-02 | `content/z10-voice` | Narration generated for all Zone 10 lines and Word Gems (`generate.py --changed`, after `--dry-run` and Spiro's OK) | 100% coverage report from the voice tool |
| P5-S43-03 | `fix/z10-polish` | Feedback polish: rock crack, cart arrival, lock click; particle and sound on each action | 60 fps on both devices with the profiler |
| P5-S43-04 | `chore/z10-release` | Version code bump, changelog, regression suite, internal testing build, then production rollout | Build installed from Play on both devices; math reviewer sign-off on Zone 10 |

**Implementation notes for the agent**

- Audio files are OGG, loudness-normalized by the pipeline; never hand-edit `narration/audio/`.
- Content update notes go in `docs/changelog.md` and the Play Console release notes (short, parent-facing).
- Keep this sprint small; it is 4 days. Anything that slips goes to the backlog, not into Sprint 44.

**Tests**

- Full regression: GdUnit4, pytest, cross-check `--all`, lint, posture matrix, save-upgrade from the 1.5 fixture.
- Narration coverage check fails CI if any `z10.` line lacks audio.

**Playtest focus.** Friday build on both of Charlie's devices. Charlie may try the circular track for fun even though it is ahead of his frontier; log whether the picture alone makes sense to him.

### Sprint 44 (Sep 13–17): Zone 11 curriculum and cipher generators

**Goal.** Zone 11 skill graph plus Caesar, affine and modular-inverse generators, all cross-checked.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S44-01 | `content/z11-skill-graph` | `curriculum/skills/z11_cipher_vault.json` with the 15 skills above | DAG test passes; reviewer has the file |
| P5-S44-02 | `feat/z11-cipher-generator` | `CipherGenerator` with the shared pure helpers | Seeded tests; 10,000-run; cross-check |
| P5-S44-03 | `feat/z11-modinv-generator` | `ModInverseGenerator.exists`, `.find_small` | As above; `exists` matches `gcd(a, n) == 1` in the checker |
| P5-S44-04 | `feat/z11-euclid-generator` | `EuclidGenerator` including `extended_gcd` and `steps` | As above; `a*x + b*y == gcd` asserted for all 10,000 |
| P5-S44-05 | `test/crosscheck-z11-a` | `tools/crosscheck/z11_cipher.py`, `z11_modinv.py`, `z11_euclid.py` | pytest passes |
| P5-S44-06 | `content/z11-words` | Kid word list for `caesar_crack` in `curriculum/wordlists/cipher_words.json` (first-grade-safe words, screened against banned content keywords) | Lint passes on the word list |
| P5-S44-07 | `content/z11-lines` | Zone 11 lines and 9 Word Gems | Lint and reading-level check |

**Implementation notes for the agent**

- Letters map A=0 … Z=25. Encode as `(x + k) mod 26`; affine as `(a*x + b) mod 26` with `gcd(a, 26) = 1`. The affine decode uses `a⁻¹ (y − b) mod 26`; compute `a⁻¹` by brute force over 1..25 in the generator (tiny, clear), and by `pow(a, -1, 26)` in the Python checker (independent method).
- `caesar_crack` offers a short ciphertext and three candidate shifts; only one yields a real word from the word list. The generator must verify the two wrong shifts do not also produce a listed word.
- `extended_gcd` must be iterative, not recursive, to keep stack depth trivial on low-end devices.
- Distractors for `euclid.extended.coeffs`: `swapped_coeffs` is `[y, x]`, `sign_flip` is `[−x, −y]`; both must be checked to fail the `a*x + b*y == gcd` identity before being offered (if `a == b`, swapped equals correct, so skip that distractor).

**Tests**

- Round trip: `caesar_decode(caesar_encode(t, k), k) == t` for all k and 1,000 random texts.
- Affine with every valid `a` (12 values) round-trips.
- `extended_gcd` identity holds; `steps` ends with remainder 0.
- Cross-check recomputes ciphers with Python string ops and `pow(a, -1, 26)`.

**Playtest focus.** Spiro checks 20 `caesar_crack` problems for word list quality. A tester-family child aged 10+ can try the paper cipher wheel if available.

### Sprint 45 (Sep 20–24): Zone 11 mechanics, Diophantine coins, toy RSA, secret message

**Goal.** Every Zone 11 door is playable, and the secret-message feature works with no data leaving the device.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S45-01 | `feat/z11-cipher-wheel` | `cipher_wheel.tscn`: two rings, drag to shift, affine multiplier dial | Works with finger, pen, mouse |
| P5-S45-02 | `feat/z11-euclid-machine` | `euclid_machine.tscn`: animated bars for basic algorithm; ladder view for extended | One step per tap; replay button |
| P5-S45-03 | `feat/z11-diophantine-generator` | `DiophantineGenerator.coin_puzzle`, `.solvable` plus `tools/crosscheck/z11_diophantine.py` | Seeded tests; 10,000-run; cross-check |
| P5-S45-04 | `feat/z11-coin-puzzle` | `coin_puzzle.tscn`: drag coins into tray; counts update | Drop targets ≥ 64 dp |
| P5-S45-05 | `feat/z11-rsa-generator` | `RsaGenerator.keygen`, `.encrypt`, `.decrypt`, `pow_mod`; `tools/crosscheck/z11_rsa.py` | Cross-check uses `pow(m, e, n)` |
| P5-S45-06 | `feat/z11-rsa-door` | `rsa_door.tscn`: step-by-step key building using the Euclid machine | Decrypt(Encrypt(m)) == m shown on screen |
| P5-S45-07 | `feat/z11-letter-pad` | `scenes/input/letter_pad.tscn`: A–Z and space, no `LineEdit` | Lint rule passes; 64 dp keys |
| P5-S45-08 | `feat/z11-secret-message` | `secret_message.tscn` per the design above; counter in `Rewards` | No persistence of text; lint rule for clipboard/shell calls passes |
| P5-S45-09 | `feat/z11-zone-integration` | Hub entry, mine loading, hint visuals; "Vault Door" engineering project (affine lock) | Full session on both devices |

**Implementation notes for the agent**

- The secret-message screen is child-facing; its only outputs are pixels on the screen. No `DisplayServer.clipboard_set`, no `OS.shell_open`, no file writes, no `JavaScriptBridge`. Add these to the lint banned list for `scenes/zones/z11_cipher_vault/secret_message*`.
- The `LetterPad` reuses the `NumberPad` script structure (a grid of buttons emitting `key_pressed(ch: String)`), not a copy-paste: extract a shared `KeyPadBase` in `scenes/input/` if the two diverge by less than a screen of code. Explain in the summary: **scene inheritance** lets a scene extend another scene's node tree, which is how `LetterPad` can inherit `NumberPad`'s layout.
- Coin puzzle: `Problem.representation` carries `{a, b, c, allow_negative: false}`; Explorer mode never asks for negative coins. Scholar mode may show the general solution `x = x0 + (b/g)t`.
- Toy RSA stays at p, q ≤ 13 so n ≤ 169 and every number fits on screen as a short multiplication; `pow_mod` with square-and-multiply keeps intermediates under 169².

**Tests**

- Scene loads; input simulations for wheel drag and coin drop.
- `secret_message` test: after creating a message and closing the scene, the save file contains only the incremented counter (assert the text does not appear anywhere in `user://`).
- Diophantine: every generated puzzle is solvable (gcd divides c); `solvable` distractor `ignored_gcd_condition` is a c not divisible by gcd.
- RSA: for all 10 (p, q) pairs and all valid e, round-trip holds for every m < n.

**Playtest focus.** Spiro encodes a message as a "child" and the second adult decodes it on paper; time it. Does the key card give enough to decode without the game? Charlie can play with the cipher wheel (letters are fun even when the math is early).

### Sprint 46 (Sep 27–Oct 1): Zone 11 art, voice, polish, release

**Goal.** Zone 11 ships.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S46-01 | `content/z11-art` | Zone 11 art batch: vault doors, wheel, coins, Euclid bars; electric lighting | Credits updated |
| P5-S46-02 | `content/z11-voice` | Narration for all Zone 11 lines, Word Gems, and the "secret message" Bolt lines | 100% coverage |
| P5-S46-03 | `fix/z11-polish` | Door-opening animation, wheel click sounds, Euclid machine feel | 60 fps on both devices |
| P5-S46-04 | `chore/z11-release` | Regression, version bump, internal then production | Reviewer sign-off on Zone 11 |

**Implementation notes for the agent**

- The cipher wheel letters must use Andika at a size that keeps 26 letters legible on a 10-inch tablet; measure, do not guess.
- Vault door animation: a `Tween` sequence, `tween_property` on rotation then position; never a per-frame script.

**Tests**

- Full regression plus narration coverage.
- Lint rule for the secret-message scene runs in CI.

**Playtest focus.** Friday build. Charlie tries the cipher wheel; log whether letter mapping is intuitive at age 7.

### Sprint 47 (Oct 4–8): Zone 12 Mathematician's Journal and proof builder

**Goal.** The proof-builder framework (data model, validator, scene) exists with one small practice proof.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S47-01 | `content/z12-skill-graph` | `curriculum/skills/z12_infinite_core.json` with the 11 skills | DAG test passes |
| P5-S47-02 | `feat/z12-proof-model` | `Proof`, `ProofStep`, `ProofDecoy`, `ProofResult` resource classes in `scripts/core/`; `ProofLoader` from JSON with `schema_version` | Loads every file in `curriculum/proofs/` |
| P5-S47-03 | `feat/z12-proof-validator` | `ProofValidator.validate`, `.next_valid_tiles` | Unit tests for partial and strict order, decoys, justifications |
| P5-S47-04 | `feat/z12-proof-generator` | `ProofGenerator.identify_parts`, `.order_chain`, `.pick_justification`, `.spot_contradiction` plus `tools/crosscheck/z12_proof.py` (checks the generated chain is a valid topological order) | Seeded tests; cross-check |
| P5-S47-05 | `feat/z12-proof-builder-scene` | `proof_builder.tscn`, `proof_tile.tscn`: drag tiles into slots, justification chips, hint ladder with scaffold levels | Works with finger, pen, mouse; tiles ≥ 64 dp |
| P5-S47-06 | `feat/z12-journal` | `journal.tscn` hub for Zone 12 | Navigates to proof builder, number sets, mysteries (stubs) |
| P5-S47-07 | `content/z12-practice-proof` | `curriculum/proofs/practice_even_plus_even.json` (3 steps: even + even is even) with lines | Completable end to end |

**Implementation notes for the agent**

- The validator is pure and returns errors by slot; the scene turns each into a Bolt line by `misconception` or error kind. No "Wrong!" wording; use the configured feedback line.
- Drag-and-drop uses `InputRouter`'s drag stream, not Godot's built-in `_get_drag_data` (which behaves differently for touch and mouse). This keeps finger, pen and mouse identical, as CLAUDE.md requires.
- Slot layout: a `VBoxContainer` of slots on the left two-thirds, a `ScrollContainer` tray on the right. Test 4:3.
- A placed decoy slides back with a tween; no gem loss, no streak change.

**Tests**

- Validator: table-driven tests with every error kind; partial order accepts all topological orders of the Euclid fixture; strict order rejects a swap.
- Loader rejects unknown `schema_version` and duplicate step IDs.
- Scene test: place tiles programmatically, assert completion signal `proof_completed(proof_id: StringName, hints_used: int)`.

**Playtest focus.** Spiro completes the practice proof with touch only, then mouse only. Is the "why?" chip step clear without reading a paragraph?

### Sprint 48 (Oct 11–15): Guided proofs and number sets

**Goal.** Euclid's infinitely many primes and √2 irrational are playable as guided proofs; the number-sets room works.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S48-01 | `content/z12-euclid-proof` | `curriculum/proofs/euclid_infinite_primes.json` (5–7 steps, 2–3 decoys) with lines | Completable; validator fixture test |
| P5-S48-02 | `content/z12-sqrt2-proof` | `curriculum/proofs/sqrt2_irrational.json` (strict order) with lines | As above |
| P5-S48-03 | `feat/z12-number-sets-generator` | `NumberSetsGenerator.classify` (integers, rationals, reals, with √2, √4, 0.75, 1/3, −3 style items) plus `tools/crosscheck/z12_sets.py` | Seeded tests; cross-check with Python `fractions` and perfect-square test |
| P5-S48-04 | `feat/z12-number-sets-room` | `number_sets.tscn`: nested rings, drag numbers to smallest ring | 64 dp drops; works on 4:3 |
| P5-S48-05 | `content/z12-lines-a` | All proof lines, contradiction explanation, set names as Word Gems (`integer`, `rational`, `irrational`, `real`, `proof`, `contradiction`, `assume`) | Lint and reading check |
| P5-S48-06 | `feat/z12-proof-rewards` | Completing a proof without hints drops a "Core Crystal"; with hints, a standard gem | Deterministic |

**Implementation notes for the agent**

- Euclid step text, one idea per line, for example: "Pretend there are only a few primes." / "Multiply them all together." / "Add 1. Call it N." / "N is not divisible by any prime on the list." / "So N has a new prime factor." / "That is a contradiction. There are infinitely many primes." Decoys: "N is prime" (misconception `n_plus_one_is_prime`), "There are infinitely many primes, so…" (`assumes_conclusion`).
- √2 proof uses the even-square argument; the practice proof from Sprint 47 ("even + even is even") is a prerequisite line of reasoning, and the step "if n² is even then n is even" is a tile with justification `lemma.even_square`.
- Number items are rendered by `MathLabel` (Scholar notation) with a plain-words fallback in Explorer mode ("the square root of 2").
- `NumberSetsGenerator` must never generate an item whose classification is ambiguous for a child (no repeating decimals shown as decimals; show 1/3 as a fraction).

**Tests**

- Each proof JSON has a GdUnit4 fixture test that walks the canonical order and asserts completion, then walks every decoy and asserts the right error kind.
- Number sets: √4 classifies as integer; 0.75 as rational; √2 as real-only.

**Playtest focus.** Second adult (not Spiro) assembles the Euclid proof cold. Count hints needed. Charlie can play the number-sets room with integers only.

### Sprint 49 (Oct 18–22): Unsolved Mysteries, Zone 12 art, voice, polish, release

**Goal.** Zone 12 ships, completing the mountain.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S49-01 | `feat/z12-mystery-generator` | `MysteryGenerator.goldbach_pair`, `.next_twin` plus `tools/crosscheck/z12_mystery.py` | Seeded; cross-check with Python sieve |
| P5-S49-02 | `feat/z12-mysteries-room` | `mysteries.tscn`: display cases, interactive puzzles, "nobody has proven this" lines | Works on both devices |
| P5-S49-03 | `content/z12-art` | Zone 12 art: glowing core, journal, crystals (electric glow, no fire) | Credits updated |
| P5-S49-04 | `content/z12-voice` | Narration for all Zone 12 lines including proof steps | 100% coverage |
| P5-S49-05 | `fix/z12-polish` | Tile snap feel, page-turn animation, Core Crystal celebration | 60 fps |
| P5-S49-06 | `chore/z12-release` | Regression, bump, internal then production (content update "The Infinite Core") | Reviewer sign-off on Zone 12 math and proof wording |

**Implementation notes for the agent**

- Goldbach puzzle accepts any valid pair; the generator stores all valid pairs for n ≤ 100 in the `Problem` (precomputed by a sieve in the generator), and the evaluator checks membership.
- The twin-prime puzzle caps at p < 200 and shows the pair on a number line.
- Mystery-room lines say clearly: "People have checked this for huge numbers. No one has proven it for every number. That is why it is a mystery." One sentence per line.

**Tests**

- Goldbach: every even n in [4, 100] has at least one pair; evaluator accepts each.
- Twin: `next_twin(p)` matches a Python reference list.
- Full regression and narration coverage.

**Playtest focus.** Friday build on both devices. Charlie visits the Unsolved Mysteries room and tries Goldbach with the sieve picture; log the reaction to "nobody knows."

### Sprint 50 (Oct 25–29): Scholar mode complete, badges, Master Miner ranks

**Goal.** Scholar mode meets the completion table; all badges exist; ranks show on hub and dashboard.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S50-01 | `feat/scholar-math-label` | `MathLabel` control: superscripts, fractions, `≡`, `(mod n)`, `√`, set symbols; font fallback confirmed | Renders every Zone 1–12 notation sample in a test scene |
| P5-S50-02 | `feat/scholar-notation-levels` | `notation_level` per skill in all `curriculum/skills/*.json`; renderer picks words or symbols | Explorer profiles see no symbols beyond `+ − × ÷ =` |
| P5-S50-03 | `feat/scholar-keyboard-everywhere` | Keyboard entry for every number-answer problem in Zones 1–12 through `InputRouter`; `NumberPad` remains | Keyboard-only run of every screen passes |
| P5-S50-04 | `feat/scholar-glossary` | `scholar_definition_line_id` on every Word Gem; glossary shows both definitions in Scholar mode | Lint: every term has both lines |
| P5-S50-05 | `content/badges-remaining` | Fermat, Ramanujan, Noether and Euclid's Proof in `curriculum/badges.json`; 30-second stories; voice generated | Unlock rules tested with simulated learners |
| P5-S50-06 | `feat/master-miner-ranks` | `Rewards.rank_for(profile)`; hub and parent dashboard display | Derived, not saved; thresholds in `curriculum/ranks.json` |
| P5-S50-07 | `docs/scholar-decisions` | Record the completion table and the font-fallback choice in `docs/decisions.md` | Entry exists |

**Implementation notes for the agent**

- `RichTextLabel` BBCode supports `[font_size]` and `[color]`; superscripts can be composed by a smaller font and a vertical offset (confirm whether `[sup]` style tags exist in Godot 4.7's BBCode; if not, use a `HBoxContainer` with a raised `Label`). Verify in the Godot docs before writing.
- Fractions: a `VBoxContainer` with numerator, a `ColorRect` bar sized to the wider label, denominator. Reuse for Zone 7 problems.
- Notation levels are per skill, not per zone: a Zone 2 skill in Scholar mode still shows `+`, nothing fancier.
- Badges reuse the Phase 2 badge scene; add data, not code, where possible.

**Tests**

- `MathLabel` golden test: a scene with every notation sample loads and reports no missing glyph (check `Font.has_char` for each special character; verify the API name in the docs).
- Simulated-learner tests: a fast learner earns every badge within the simulated Zone 10–12 run; a random guesser earns none.
- Rank thresholds: boundary tests at 20/21, 60/61, 100/101, 140/141.

**Playtest focus.** Spiro plays a Scholar-mode session in laptop posture with keyboard only, then tablet with touch only. Charlie plays Explorer mode and must see no new symbols.

### Sprint 51 (Nov 1–5): Web version, full regression, math reviewer final check

**Goal.** A web build runs on GitHub Pages with progress kept across reloads; the whole game passes regression; Zones 10–12 are signed off.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S51-01 | `chore/web-export-preset` | "Web" preset in `export_presets.cfg` (threads off, per the design; **ask Spiro before committing**) | `--export-release "Web" build/web/index.html` succeeds headless in CI |
| P5-S51-02 | `chore/web-pages-deploy` | GitHub Actions job publishes `build/web/` to `gh-pages` on tags; landing page notes the game makes no network calls after load | Page loads in Chrome on a Chromebook |
| P5-S51-03 | `fix/web-saves` | Verify `SaveSystem` on IndexedDB: reload keeps progress; close-request behaviour documented | Test plan executed and recorded |
| P5-S51-04 | `fix/web-handwriting-fallback` | Explicit test that web falls back to `NumberPad` | Automated where possible; manual otherwise |
| P5-S51-05 | `fix/web-audio-gate` | Narration starts after "Tap to start" | Manual check in Chrome |
| P5-S51-06 | `chore/web-size-budget` | Measure web download; if over 150 MB, apply the narration trimming rule from the design and document it | Number recorded in `docs/decisions.md` |
| P5-S51-07 | `test/full-regression-v2` | Full matrix (see Testing and quality) on Android arm64, x86_64 emulator, 2-in-1 postures, tablet, mouse-only, web | Results table in `docs/releases/v2.0-regression.md` |
| P5-S51-08 | `docs/reviewer-z10-12` | Package Zones 10–12 for the math reviewer: sample problems, proofs, vocabulary; collect sign-off | Sign-off noted in `docs/decisions.md` |
| P5-S51-09 | `docs/privacy-web-note` | `docs/privacy-policy.md` web section | Published on GitHub Pages |

**Implementation notes for the agent**

- Do not change the Android preset while adding the Web preset; diff `export_presets.cfg` before committing and confirm no `INTERNET` permission appears anywhere.
- The Pages workflow uses only `actions/checkout`, the headless Godot download step already in CI, and `actions/upload-pages-artifact` / `deploy-pages`. No third-party deploy actions.
- Web export cannot include the `digit_ink` AAR; the export should exclude `android/` and `addons/digit_ink/bin/` via preset resource filters.
- If the web build exceeds the size budget, the trimming rule is data-driven (a narration manifest per platform), not a code fork.

**Tests**

- CI: web export job runs on every merge to `main` (export only; deploy on tags).
- Smoke test: a Playwright script in `tools/ci/web_smoke.py` is **not** added without Spiro's approval (new dependency). Default: manual smoke test checklist in `docs/build-and-release.md`.
- Regression matrix executed and recorded.

**Playtest focus.** Charlie plays the web version on the 2-in-1 in Chrome for 15 minutes; log load time, audio start, and any touch issue. A tester family with a school Chromebook tries the link.

### Sprint 52 (Nov 8–12): Version 2.0 release and documentation

**Goal.** Version 2.0 is on Google Play and the web, and the three guides are complete.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P5-S52-01 | `fix/v2-hardening` | Bug bash results from Sprint 51; performance pass; save-migration test from every fixture to 2.0 | Zero known crashes; profiler 60 fps |
| P5-S52-02 | `docs/build-and-release` | `docs/build-and-release.md` per outline | A clean machine follows it to a debug APK |
| P5-S52-03 | `docs/how-to-add-a-zone` | `docs/how-to-add-a-zone.md` per outline | An agent given only this doc produces a stub Zone 13 branch that passes CI (then delete the branch) |
| P5-S52-04 | `docs/curriculum-data-guide` | `docs/curriculum-data-guide.md` per outline | Math reviewer reads it and can sample a generator without help |
| P5-S52-05 | `docs/maintenance-runbook` | Maintenance section in `build-and-release.md`; `CLAUDE.md` "Current phase" updated to Maintenance | Done |
| P5-S52-06 | `chore/v2-release` | Version 2.0: Android production rollout, web tag deploy, release notes, store listing update (12 zones), screenshots refresh | Live on both channels |
| P5-S52-07 | `docs/sdk-audit-v2` | `docs/sdk-audit.md` reconfirmed: no new SDKs since Phase 3; data safety form unchanged | Entry dated |

**Implementation notes for the agent**

- The "stub Zone 13" exercise in P5-S52-03 is a documentation test only; the branch is deleted afterwards and nothing from it merges. Make that explicit in the doc so a future agent does not ship it.
- Release notes are parent-facing and short; no model names or tool names in any committed text.
- Update the README's zone table to show all 12 zones released.

**Tests**

- Everything in the Testing and quality section, one final time on the release candidate.
- Save migration: load every fixture in `tests/save/fixtures/` (MVP through 1.5) into 2.0.

**Playtest focus.** Charlie plays a full session on his own on each device, plus the web build. Second adult observes one session. Log goes into the maintenance backlog.

---

## Testing and quality

### Generators and cross-checks

- Every new generator has a GdUnit4 suite in `tests/generators/` with fixed seeds, edge cases, and a 10,000-problem run asserting: answer within the skill's range, distractors never equal the answer, no duplicate distractors, params respected.
- Every generator has a separate Python checker in `tools/crosscheck/` that recomputes answers from the exported problem JSON using **exact integer arithmetic**: Python `%`, `pow(a, -1, n)`, `pow(m, e, n)`, `math.gcd`, `fractions.Fraction`, `math.isqrt`. No floats anywhere in modular, cipher or RSA checks. The checker and the generator share no code and use different algorithms where one exists (brute-force inverse vs. `pow`; `posmod` vs. `%`; iterative extended Euclid vs. recursive in Python).
- Run `python tools/crosscheck/run.py --all --n 10000` before every release sprint and for any touched generator before calling a task done.

### Proof validator

- Table-driven unit tests for every error kind, partial vs. strict ordering, decoy handling, and `next_valid_tiles`.
- A fixture test per proof JSON: canonical walk completes; each decoy produces its configured error; every non-canonical topological order completes for partial proofs.
- A schema test: every file in `curriculum/proofs/` has unique step IDs, `depends_on` references existing steps, and `justification` values appear in the file's `justifications` list.

### Adaptive engine

- Simulated learners (fast, average, slow, random guesser, forgetter) run through Zones 10–12 skill graphs. A random guesser never masters anything; a fast learner can test out via the Challenge Door; badge unlock rules fire only for mastered skills.
- No change to BKT defaults or thresholds in this phase without Spiro's sign-off.

### Web build

- CI job: headless `--export-release "Web"` on every merge to `main`; artifact size reported; fails if over budget.
- Manual smoke checklist (until a browser automation dependency is approved): page loads, "Tap to start" enables audio, a Zone 1 rock completes, reload keeps progress, `NumberPad` appears where the slate would, keyboard entry works in Scholar mode, no network requests after load (checked in Chrome DevTools).

### Full regression matrix (Sprint 51 and 52)

| Platform | Input | Checks |
|---|---|---|
| Android arm64 on the 2-in-1, laptop posture | trackpad, keyboard | every screen; Scholar keyboard entry |
| Android arm64 on the 2-in-1, tent posture | touch | every screen |
| Android arm64 on the 2-in-1, tablet posture | touch, stylus | every screen; `ChalkSlate`; palm rejection; posture switch mid-dig keeps state |
| Android arm64 tablet | touch (stylus if available) | every screen; airplane-mode full session |
| Android x86_64 emulator (Chromebook profile) | mouse only | every screen with click and drag; `NumberPad` instead of slate |
| Android emulator, small/old tablet profile | touch | layout at 4:3 and 16:10; performance floor |
| Web (Chrome on the 2-in-1) | touch and mouse | smoke checklist above |
| All | saves | close mid-dig, posture change, device restart, install 2.0 over 1.5, every fixture migration |
| All | content | `lint_content.py` clean; narration coverage 100% for Zones 1–12 (or the documented web trimming) |

### Narration coverage

- The voice tool's coverage report must list zero lines without audio for every `z10.`, `z11.`, `z12.` and `badge.` ID before each content release.
- Number clips 0–1,000 already exist; Zone 11 needs no new numbers. Zone 12 needs no numbers above 200.

---

## Exit criteria

Phase 5 is done, and Version 2.0 is released, when all of these hold:

1. Zones 10, 11 and 12 are live on Google Play as content updates, and the Version 2.0 build is in production.
2. The web build is published on GitHub Pages, loads on a school-managed Chromebook in Chrome, keeps progress across reloads, and makes no network requests after load.
3. Every Zone 10–12 generator passes its GdUnit4 suite and Python cross-check at 10,000 problems; every proof fixture test passes.
4. Scholar mode meets every row of the completion table; Explorer-mode profiles show no notation beyond `+ − × ÷ =`.
5. All mathematician badges and Master Miner ranks exist and unlock deterministically.
6. Narration coverage is 100% for all child-facing lines on Android.
7. The math reviewer has signed off Zones 10–12 and the proof wording.
8. The full regression matrix is executed and recorded in `docs/releases/v2.0-regression.md`, with zero known crashes.
9. Saves from every prior version migrate to 2.0.
10. `docs/build-and-release.md`, `docs/how-to-add-a-zone.md` and `docs/curriculum-data-guide.md` exist and have each been exercised by someone other than the author (or by an agent with only the doc as context).
11. `docs/sdk-audit.md` confirms no new SDK, plugin or permission since the Phase 3 compliance review; the Android export still requests no `INTERNET` permission.
12. `CLAUDE.md` "Current phase" reads Maintenance.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Zone 10–12 math is years ahead of Charlie, so playtests give little signal | High | Medium | Use Spiro and a second adult for cold walkthroughs; recruit one tester family with a 10–12-year-old; rely on simulated learners and the math reviewer for correctness; keep the Zone 1–5 playtests running for fun and regression |
| Proof builder feels like a quiz, not discovery | Medium | High | Practice proof first (Sprint 47); decoys with gentle feedback; scaffold levels; second adult cold test in Sprint 48 before art |
| Secret-message feature drifts toward sharing or storage | Low | High (compliance) | Lint rule on the scene; test that no text is persisted; no share, clipboard or file actions; design reviewed against CLAUDE.md rules 1–2 |
| Web export size exceeds 150 MB with 12 zones of narration | Medium | Medium | Measure early in Sprint 51; data-driven narration manifest per platform; landing-page note |
| Web threading headers block GitHub Pages hosting | Medium | Medium | Single-threaded export option by default; decision logged; no third-party service-worker code without approval |
| Font lacks glyphs for ℤ ℚ ℝ or `≡` | Medium | Low | Check `has_char` in Sprint 50; add a licensed fallback font with a credits entry |
| Scholar-mode symbols leak into Explorer profiles | Low | Medium | Per-skill `notation_level`; lint rule that Explorer snapshots contain no banned glyphs; playtest with Charlie |
| The 4-day Sprint 43 (and any holiday that shifts onto a release sprint) compresses release work | Medium | Medium | Release sprints carry no new features; slipping items go to the backlog |
| Solo-developer fatigue at the end of a 52-sprint year | Medium | High | Sprint 52 is docs and release only; maintenance mode is 2–4 days a month; nothing provisional is committed before the Phase 4 review |
| Negative-remainder convention confuses children (`−3 mod 7`) | Medium | Low | Only `mod.track.backward` touches it, in concrete representation (the cart goes backward on a loop); canonical remainder is always 0..n−1 |

---

## Decisions for Spiro

1. **Confirm Phase 5 at the Phase 4 review (Aug 20, 2027).** Recommendation: proceed if Version 1.5 shipped on time and the three-sprint zone pattern held for Zones 6–9; otherwise drop the web version (Sprint 51) first, then the Unsolved Mysteries room, before touching proofs.
2. **Web export threading.** Recommendation: single-threaded export so GitHub Pages can host it with no extra code. Needs your approval because it changes export settings.
3. **Web narration trimming rule** if the build exceeds 150 MB. Recommendation: full narration for Zones 1–5 on web, text elsewhere, stated on the landing page.
4. **Fallback font** for set symbols if Andika lacks them. Recommendation: approve one Open Font License font; it is an asset, not an SDK, but it is still a dependency and needs an `assets/CREDITS.md` entry.
5. **Secret-message input.** Recommendation: a `LetterPad` child-safe keyboard (A–Z and space, 40-character cap). Confirm you are comfortable with free-text letters on a child screen; the alternative is a word-list-only picker.
6. **Toy RSA depth.** Recommendation: p, q ≤ 13 and no mention of "security" claims beyond "this is the idea behind real codes." Confirm with the math reviewer.
7. **Voice generation runs** for Zones 10–12 and badge stories: three paid batches (Sprints 43, 46, 49) plus one for badges (Sprint 50). Approve each run after `--dry-run`.
8. **Browser automation for web smoke tests** (Playwright). Recommendation: not now; manual checklist. Revisit in maintenance if web use grows.
9. **Documentation test for `how-to-add-a-zone.md`** (an agent builds and then deletes a stub Zone 13). Recommendation: do it; it is the cheapest way to prove the guide works.
10. **Maintenance cadence** and who covers it when you are away. Recommendation: one fixed day per month plus the August update week.

---

## After Phase 5

Maintenance mode, about **2–4 days per month**, starting Sprint 53 (week of November 15, 2027). Charlie will be about 7; the game holds content through about age 12, and he grows into it at his own pace.

**Monthly (1 day).**

- Pull the latest exported play logs from the parent area (Spiro's own devices only; `private/` is gitignored and never uploaded).
- Run `python tools/bkt/fit.py` offline; compare fitted parameters with `curriculum/bkt_defaults.json`. Propose changes in `docs/decisions.md`; apply only with sign-off and with the simulated-learner suite passing.
- Triage Google Play reviews and tester-family feedback into the backlog. Reply to reviews in a warm, short tone; never promise features.
- Run the full test suite and `lint_content.py` on `main`; fix anything red.

**Quarterly (1–2 days).**

- Godot patch-release check: read the release notes for 4.7.x; upgrade only on purpose, after a branch build passes the full regression matrix; update `.godot-version`; ask Spiro before upgrading.
- Re-run the Families Policy self-check against `docs/sdk-audit.md` and the live export preset (no `INTERNET`, no new permissions).
- Refresh save-migration fixtures if any release changed the schema.

**Yearly, each August (one week).**

- Raise the Android target API level to the new Google Play requirement; follow `docs/build-and-release.md` section 7.
- Full regression matrix, then release.
- Review Google Play Console policy changes for children's apps.

**On demand.**

- Bug fixes from playtests, released as patch versions.
- Optional new gems, Deep Dig challenges or deeper problems, each following `docs/how-to-add-a-zone.md` sections 3–4 even when no new zone is involved.
- If a new zone or topic is ever added, it is a new phase with its own plan document, not a maintenance task.
