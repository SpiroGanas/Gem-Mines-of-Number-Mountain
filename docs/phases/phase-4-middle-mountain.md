# Phase 4: Middle Mountain (Sprints 29–40)

> **Changed 2026-10-19 (Spiro):** no narration and no AI voice. Sprint 22 (voice pipeline, `Narration` autoload), the read-aloud setting, narration coverage and the AI-voice listing note are dropped; the children this game is for read. Phones are supported (no phone exclusion). See `docs/decisions.md`, 2026-10-19.

This document is the implementation plan for Phase 4 of *Gem Mines of Number Mountain*. It expands section 8.5 of the master plan (`docs/development-plan.md`) into enough detail that an experienced engineer, working with an AI coding agent, can build the phase. It assumes the conventions in `CLAUDE.md` (repository layout, Godot 4 syntax only, non-negotiable rules, content rules). The previous phase is `docs/phases/phase-3-public-release-readiness.md`; the next is `docs/phases/phase-5-deep-mountain.md`.

Status: **provisional**. Phase 4 runs only if the game is live on Google Play after Phase 3 and Spiro confirms the roadmap.

---

## Overview

| Item | Value |
|---|---|
| Phase | 4: Middle mountain |
| Sprints | 29–40 (12 one-week sprints, three of them 4-day holiday weeks: 29, 31 and 34) |
| Dates | May 31 – Aug 20, 2027 |
| Status | Provisional (confirmed at the Feb 19, 2027 decision gate and again after public launch) |
| Milestone | **Version 1.5**: Zones 6–9 live on Google Play as free content updates, Scholar mode part 1, yearly platform update done |
| Entry gate | Public Version 1.0 approved and live on Google Play (end of Phase 3) |
| Charlie's rough age band for this content | 8–11 (the adaptive engine, not the calendar, decides when he enters) |

**Outcome.** Four new zones ship, each as its own public content update: **Zone 6 Gear Works** (greatest common factor, least common multiple, simplest form, gear trains), **Zone 7 Crystal Shards** (fractions, decimals, percents, ratio, negative numbers), **Zone 8 Power Tower** (exponents, roots, powers of 2 and 10, binary and other bases, scientific notation) and **Zone 9 Pattern Grotto** (sequences, figurate numbers, Fibonacci, the golden ratio, Gauss's sum, proof without words, Fib poems). Alongside the zones, **Scholar mode part 1** adds keyboard entry and real on-screen notation, and **Sprint 38** performs the yearly Google Play target-API update. Every zone follows the same three-sprint pattern so the agent's work becomes repeatable.

**Out of scope for Phase 4** (goes to Phase 5 or the backlog):

- Zones 10–12 (modular arithmetic, ciphers, proof).
- Scholar mode part 2 (full notation set, reduced narration, Master Miner ranks).
- The web export.
- Remaining mathematician badges beyond the four from Phase 2 plus the ones listed per zone below.
- Any new SDK, plugin or dependency (ask Spiro first; see `CLAUDE.md`).
- Changes to BKT thresholds, save schema or existing curriculum prerequisites without Spiro's sign-off.

---

## Entry criteria

Phase 4 starts only when all of these are true. If one is missing, the first sprint absorbs it.

| # | Criterion | Where it comes from | How to verify |
|---|---|---|---|
| 1 | Public Version 1.0 is live on Google Play with the Families Policy review passed | Phase 3, Sprint 28 | Play Console shows the production release; `docs/sdk-audit.md` matches the shipped build |
| 2 | Narration pipeline works end to end: `tools/voice/generate.py --dry-run` lists zero missing lines for Zones 1–5 and numbers 0–1,000 | Phase 3, Sprint 22 | Run the dry run; confirm `narration/audio/` is committed and `text/lines.csv` `voice_version` columns are populated |
| 3 | `Narration` autoload splices number clips and emits `word_spoken(index)`; the read-aloud setting is per profile | Phase 3, Sprint 22–23 | GdUnit4 suites in `tests/autoload/test_narration.gd` pass |
| 4 | Profiles (up to 4) with per-profile BKT state and rewards; save `schema_version` for profiles is migrated and tested | Phase 3, Sprint 23 | `tests/save/` fixtures for every prior version load |
| 5 | A written **release checklist** exists at `docs/release-checklist.md` (build, sign, upload, staged rollout, listing update) | Phase 3, Sprint 28 | File exists and was used for the 1.0 launch |
| 6 | Handwriting (`ChalkSlate` + `addons/digit_ink`) recognizes one digit per box with confirmation on low confidence; `FakeRecognizer` works in the editor | Phase 2, Sprint 14 | `tests/scenes/input/test_chalk_slate.gd` passes |
| 7 | Mouse-only and keyboard-only passes exist in the Friday device matrix | Phase 3, Sprint 25 | `docs/release-checklist.md` lists them |
| 8 | Math reviewer has signed off on Zones 1–5 | Phase 2, Sprint 21 | Entry in `docs/decisions.md` |
| 9 | Charlie's placement, by the engine, has reached the Zone 5 frontier or is close to it | Play logs | Parent dashboard; if he is far from it, Phase 4 still proceeds (content is built ahead of him) |

---

## Architecture and design

### The three-sprint zone pattern

Every zone in Phase 4 (and Phase 5) is built in three sprints. Treat this as a checklist and copy it into each zone's GitHub Project cards.

**Sprint A: curriculum and generators**

1. Write `curriculum/skills/zNN_<name>.json`: every skill with `id`, `prereqs`, `generator`, `params`, `representations`, `terms`, `answer_modes`. Prerequisites must keep the graph acyclic (`tests/curriculum/test_skill_graph.gd` enforces this).
2. Add vocabulary entries to `curriculum/vocabulary.json` (each new math term becomes a Word Gem).
3. For each generator in `scripts/generators/<family>.gd`: write the GdUnit4 test first (`tests/generators/test_<family>.gd`, fixed seeds, edge cases, "distractors never equal the answer, never duplicate"), then the generator.
4. Write the independent Python checker in `tools/crosscheck/<family>.py`. It reads exported problem JSON and recomputes the answer with its own arithmetic. It must not import or copy generator logic.
5. Add all child-facing lines for the zone to `text/lines.csv` with IDs `zNN.<context>.<purpose>`. Leave `voice_version` blank; the voice batch fills it in Sprint C.
6. Run `python tools/crosscheck/run.py --skill <family> --n 10000` and `python tools/ci/lint_content.py`.
7. Send the zone's skill list and 30 sample problems per skill (exported JSON rendered to a readable Markdown table by `tools/crosscheck/export_samples.py`) to the math reviewer. Record the sign-off in `docs/decisions.md`.

**Sprint B: mechanic and engineering project**

1. Build the zone's dig mechanic as a scene under `scenes/zones/zNN_<name>/` that reuses `scenes/mine/` (rock wall, rock, cart, Bolt). Zone scenes handle presentation only; logic lives in `scripts/`.
2. Build the zone's engineering project under `scenes/workshop/builds/<project>/`, using the build-screen framework from Phase 2 Sprint 16.
3. Wire any new answer mode into `InputRouter` and the `Problem.answer_modes` list; add the fallback for mouse-only devices.
4. Gray-box only: Kenney CC0 placeholder shapes. No art spend yet.
5. Weekend playtest with Charlie focused on "is the new mechanic fun and understandable?".

**Sprint C: art, voice batch, polish, release**

1. Art pass for the zone (contract artist batch, briefed in Sprint A so the batch arrives in time). Every asset gets a `assets/CREDITS.md` entry.
2. **Voice batch:** `python tools/voice/generate.py --dry-run` to list new lines; **ask Spiro before running the paid generation**; then `--changed`. Commit `narration/audio/` output. Confirm 100% narration coverage with `tools/voice/coverage.py --zone NN`.
3. Polish: squash-and-stretch on new objects, particles on reveals, a sound on every action, celebration on zone completion.
4. Full regression: all GdUnit4 suites, all cross-checks, lint, posture and input matrix on both of Charlie's devices.
5. Release as a content update using `docs/release-checklist.md`:
   - Bump `version/name` and `version/code` in `export_presets.cfg` (no secrets committed).
   - Save migration if the schema changed (should be rare; ask Spiro first).
   - Build the AAB: `"$GODOT" --headless --path . --export-release "Android" build/gem-mines.aab`.
   - Internal testing track first; install on both of Charlie's devices; one full session.
   - Update the store listing: "What's new" text, one new screenshot for the zone.
   - Production with a **staged rollout** (start at 20%, raise to 100% after 48 hours with no new crashes in the Play Console vitals; vitals are Google's own, not an SDK we add).
   - Tag the release in git: `v1.1.0-zone6`, `v1.2.0-zone7`, `v1.3.0-zone8`, `v1.5.0-zone9`.
6. Backlog triage: anything cut from the zone goes to the GitHub Project backlog, not into the next zone's sprints.

### Shared data representation for Phase 4 problems

Phase 4 introduces non-integer answers for the first time. Keep `Problem.answer` canonical and exact:

| Math object | Canonical `answer` value | Display | Notes |
|---|---|---|---|
| Integer | `int` | `Text` placeholder `{n}` | Unchanged from Phases 1–3 |
| Fraction | `Dictionary[String, int]` `{"num": 3, "den": 4}` in **lowest terms with positive denominator** | New `Fraction` display scene | Never use `float`. Equality is `a.num * b.den == b.num * a.den` after normalization |
| Decimal | `Dictionary[String, int]` `{"mantissa": 275, "scale": 2}` meaning 2.75 | Formatted by `Text.format_decimal()` | Scale is the number of decimal places. Compare as integers after aligning scale |
| Percent | `int` or `{"mantissa", "scale"}` | `{p}%` | Store the number, not the string |
| Ratio | `Dictionary[String, int]` `{"a": 2, "b": 3}` in lowest terms | `2 : 3` | Order matters; the generator states which quantity is first |
| Negative integer | `int` | Depth gauge | Nothing special; the gauge scene handles the sign |
| Exponent form | `Dictionary[String, int]` `{"base": 2, "exp": 5}` | BBCode superscript | Answer is often the *value* (`int`); state which in `params.answer_kind` |
| Number in base b | `Dictionary` `{"base": 2, "digits": [1, 0, 1, 1]}` (most significant first) | Vault lock dials | The child never types a base prefix |
| Scientific notation | `{"mantissa": 34, "scale": 1, "exp": 5}` meaning 3.4 × 10⁵ | Two input boxes | Normalize so `1 <= mantissa / 10^scale < 10` |
| Sequence term | `int` | Pattern tiles | Rule stored in `params`, not in the answer |

Add a small pure-logic helper module `scripts/core/rational.gd` (`class_name Rational`) that delegates `gcd` and `lcm` to the Phase 2 `MathUtil` (`scripts/core/math_util.gd`) rather than duplicating them, and adds `normalize(num: int, den: int) -> Dictionary`, `add`, `sub`, `mul`, `compare` and `to_decimal(num: int, den: int, places: int) -> Dictionary`. Generators use it; the Python cross-checker uses `fractions.Fraction` and `math.gcd` independently.

`Problem.answer_modes` grows two entries in this phase: `"keyboard"` (Scholar mode) and `"handwriting_fraction"` (two-box handwriting). The existing modes are `"tap"`, `"drag"`, `"number_pad"`, `"handwriting"` (Phases 1–2).

### Zone 6: Gear Works (Sprints 29–31)

**Math.** Greatest common factor (GCF), least common multiple (LCM), simplest form, gear ratios. Prerequisites come from Zone 4 (factors, multiples) and Zone 5 (prime factorization).

**Skill list** (`curriculum/skills/z06_gear_works.json`). All IDs are new; prerequisites in Zones 4–5 already exist and are not changed.

| Skill ID | Prereqs | Generator | Key params | Representations | Named distractors |
|---|---|---|---|---|---|
| `gcf.list.common_factors` | `fac.pairs.rectangles`, `fac.list.find_all` | `GcfGenerator.common_factors` | `max_n: 50` | concrete (gear teeth), pictorial (factor lists), abstract | `included_non_factor`, `missed_largest` |
| `gcf.find.by_listing` | `gcf.list.common_factors` | `GcfGenerator.gcf` | `max_n: 60, coprime_rate: 0.2` | pictorial, abstract | `picked_smallest_common`, `picked_lcm`, `picked_prime_factor_only` |
| `gcf.find.by_factor_tree` | `gcf.find.by_listing`, `pf.tree.build` | `GcfGenerator.gcf_from_factorization` | `max_n: 120` | pictorial (two trees), abstract | `multiplied_all_primes`, `took_union` |
| `gcf.coprime.identify` | `gcf.find.by_listing` | `GcfGenerator.coprime` | `max_n: 40` | abstract | `shared_even_only`, `assumed_primes_only` |
| `lcm.list.common_multiples` | `mul.list.first_k` | `LcmGenerator.common_multiples` | `max_n: 12, count: 3` | concrete (gear turns), pictorial | `listed_product_only`, `off_by_one_multiple` |
| `lcm.find.by_listing` | `lcm.list.common_multiples` | `LcmGenerator.lcm` | `max_n: 15` | pictorial, abstract | `picked_product`, `picked_gcf`, `picked_sum` |
| `lcm.find.by_factorization` | `lcm.find.by_listing`, `gcf.find.by_factor_tree` | `LcmGenerator.lcm_from_factorization` | `max_n: 60` | abstract | `took_intersection`, `dropped_highest_power` |
| `lcm.relation.gcf_times_lcm` | `gcf.find.by_listing`, `lcm.find.by_listing` | `LcmGenerator.product_relation` | `max_n: 30` | abstract | `added_instead_of_multiplied` |
| `gear.ratio.teeth` | `lcm.find.by_listing` | `GearGenerator.teeth_ratio` | `teeth: [8, 12, 16, 24, 32]` | concrete (gears), pictorial | `inverted_ratio`, `subtracted_teeth` |
| `gear.sync.turns_to_align` | `gear.ratio.teeth`, `lcm.find.by_listing` | `GearGenerator.turns_to_align` | `teeth: [6..24]` | concrete | `used_gcf`, `used_larger_gear_only` |
| `simplify.fraction.gcf` | `gcf.find.by_listing`, `fraction.unit.identify` (Zone 7 prereq flagged; see decision 3) | `SimplifyGenerator.simplest_form` | `max_den: 48` | pictorial (shaded gears), abstract | `divided_numerator_only`, `partially_simplified`, `swapped_num_den` |
| `simplify.ratio.gcf` | `gear.ratio.teeth`, `gcf.find.by_listing` | `SimplifyGenerator.simplest_ratio` | `max_term: 48` | concrete, abstract | `partially_simplified`, `inverted_ratio` |

**Generators** (`scripts/generators/gcf_lcm.gd`, `scripts/generators/gears.gd`, `scripts/generators/simplify.gd`), all pure:

```gdscript
class_name GcfGenerator
extends RefCounted

## Pure logic. No nodes, no globals, no randi(). Always use the passed-in rng.
static func gcf(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
    var max_n: int = params.get("max_n", 60)
    var coprime_rate: float = params.get("coprime_rate", 0.2)
    # choose a, b in [2, max_n]; force gcd == 1 with probability coprime_rate
    # answer = Rational.gcd(a, b); distractors via _distractors_gcf(a, b, answer)
    ...

static func _distractors_gcf(a: int, b: int, answer: int) -> Array[Distractor]:
    # Distractor is {value, misconception_id}; filter value == answer and duplicates
    ...
```

Every generator function follows the `static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem` contract from `CLAUDE.md`. Where a file holds several related generators (`gcf`, `common_factors`, …), the curriculum JSON `generator` field names them as `"GcfGenerator.gcf"`, and the existing generator registry (`scripts/generators/registry.gd` from Phase 1) resolves `Class.method` strings with `Callable`. Verify in Godot docs that `Callable(object, method_name)` on a `GDScript` class resource works for static methods in 4.7 (`Callable.create` and `GDScript.new()` behaviour); the Phase 1 registry already settled this, so reuse it.

**Mechanic: gear train machine builder** (Sprint 30). `scenes/zones/z06_gear_works/gear_bench.tscn` with `scenes/zones/z06_gear_works/gear.tscn` (a `Node2D` with a `Sprite2D`, teeth count label, and a `rotation` driven by a shared `GearTrain` logic object in `scripts/zones/gear_train.gd`). Charlie drags gears from a tray onto axles. The train "syncs" when the marked teeth on the first and last gear line up again, which happens after `lcm(teeth...) / teeth_first` turns. The build project **Conveyor Sync** (`scenes/workshop/builds/conveyor_sync/`) asks him to pick gears so two conveyors deliver gems at the same time; the answer check is pure logic in `scripts/zones/gear_train.gd` (`static func turns_to_align(teeth: Array[int]) -> int`). Rotation animation uses `create_tween()` chained per gear; do not allocate in `_process`.

Electric motors drive the gears (no steam, no smoke). Gear sound is a soft electric whir.

### Zone 7: Crystal Shards (Sprints 32–34)

**Math.** Fractions (unit fractions, equivalent fractions, comparing, adding with like and unlike denominators), decimals (tenths and hundredths), percents, ratio, negative numbers as depth below the mountain's base.

**Skill list** (`curriculum/skills/z07_crystal_shards.json`):

| Skill ID | Prereqs | Generator | Key params | Representations | Named distractors |
|---|---|---|---|---|---|
| `fraction.unit.identify` | `div.sharing.equal_shares` (Zone 4) | `FractionGenerator.unit_fraction` | `max_den: 12` | concrete (crystal split into shards), pictorial | `counted_shaded_as_denominator`, `inverted` |
| `fraction.part.of_whole` | `fraction.unit.identify` | `FractionGenerator.part_of_whole` | `max_den: 12` | concrete, pictorial, abstract | `inverted`, `unshaded_count`, `off_by_one_numerator` |
| `fraction.number_line.place` | `fraction.part.of_whole` | `FractionGenerator.number_line` | `max_den: 8` | pictorial (number line with tick marks) | `counted_ticks_not_gaps`, `inverted` |
| `fraction.equivalent.build` | `fraction.part.of_whole`, `simplify.fraction.gcf` | `FractionGenerator.equivalent` | `max_den: 24` | pictorial (two crystals), abstract | `added_to_both`, `scaled_numerator_only` |
| `fraction.compare.like_den` | `fraction.part.of_whole` | `FractionGenerator.compare` | `like_den: true, max_den: 12` | pictorial, abstract | `compared_denominators` |
| `fraction.compare.unlike_den` | `fraction.compare.like_den`, `fraction.equivalent.build` | `FractionGenerator.compare` | `like_den: false, max_den: 12` | pictorial, abstract | `bigger_denominator_bigger`, `compared_numerators_only` |
| `fraction.add.like_den` | `fraction.part.of_whole` | `FractionGenerator.add` | `like_den: true, max_den: 12, allow_improper: false` | concrete, pictorial, abstract | `added_denominators`, `forgot_simplify` |
| `fraction.add.unlike_den` | `fraction.add.like_den`, `lcm.find.by_listing` | `FractionGenerator.add` | `like_den: false, max_den: 12` | pictorial, abstract | `added_denominators`, `added_numerators_only`, `used_product_not_lcm_unsimplified` |
| `fraction.mixed.convert` | `fraction.add.like_den` | `FractionGenerator.mixed_number` | `max_whole: 5, max_den: 8` | pictorial, abstract | `dropped_whole`, `added_whole_to_numerator` |
| `decimal.tenths.read` | `pv.hundred.intro` (Zone 1), `fraction.part.of_whole` | `DecimalGenerator.tenths` | `max_whole: 9` | concrete (ten-shard crystal), pictorial, abstract | `place_shift`, `read_as_whole` |
| `decimal.hundredths.read` | `decimal.tenths.read` | `DecimalGenerator.hundredths` | `max_whole: 9` | pictorial (10×10 grid), abstract | `place_shift`, `dropped_zero` |
| `decimal.fraction.convert` | `decimal.hundredths.read`, `fraction.equivalent.build` | `DecimalGenerator.from_fraction` | `dens: [2, 4, 5, 10, 20, 25, 50, 100]` | abstract | `wrote_numerator_as_decimal`, `place_shift` |
| `decimal.compare.order` | `decimal.hundredths.read` | `DecimalGenerator.compare` | `max_scale: 2` | pictorial, abstract | `longer_is_bigger`, `ignored_whole` |
| `percent.of_hundred.read` | `decimal.hundredths.read` | `PercentGenerator.of_hundred` | — | pictorial (10×10 grid) | `place_shift` |
| `percent.fraction.convert` | `percent.of_hundred.read`, `decimal.fraction.convert` | `PercentGenerator.from_fraction` | `dens: [2, 4, 5, 10, 20, 25, 50]` | abstract | `wrote_numerator_as_percent`, `place_shift` |
| `ratio.describe.part_part` | `simplify.ratio.gcf` | `RatioGenerator.part_to_part` | `max_count: 12` | concrete (ore mix), pictorial | `part_to_whole`, `inverted_ratio` |
| `ratio.scale.alloy` | `ratio.describe.part_part`, `mult.facts.mixed` | `RatioGenerator.scale_up` | `max_factor: 6` | concrete (alloy mixing), abstract | `added_instead_of_scaled`, `scaled_one_part` |
| `negative.depth.read` | `count.to_120.read` | `NegativeGenerator.depth_read` | `min_depth: -30` | pictorial (depth gauge) | `dropped_sign`, `off_by_one` |
| `negative.depth.compare` | `negative.depth.read` | `NegativeGenerator.compare` | `range: [-30, 30]` | pictorial | `bigger_magnitude_bigger` |
| `negative.depth.move` | `negative.depth.compare`, `sub.to_100.regroup` (Zone 2) | `NegativeGenerator.move` | `range: [-30, 30], step: 15` | pictorial (elevator moves), abstract | `wrong_direction`, `dropped_sign` |

Decision 3 below covers the one cross-zone prerequisite (`simplify.fraction.gcf` in Zone 6 needs `fraction.unit.identify` from Zone 7). Recommended fix: move `fraction.unit.identify` and `fraction.part.of_whole` into the Zone 6 JSON as "preview" skills, so the graph stays ordered by zone. Spiro signs off because it is a prerequisite change.

**Mechanic: crystal splitting** (Sprint 33). `scenes/zones/z07_crystal_shards/crystal.tscn` renders a crystal as `n` equal wedge shards (`Polygon2D` per shard, generated by `scripts/zones/crystal_shards.gd` from `den`). Charlie taps shards to shade them (`num`) and drags shards between two crystals to show equivalence. Comparison problems put two crystals side by side with a balance bar. Decimals use a ten-shard crystal and a 10×10 "crystal grid". Ratio uses the **alloy mixer** build (`scenes/workshop/builds/alloy_mixer/`): two ore hoppers, a recipe card with a ratio, and a mixing drum driven by an electric motor; the check is `scripts/zones/alloy.gd` pure logic. Negative numbers use the **depth gauge** (`scenes/zones/z07_crystal_shards/depth_gauge.tscn`): a vertical number line with 0 at the mountain base, Bolt's elevator moving above and below it.

**Fraction handwriting extension** (`scenes/input/ChalkSlate`). `ChalkSlate` currently lays out `n` digit boxes in a row. Add a **layout mode** enum:

```gdscript
enum Layout { ROW, FRACTION, DECIMAL }

@export var layout: Layout = Layout.ROW
@export var box_count: int = 1          # ROW: digits; FRACTION: digits per numerator/denominator
@export var decimal_places: int = 0     # DECIMAL only

signal answer_written(value: Variant)   # int, or {"num", "den"}, or {"mantissa", "scale"}
```

- `FRACTION`: two rows of boxes separated by a drawn vinculum (`Line2D`), numerator above, denominator below. Each box is still one digit, so the recognizer is unchanged. Boxes are at least `UI.min_target_px()` square; the vinculum is a non-interactive child.
- `DECIMAL`: a row of boxes with a fixed decimal point drawn between whole and fractional boxes. The child writes digits only; the point is never written.
- Low-confidence confirmation becomes "Did you write 3 over 4?" (line `z7.slate.confirm_fraction`) with the fraction rendered by the `Fraction` display scene.
- Palm rejection and `FakeRecognizer` fallback are unchanged. On mouse-only devices `answer_modes` drops `"handwriting_fraction"` and the `NumberPad` gets a fraction layout (two number pads stacked) under the same `InputRouter` action.
- No strokes are ever stored (`CLAUDE.md` rule 2).

### Zone 8: Power Tower (Sprints 35–37)

**Math.** Exponents, square and cube numbers, square roots of perfect squares, powers of 2 and 10, binary and other bases, scientific notation.

**Skill list** (`curriculum/skills/z08_power_tower.json`):

| Skill ID | Prereqs | Generator | Key params | Representations | Named distractors |
|---|---|---|---|---|---|
| `exp.repeated_mult.read` | `mult.facts.mixed`, `mult.equal_groups.total` (Zone 3) | `ExponentGenerator.repeated_mult` | `max_base: 5, max_exp: 4` | concrete (tower floors), pictorial, abstract | `multiplied_base_by_exp`, `added_base_exp_times` |
| `exp.evaluate.small` | `exp.repeated_mult.read` | `ExponentGenerator.evaluate` | `max_base: 6, max_exp: 4, max_value: 1000` | pictorial, abstract | `multiplied_base_by_exp`, `off_by_one_exponent`, `swapped_base_exp` |
| `exp.square.numbers` | `exp.evaluate.small`, `arr.rows_cols.count` (Zone 3) | `ExponentGenerator.square` | `max_n: 15` | concrete (square array), abstract | `doubled`, `off_by_one_square` |
| `exp.cube.numbers` | `exp.square.numbers` | `ExponentGenerator.cube` | `max_n: 8` | concrete (cube of blocks), abstract | `tripled`, `squared_only` |
| `root.square.perfect` | `exp.square.numbers` | `RootGenerator.square_root` | `max_root: 15` | pictorial (array side), abstract | `halved`, `off_by_one_root` |
| `exp.powers_of_two.list` | `exp.evaluate.small` | `ExponentGenerator.powers_of_base` | `base: 2, max_exp: 10` | concrete (doubling elevator floors) | `off_by_one_exponent`, `added_two` |
| `exp.powers_of_ten.list` | `exp.evaluate.small`, `pv.hundred.intro` | `ExponentGenerator.powers_of_base` | `base: 10, max_exp: 6` | abstract | `off_by_one_exponent`, `counted_digits_not_zeros` |
| `exp.zero_one.rules` | `exp.evaluate.small` | `ExponentGenerator.special_exponents` | `max_base: 12` | abstract | `zero_power_is_zero`, `first_power_is_one` |
| `base.binary.to_decimal` | `exp.powers_of_two.list`, `pv.tens_ones.build` | `BaseGenerator.to_decimal` | `base: 2, max_bits: 6` | concrete (vault lock lamps), pictorial (place-value columns) | `read_as_decimal_digits`, `reversed_bits`, `dropped_leading_place` |
| `base.binary.from_decimal` | `base.binary.to_decimal` | `BaseGenerator.from_decimal` | `base: 2, max_value: 63` | concrete, pictorial | `reversed_bits`, `greedy_skipped_place` |
| `base.binary.add` | `base.binary.from_decimal`, `add.to_20.sums` | `BaseGenerator.add` | `base: 2, max_bits: 5` | pictorial | `forgot_carry`, `carried_as_decimal` |
| `base.other.to_decimal` | `base.binary.to_decimal` | `BaseGenerator.to_decimal` | `bases: [3, 4, 5, 8], max_digits: 3` | pictorial | `read_as_decimal_digits`, `used_base_two` |
| `base.other.from_decimal` | `base.other.to_decimal` | `BaseGenerator.from_decimal` | `bases: [3, 4, 5, 8], max_value: 99` | pictorial | `greedy_skipped_place`, `used_base_two` |
| `sci.notation.read` | `exp.powers_of_ten.list`, `decimal.tenths.read` | `SciNotationGenerator.read` | `exp_range: [1, 6], mantissa_places: 1` | abstract | `off_by_one_exponent`, `counted_digits_not_shift` |
| `sci.notation.write` | `sci.notation.read` | `SciNotationGenerator.write` | `max_value: 9_000_000` | abstract | `mantissa_not_normalized`, `off_by_one_exponent` |
| `lever.counterweight.balance` | `mult.facts.mixed`, `exp.powers_of_two.list` | `LeverGenerator.balance` | `max_weight: 32, distances: [1, 2, 4, 8]` | concrete (elevator counterweight) | `matched_weight_only`, `added_distance` |

**Mechanic: binary vault locks and the elevator counterweight** (Sprint 36). `scenes/zones/z08_power_tower/vault_lock.tscn`: a row of lamps (off/on = 0/1) above place-value labels (32, 16, 8, 4, 2, 1). Tapping a lamp toggles it; the lock opens when the lamps sum to the target. Other bases use dials with `b` positions instead of lamps. `scenes/zones/z08_power_tower/tower_elevator.tscn`: floors numbered by powers (floor `k` is at height `2^k` for the doubling elevator) with a `create_tween()` for the cab. The build project **Counterweight Elevator** (`scenes/workshop/builds/counterweight_elevator/`) balances `weight × distance` on each side of a lever (moment balance, kept to whole numbers); logic in `scripts/zones/lever.gd`. All lights are electric lamps; the vault glows with crystals.

**Notation.** Exponents display as superscripts. `RichTextLabel` BBCode is used only where a plain `Label` cannot render the notation; check the 4.7 docs for superscript support (verify in Godot docs: BBCode tags available in `RichTextLabel`; if there is no superscript tag, render the exponent as a smaller, raised `Label` inside an `HBoxContainer`, which is what the `ExponentDisplay` scene below does). Build `scenes/ui/math/exponent_display.tscn` and `scenes/ui/math/fraction_display.tscn` as reusable scenes, and have every zone use them rather than ad-hoc labels.

### Zone 9: Pattern Grotto (Sprints 39–40)

**Math.** Sequences (arithmetic and geometric), triangular and square numbers, Fibonacci numbers, the golden ratio as a limit of ratios, Gauss's sum 1 + 2 + … + n, proof without words.

**Skill list** (`curriculum/skills/z09_pattern_grotto.json`):

| Skill ID | Prereqs | Generator | Key params | Representations | Named distractors |
|---|---|---|---|---|---|
| `seq.arith.next_term` | `skip.by_5.to_100` (Zone 3) | `SequenceGenerator.arithmetic` | `max_start: 20, max_step: 9, length: 5` | concrete (crystal tiles), abstract | `added_wrong_step`, `repeated_last_term` |
| `seq.arith.missing_term` | `seq.arith.next_term` | `SequenceGenerator.arithmetic_missing` | same | pictorial, abstract | `added_wrong_step`, `averaged_neighbors_wrong` |
| `seq.arith.rule_describe` | `seq.arith.missing_term` | `SequenceGenerator.describe_rule` | same | abstract | `confused_start_and_step` |
| `seq.geom.next_term` | `exp.powers_of_two.list` | `SequenceGenerator.geometric` | `ratios: [2, 3, 5, 10], max_value: 1000` | concrete (doubling crystals), abstract | `added_ratio`, `off_by_one_exponent` |
| `seq.arith_vs_geom.classify` | `seq.arith.next_term`, `seq.geom.next_term` | `SequenceGenerator.classify` | — | abstract | `swapped_types` |
| `fig.triangular.build` | `add.to_100.regroup`, `arr.rows_cols.count` | `FigurateGenerator.triangular` | `max_n: 12` | concrete (stacked gems), pictorial | `used_square`, `off_by_one_n` |
| `fig.square.build` | `exp.square.numbers`, `fig.triangular.build` | `FigurateGenerator.square` | `max_n: 12` | concrete | `used_triangular`, `off_by_one_n` |
| `fig.two_triangles.square` | `fig.square.build` | `FigurateGenerator.two_triangles` | `max_n: 10` | pictorial (proof without words) | `added_same_triangular_twice_wrong_n` |
| `fib.sequence.next_term` | `add.to_100.regroup` | `FibGenerator.next_term` | `max_index: 15` | concrete (crystal spiral), abstract | `added_wrong_pair`, `doubled_last` |
| `fib.sequence.missing_term` | `fib.sequence.next_term` | `FibGenerator.missing_term` | `max_index: 15` | abstract | `added_wrong_pair` |
| `fib.ratio.converge` | `fib.sequence.next_term`, `decimal.hundredths.read` | `FibGenerator.ratio_to_hundredths` | `max_index: 12` | pictorial (golden rectangle), abstract | `inverted_ratio`, `place_shift` |
| `gauss.sum.pairing` | `fig.triangular.build`, `mult.facts.mixed` | `GaussGenerator.sum_to_n` | `max_n: 20` | pictorial (pairing diagram), abstract | `forgot_halve`, `used_n_squared`, `off_by_one_n` |
| `gauss.sum.formula` | `gauss.sum.pairing` | `GaussGenerator.sum_to_n` | `max_n: 100, require_formula: true` | abstract | `forgot_halve`, `used_n_squared` |
| `proof.words.match` | `fig.two_triangles.square`, `gauss.sum.pairing` | `ProofGenerator.match_diagram` | diagram ids | pictorial only | `wrong_diagram` |
| `fib.poem.syllables` | `fib.sequence.next_term` | `FibPoemGenerator.count_check` | `lines: [1, 1, 2, 3, 5, 8]` | abstract (word tiles) | `wrong_line_count` |

**Mechanic: pattern tiles, proof-without-words puzzles and the Fib poem maker** (Sprint 40). `scenes/zones/z09_pattern_grotto/pattern_wall.tscn`: a row of crystal tiles with one or more blank slots; Charlie drags number tiles into slots or taps the rule. `scenes/zones/z09_pattern_grotto/proof_board.tscn`: drag-tile diagrams (two staircases that fit into a rectangle for Gauss's sum; two triangular arrays forming a square). `scenes/zones/z09_pattern_grotto/fib_poem.tscn`: six lines with syllable targets 1, 1, 2, 3, 5, 8; a word bank of tiles with pre-counted syllables (`curriculum/poem_words.json`, each word with `syllables: int` checked by a human, never computed at runtime); a line glows when its syllable total matches. Writing his own poem (free text) is Scholar-mode only and uses the keyboard path; the game never judges the words, only the counts, and stores nothing from free text beyond the profile's saved poems (text only, no strokes).

Crystal spirals (Fibonacci) grow by `create_tween()` from the center. No animals in the spiral examples (sunflower seeds and pine cones are fine; no shells, no bees).

### Scholar mode, part 1 (Sprint 37)

Section 3.3 of the master plan: Scholar mode unlocks gradually, per feature, driven by reading checks and a parent setting. Part 1 delivers the two features that Zones 8–9 need.

**Gating.** Add `scripts/core/mode_gate.gd` (`class_name ModeGate`, pure logic):

```gdscript
class_name ModeGate
extends RefCounted

enum Feature { KEYBOARD_ENTRY, MATH_NOTATION, LONGER_TEXT, REDUCED_NARRATION }

## parent_setting: "explorer" | "scholar" | "auto"
## reading_level: 0..3 from the profile's reading checks (Phase 3 stores this)
static func is_enabled(feature: Feature, parent_setting: String, reading_level: int, has_keyboard: bool) -> bool:
    match parent_setting:
        "explorer": return false
        "scholar": return feature != Feature.KEYBOARD_ENTRY or has_keyboard
        _:
            match feature:
                Feature.KEYBOARD_ENTRY: return has_keyboard and reading_level >= 2
                Feature.MATH_NOTATION: return reading_level >= 2
                Feature.LONGER_TEXT: return reading_level >= 3
                Feature.REDUCED_NARRATION: return reading_level >= 3
    return false
```

`has_keyboard` comes from `InputRouter` (laptop posture on the 2-in-1, or a connected keyboard; verify in Godot docs which `DisplayServer` or `Input` signal reports keyboard presence on Android, and fall back to "a key was pressed in this session"). The parent setting lives in the profile, edited in the parent area.

**Keyboard entry.** A new input scene `scenes/input/KeyboardEntry.tscn` that accepts digit keys, minus, slash (fraction), period (decimal) and Enter through `InputRouter` actions, and shows the typed value in the same `fraction_display` / `exponent_display` scenes. It is **not** a `LineEdit` (rule 6): it is a `Control` that handles `_unhandled_key_input` and renders its own text, so no system keyboard ever appears. Backspace and Enter map to `InputRouter` actions `ui_erase` and `ui_submit`.

**Math notation.** `scenes/ui/math/` holds `fraction_display.tscn`, `exponent_display.tscn`, `sci_notation_display.tscn` and `congruence_display.tscn` (the last is a stub for Phase 5; `≡` is a plain Unicode character in Andika, verify that Andika's glyph set includes U+2261 and U+00B2–U+2079; if not, add a fallback font and record it in `assets/CREDITS.md`). Explorer mode shows "2 to the power 5" in words next to the notation; Scholar mode shows notation alone.

**Text table.** Scholar-mode lines use the same IDs with a `.scholar` suffix variant column? No: keep one ID per line and add a `mode` column to `text/lines.csv` (`explorer` default, `scholar` optional). `Text.get_line(id)` picks the scholar variant when `ModeGate.is_enabled(Feature.LONGER_TEXT, …)` is true and a variant exists. This is additive and does not break Phase 3's voice pipeline, which treats each `(id, mode)` pair as its own clip.

### Yearly platform update procedure (Sprint 38)

Google Play raises the target API level every August 31. Sprint 38 (Aug 2–6, 2027) handles the 2027 requirement. Procedure, to be saved as `docs/platform-update.md` and reused every year:

1. **Read the requirement.** Check the current Play target-API requirement and the Godot Android export docs for the pinned 4.7.x version. Note the required target SDK and the minimum Godot version that supports it.
2. **Decide on Godot.** If the pinned 4.7.x cannot target the new SDK, propose the smallest upgrade (a 4.7 patch first, then 4.8 only if required). **Ask Spiro before upgrading** (`CLAUDE.md`). Record the decision in `docs/decisions.md`.
3. **Update the toolchain in a branch** `chore/platform-update-2027`: `.godot-version`, Android Studio SDK (`sdkmanager "platforms;android-NN"`), build tools, JDK if the Godot docs changed the recommendation, Gradle build template (re-install from the editor: Project → Install Android Build Template, verify in Godot docs for 4.7 wording).
4. **Update `export_presets.cfg`:** `gradle_build/target_sdk`, keep `min_sdk` at Godot's default, ABIs stay `arm64-v8a` + `x86_64`, permissions stay empty (no `INTERNET`), screen-size settings keep every size on (phones are supported). Diff the preset and confirm nothing else changed.
5. **Re-run the SDK audit** (`docs/sdk-audit.md`, `tools/ci/check_sdk_audit.py`), with no new dependencies. (Corrected 2026-10-19: there is no Kotlin plugin or LiteRT to rebuild; handwriting runs in GDScript. The maintained procedure is `docs/platform-update.md`.)
6. **Full regression:** `--import`, all GdUnit4 suites, all cross-checks, lint, debug APK on both of Charlie's devices (all postures, touch, stylus, keyboard), emulator matrix (tablet, resizable/desktop, x86_64 Chromebook), airplane-mode session, save from the previous version loads, handwriting accuracy spot check (20 digits per device).
7. **CI:** update the Godot version in `.github/workflows/ci.yml` and the `tools/ci/` scripts; confirm the Friday build job passes.
8. **Release** via the standard checklist as a maintenance update (`v1.4.1-platform`). Staged rollout. Watch Play Console vitals for 48 hours.
9. **Data safety form and privacy policy:** re-read both; a platform update should change nothing, and the review confirms it.

Budget the full sprint for this. Zone 9 work does not start until the regression passes.

---

## Sprint plan

Dates follow the master plan. Sprints 29, 31 and 34 are 4-day holiday weeks; every other sprint, including 38, is a full week. Each sprint starts with the Monday 30-minute planning and ends with the Friday internal-track build.

### Sprint 29 (Jun 1–4, 4 days, Memorial Day): Zone 6 curriculum and generators

**Goal.** Zone 6's skill graph, generators and cross-checks exist and the math reviewer has the samples.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S29-01 | `feat/z6-skill-graph` | `curriculum/skills/z06_gear_works.json` with the 12 skills above; vocabulary entries for GCF, LCM, simplest form, gear ratio, coprime | `tests/curriculum/test_skill_graph.gd` passes (acyclic, all generators resolve, all prereqs exist) |
| P4-S29-02 | `feat/z6-rational-helper` | `scripts/core/rational.gd` with gcd, lcm, normalize, add, sub, mul, compare, to_decimal | `tests/core/test_rational.gd`: 40+ cases including gcd(0, n), negative inputs rejected by assert, lcm overflow guard (`assert(a * b < 2**62)`) |
| P4-S29-03 | `feat/z6-gcf-generator` | `GcfGenerator` (common_factors, gcf, gcf_from_factorization, coprime) | Seeded GdUnit4 tests; 10,000-problem cross-check passes |
| P4-S29-04 | `feat/z6-lcm-generator` | `LcmGenerator` (common_multiples, lcm, lcm_from_factorization, product_relation) | Same |
| P4-S29-05 | `feat/z6-gear-simplify-generators` | `GearGenerator`, `SimplifyGenerator` | Same |
| P4-S29-06 | `content/z6-text-lines` | All Zone 6 lines in `text/lines.csv` (`z6.*`), about 60 lines, 12 words or fewer each in Explorer mode | `lint_content.py` passes; reading-level spot check by Spiro |
| P4-S29-07 | `chore/z6-reviewer-pack` | `tools/crosscheck/export_samples.py --zone 6` output sent to the math reviewer; artist brief for Zone 6 sent | Emails sent; `docs/decisions.md` has a pending entry |

**Implementation notes for the agent**

- Generators are pure: no `Node`, no autoload access, no `randi()`. Pass `rng` through every helper.
- Distractor lists: build as `Array[Distractor]`, then filter `value == answer` and duplicates, then take the first three. If fewer than two distractors survive, regenerate the operands (loop with a cap of 50 tries, then `push_error` and return the problem with fewer distractors; tests assert the cap is never hit on 10,000 problems).
- `coprime_rate` is applied by drawing `rng.randf()`; tests pin the rate within ±3% over 10,000 problems.
- The hint ladder for GCF/LCM: step 2's visual model is a pair of factor lists (pictorial representation), step 3 a worked example with the same `params` but a different seed.
- Explain in the summary for Spiro: a `RefCounted` class with only static functions is Godot's idiom for a stateless module; `class_name` registers it globally.

**Tests**

- `tests/generators/test_gcf_lcm.gd`, `tests/generators/test_gears.gd`, `tests/generators/test_simplify.gd`: seeds 1–20, edge cases (a == b, one is a multiple of the other, both prime, coprime), distractor invariants, `answer_modes` non-empty, `prompt_line_id` exists in `text/lines.csv`.
- `tools/crosscheck/gcf_lcm.py` uses `math.gcd` and `math.lcm`; `tools/crosscheck/simplify.py` uses `fractions.Fraction`.
- `python -m pytest tools` passes.

**Charlie playtest (weekend).** Paper prototype of gears: cardboard gears with marked teeth; does "they line up again after 12 turns" make sense? Log the words he uses for LCM.

### Sprint 30 (Jun 7–11): Zone 6 gear-train machine builder

**Goal.** Zone 6 is playable gray-box: dig loop with gear problems plus the Conveyor Sync build project.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S30-01 | `feat/z6-gear-train-logic` | `scripts/zones/gear_train.gd`: `turns_to_align`, `ratio`, `direction_of(index)` | Unit tests pass, including alternating rotation direction |
| P4-S30-02 | `feat/z6-gear-scene` | `scenes/zones/z06_gear_works/gear.tscn`, `gear_bench.tscn`; drag from tray to axle via `InputRouter` | Works with touch, stylus and mouse; targets ≥ `UI.min_target_px()` |
| P4-S30-03 | `feat/z6-dig-integration` | Zone 6 rocks present GCF/LCM problems through the existing `scenes/mine/` flow with tap, drag and numpad modes | A full dig session on both devices; autosave after every rock |
| P4-S30-04 | `feat/z6-conveyor-sync-build` | `scenes/workshop/builds/conveyor_sync/`: pick gears so two conveyors deliver together; rewards per the build framework | Build completes; the machine keeps running in the hub afterwards |
| P4-S30-05 | `feat/z6-hint-ladder` | Hint ladder steps 1–4 wired for every Zone 6 skill (highlight, factor lists, worked example, easier version) | GdUnit4 scene test walks all four steps |
| P4-S30-06 | `feat/z6-word-gems` | Word Gems for GCF, LCM, simplest form, coprime, gear ratio with pictures | Tapping the term in a prompt shows the picture and definition |

**Implementation notes for the agent**

- Gear rotation: one `Tween` per train, created when the train changes, looping with `set_loops()`; each gear's `rotation` is driven by `tween_method` with the ratio applied. Explain `Tween` to Spiro: a one-shot animation object created by `create_tween()` that interpolates properties over time and frees itself.
- Direction alternates along the train; a gear with an odd index spins the other way. This is cosmetic and must not be asked as math in Zone 6.
- Keep `_process` free of allocations; precompute `Array[float]` of angular speeds when the train changes.
- Motor sound: an electric whir, OGG, looped, on the SFX bus.

**Tests**

- `tests/zones/test_gear_train.gd`: `turns_to_align([8, 12]) == 3`, `[6, 8, 12] == 4`, single gear == 1.
- Scene test instantiates `gear_bench.tscn` headless, simulates a drag through `InputRouter.simulate_drag(from, to)` (helper from Phase 1 tests), and asserts the gear snapped to the axle.
- Save/resume mid-build.

**Charlie playtest.** "Is building gear trains fun?" with gray boxes. Watch whether he tries to sync by trial and error or by counting teeth; both are fine, but log it for the hint ladder.

### Sprint 31 (Jun 14–17, 4 days, Juneteenth): Zone 6 art, voice, polish, release

**Goal.** Zone 6 ships to production as content update 1.1.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S31-01 | `content/z6-art` | Integrate the artist's Zone 6 batch (gears, bench, conveyor, zone backdrop); `assets/CREDITS.md` updated | No placeholder art visible in Zone 6 |
| P4-S31-02 | `content/z6-voice` | Voice batch for all `z6.*` lines (ask Spiro before the paid run); coverage 100% | `tools/voice/coverage.py --zone 6` reports 0 missing |
| P4-S31-03 | `feat/z6-polish` | Gear-mesh particles, crack and reveal effects, zone-complete celebration, gear sound variations | Reviewed on both devices |
| P4-S31-04 | `feat/z6-badge-euclid-gcf` | Optional: the Euclid badge (if not yet earned in Phase 2) gains a GCF story variant | Badge story plays |
| P4-S31-05 | `chore/release-1.1` | Release checklist run; version bump; AAB; internal track; staged rollout; git tag `v1.1.0-zone6`; store listing "What's new" | Production rollout at 20% started; 48-hour watch scheduled |

**Implementation notes for the agent**

- Art integration: texture atlas per zone (`assets/art/z06/atlas.png` with the editor's atlas import; verify in Godot docs for 4.7 the `AtlasTexture` workflow), OGG for every sound.
- Voice: never edit `narration/audio/` by hand. Changed lines get a new `voice_version`.
- Release notes are written for parents, two sentences, no marketing superlatives.

**Tests**

- Full regression (all suites, cross-checks, lint).
- Narration coverage test: `tests/narration/test_coverage.gd` asserts every `z6.*` line has audio.
- Device matrix: 2-in-1 in all three postures, tablet, emulator x86_64 Chromebook profile, mouse-only run of every Zone 6 screen.

**Charlie playtest.** Full Zone 6 session with art and narration on the internal build. Is Bolt's narration of "least common multiple" clear? Does he replay lines?

### Sprint 32 (Jun 21–25): Zone 7 curriculum, generators and fraction handwriting

**Goal.** Zone 7's 20 skills, generators and cross-checks; the ChalkSlate fraction and decimal layouts.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S32-01 | `feat/z7-skill-graph` | `curriculum/skills/z07_crystal_shards.json`; vocabulary (numerator, denominator, equivalent, tenth, hundredth, percent, ratio, negative) | Graph test passes; decision 3 resolved and recorded |
| P4-S32-02 | `feat/z7-fraction-generator` | `FractionGenerator` (unit_fraction, part_of_whole, number_line, equivalent, compare, add, mixed_number) | Seeded tests; cross-check 10,000 each |
| P4-S32-03 | `feat/z7-decimal-percent-generators` | `DecimalGenerator`, `PercentGenerator` | Same |
| P4-S32-04 | `feat/z7-ratio-negative-generators` | `RatioGenerator`, `NegativeGenerator` | Same |
| P4-S32-05 | `feat/slate-fraction-layout` | `ChalkSlate` `Layout.FRACTION` and `Layout.DECIMAL`; confirmation line; numpad fraction fallback | Scene tests pass with `FakeRecognizer`; works on both devices with finger and stylus |
| P4-S32-06 | `feat/fraction-display-scene` | `scenes/ui/math/fraction_display.tscn` and `decimal` formatting in `Text` | Renders 3/4, 1 2/3, 0.25, 12% at Explorer sizes |
| P4-S32-07 | `content/z7-text-lines` | All `z7.*` lines, about 90 | Lint passes |
| P4-S32-08 | `chore/z7-reviewer-pack` | Samples to the math reviewer; artist brief for Zone 7 | Sent |

**Implementation notes for the agent**

- Fractions are always normalized by `Rational.normalize` before becoming `answer`. Improper fractions are allowed only when `params.allow_improper` is true; `mixed_number` problems store `{"whole": w, "num": n, "den": d}` with `n < d`.
- `add` with unlike denominators chooses denominators whose LCM is at most `max_den * 2` so pictorial models stay drawable.
- `number_line` problems store the tick count in `params` so the pictorial scene and the checker agree.
- Decimals never pass through `float`. `to_decimal` divides integers and returns `{mantissa, scale}`; for denominators not dividing a power of 10 (e.g., 3), the generator never asks for a decimal conversion (`dens` list restricts it).
- Negative depth: the gauge shows 0 at the base; "deeper" means more negative. Lines say "30 meters below" in Explorer mode and show "−30" alongside.
- `ChalkSlate` box geometry: numerator and denominator boxes each `UI.min_target_px() * 1.5` square; total slate height must fit 16:10 and 4:3 at Explorer sizes, so compute from the viewport, not constants.

**Tests**

- Generator tests: equal denominators never produce `added_denominators` equal to the answer (filtered); compare problems never produce equal fractions unless `params.allow_equal`.
- `tools/crosscheck/fractions.py`, `decimals.py`, `ratio.py`, `negatives.py` with `fractions.Fraction` and `decimal.Decimal`.
- `tests/scenes/input/test_chalk_handwriting_fraction.gd`: writing "3" above and "4" below emits `{"num": 3, "den": 4}`; low confidence on the denominator triggers the confirmation line.
- Cross-device: a mouse-only emulator run reaches every Zone 7 answer via the fraction numpad.

**Charlie playtest.** Paper crystals cut into shards; can he show 2/4 equals 1/2 by stacking? Try writing a fraction on the slate prototype (the `FakeRecognizer` build on the tablet is fine).

### Sprint 33 (Jun 28–Jul 2): Zone 7 crystal splitting, depth gauge, alloy mixer

**Goal.** Zone 7 playable gray-box with all three mechanics.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S33-01 | `feat/z7-crystal-scene` | `crystal.tscn` with `n` wedge shards generated from `den`; tap to shade, drag between crystals | Equivalence and compare problems playable by touch, stylus and mouse |
| P4-S33-02 | `feat/z7-crystal-grid` | 10-shard crystal and 10×10 grid for decimals and percents | Decimal and percent skills playable |
| P4-S33-03 | `feat/z7-depth-gauge` | `depth_gauge.tscn`: vertical number line, elevator cab, negative labels | Negative skills playable; the cab animates with a tween |
| P4-S33-04 | `feat/z7-alloy-mixer-build` | `scenes/workshop/builds/alloy_mixer/`; `scripts/zones/alloy.gd` | Ratio build completes; machine persists in the hub |
| P4-S33-05 | `feat/z7-dig-integration` | Zone 7 rocks route to the right mechanic by `representation` and `answer_modes` | Full session on both devices |
| P4-S33-06 | `feat/z7-hint-ladder` | Hint ladder for all 20 skills; step 2 models: shaded crystal, number line, grid, gauge | Scene test walks all steps for three representative skills |
| P4-S33-07 | `feat/z7-word-gems` | Word Gems for the Zone 7 vocabulary | Tap-to-define works |

**Implementation notes for the agent**

- Shards: generate `Polygon2D` points for wedge `i` of `n` once per crystal; cache per `den` in a `Dictionary[int, PackedVector2Array]` on the script (static), not per node.
- Tapping a shard toggles shading; a `ColorRect` overlay is cheaper than swapping textures. Color is never the only clue: shaded shards also get a small gem icon.
- Drag between crystals uses the standard `InputRouter` drag with a drop target of at least `UI.min_target_px()`.
- The depth gauge uses one `Line2D` and a `VBoxContainer` of labels; label every 5 units at Explorer sizes.

**Tests**

- `tests/zones/test_crystal_shards.gd`: wedge count equals `den`; shading `num` shards reports `{num, den}` normalized.
- `tests/zones/test_alloy.gd`: scaling 2:3 by 4 yields 8:12; wrong mixes report the misconception id for the hint.
- Save mid-dig on a crystal problem, resume, same problem and shading state.

**Charlie playtest.** "Is splitting crystals fun?" and whether negative depth makes sense ("the elevator goes below the mountain's floor").

### Sprint 34 (Jul 6–9, 4 days, July 4 observed): Zone 7 art, voice, polish, release

**Goal.** Zone 7 ships as content update 1.2.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S34-01 | `content/z7-art` | Artist batch for crystals, grid, gauge, mixer; credits | No placeholders |
| P4-S34-02 | `content/z7-voice` | Voice batch for `z7.*` (ask first) plus fraction phrase fragments ("over", "point", "percent", "below") | Coverage 100% |
| P4-S34-03 | `feat/narration-fraction-splice` | `Narration` speaks fractions ("three over four"), decimals ("two point seven five") and negatives ("thirty below") by splicing number clips with the new fragments | `tests/autoload/test_narration.gd` new cases pass |
| P4-S34-04 | `feat/z7-polish` | Shard-split particles, crystal chime, gauge motion sound | Reviewed |
| P4-S34-05 | `chore/release-1.2` | Checklist, bump, AAB, internal, staged rollout, tag `v1.2.0-zone7` | Rollout started |

**Implementation notes for the agent**

- Decimal narration: "two point seven five" is digit-by-digit after the point; never "seventy-five".
- Narration fragment IDs: `frag.over`, `frag.point`, `frag.percent`, `frag.below`, `frag.and` (for mixed numbers). Add them to `text/lines.csv` like any line.

**Tests**

- Full regression; narration coverage for `z7.*` and all fragments; device matrix; a mouse-only pass of every Zone 7 screen.

**Charlie playtest.** Full Zone 7 session with art and voice. Does he use the slate for fractions or the numpad?

### Sprint 35 (Jul 12–16): Zone 8 curriculum and generators

**Goal.** Zone 8's 16 skills, generators and cross-checks; exponent and base display scenes.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S35-01 | `feat/z8-skill-graph` | `curriculum/skills/z08_power_tower.json`; vocabulary (base, exponent, power, square, cube, square root, binary, scientific notation) | Graph test passes |
| P4-S35-02 | `feat/z8-exponent-root-generators` | `ExponentGenerator`, `RootGenerator` | Seeded tests; cross-check 10,000 each |
| P4-S35-03 | `feat/z8-base-generators` | `BaseGenerator` (to_decimal, from_decimal, add) for bases 2, 3, 4, 5, 8 | Same |
| P4-S35-04 | `feat/z8-sci-lever-generators` | `SciNotationGenerator`, `LeverGenerator` | Same |
| P4-S35-05 | `feat/exponent-display-scene` | `scenes/ui/math/exponent_display.tscn`, `sci_notation_display.tscn` | Renders 2⁵, 10³, 3.4 × 10⁵ at Explorer sizes; superscript approach recorded in `docs/decisions.md` |
| P4-S35-06 | `content/z8-text-lines` | All `z8.*` lines, about 80 | Lint passes |
| P4-S35-07 | `chore/z8-reviewer-pack` | Samples to the reviewer; artist brief | Sent |

**Implementation notes for the agent**

- Exponent values stay under `max_value` so the pictorial representation (floors, blocks) is drawable; `cube` stops at 8³ = 512.
- `special_exponents` asks b⁰ and b¹; distractor `zero_power_is_zero` is the classic misconception.
- Base conversion answers store digits most-significant first; the checker uses Python's `int(s, base)` and a hand-written `to_base`, both independent of GDScript.
- Scientific notation at this level uses one decimal place in the mantissa; `write` problems choose values that normalize cleanly (`34 × 10^5`, never `3.45`).
- Lever problems keep `weight × distance` under 256 on each side and produce whole-number solutions only.

**Tests**

- Exponent tests include `swapped_base_exp` being filtered when `b^e == e^b` (2⁴ = 4²).
- `tools/crosscheck/exponents.py`, `bases.py`, `sci_notation.py`, `lever.py`.

**Charlie playtest.** Lamp-row prototype: six lamps labeled 32, 16, 8, 4, 2, 1; "make 13". Does the greedy strategy come naturally?

### Sprint 36 (Jul 19–23): Zone 8 vault locks, other bases, elevator counterweight

**Goal.** Zone 8 playable gray-box.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S36-01 | `feat/z8-vault-lock` | `vault_lock.tscn`: lamp row for binary, dials for other bases, open animation | Base skills playable with touch, stylus, mouse |
| P4-S36-02 | `feat/z8-tower-elevator` | `tower_elevator.tscn`: floors at powers, cab tween | Powers-of-two and exponent skills playable |
| P4-S36-03 | `feat/z8-counterweight-build` | `scenes/workshop/builds/counterweight_elevator/`; `scripts/zones/lever.gd` | Build completes and persists |
| P4-S36-04 | `feat/z8-dig-integration` | Zone 8 rocks routed by representation | Full session on both devices |
| P4-S36-05 | `feat/z8-hint-ladder` | Hint ladder for all 16 skills; step 2 models: block tower, lamp row with place labels, array side | Scene tests |
| P4-S36-06 | `feat/z8-word-gems` | Word Gems | Works |

**Implementation notes for the agent**

- Lamps are `TextureButton`s with `toggle_mode = true`; the lock logic (`scripts/zones/vault_lock.gd`, pure) sums `digit * base^place`. The scene only renders.
- Dials for base `b` cycle 0..b−1 on tap; a long press is not used (no multi-step gestures).
- The open animation is a crystal glow, not a flame.

**Tests**

- `tests/zones/test_vault_lock.gd`: `[1,1,0,1]` in base 2 is 13; base 5 `[2,3]` is 13.
- `tests/zones/test_lever.gd`: 8 × 2 balances 4 × 4; unbalanced cases report which side is heavier.
- Save/resume mid-lock.

**Charlie playtest.** "Are vault locks fun?" Count how many locks he opens in 10 minutes and whether he explains the lamp values to you.

### Sprint 37 (Jul 26–30): Zone 8 art, voice, polish, release; Scholar mode part 1

**Goal.** Zone 8 ships as content update 1.3, with keyboard entry and notation behind the Scholar gate.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S37-01 | `content/z8-art` | Artist batch; credits | No placeholders |
| P4-S37-02 | `content/z8-voice` | Voice batch for `z8.*` (ask first) plus fragments ("to the power", "squared", "cubed", "times ten to the") | Coverage 100% |
| P4-S37-03 | `feat/mode-gate` | `scripts/core/mode_gate.gd`; profile field `interface_mode` (`explorer`/`scholar`/`auto`); parent-area control | Unit tests for every branch of `is_enabled` |
| P4-S37-04 | `feat/keyboard-entry` | `scenes/input/KeyboardEntry.tscn` via `InputRouter`; `"keyboard"` answer mode on Zone 7–8 skills when gated on | Keyboard-only pass of Zones 7–8 on the 2-in-1 in laptop posture |
| P4-S37-05 | `feat/scholar-notation` | Notation-only rendering in Scholar mode; `mode` column in `text/lines.csv`; `Text.get_line` variant lookup | Explorer and Scholar renderings reviewed side by side |
| P4-S37-06 | `feat/z8-polish` | Lamp glow particles, elevator hum, lock chime | Reviewed |
| P4-S37-07 | `chore/release-1.3` | Checklist, bump, AAB, internal, staged rollout, tag `v1.3.0-zone8` | Rollout started |

**Implementation notes for the agent**

- The profile field is a save-schema change: write migration `scripts/save/migrations/vNN_interface_mode.gd` defaulting to `"auto"`, add a fixture, and **ask Spiro** before merging (schema change).
- `KeyboardEntry` must never be a `LineEdit`; `lint_content.py` already rejects `LineEdit` in child scenes and should also flag `TextEdit`.
- Keyboard presence: when unsure, treat the keyboard as present only after a key event in the session; record the detection approach in `docs/decisions.md`.

**Tests**

- `tests/core/test_mode_gate.gd`; `tests/scenes/input/test_keyboard_entry.gd` (digits, slash, period, minus, backspace, enter; invalid keys ignored).
- Full regression; narration coverage for `z8.*`; device matrix including a keyboard-only pass.

**Charlie playtest.** Zone 8 full session. Separately, try Scholar mode on the laptop posture for one dig: does he prefer typing?

### Sprint 38 (Aug 2–6): Yearly platform update

**Goal.** The app targets the 2027 Google Play requirement with zero regressions. Follow the procedure in Architecture and design.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S38-01 | `chore/platform-update-2027` | Read requirements; propose Godot patch/upgrade; **ask Spiro**; record decision | `docs/decisions.md` entry |
| P4-S38-02 | same | Toolchain, `.godot-version`, Gradle template, `export_presets.cfg` target SDK; permissions unchanged | Preset diff reviewed; no `INTERNET` |
| P4-S38-03 | same | SDK audit refreshed (no AAR to rebuild: handwriting is GDScript) | `docs/sdk-audit.md` updated |
| P4-S38-04 | same | CI workflow and `tools/ci/` updated | CI green |
| P4-S38-05 | same | Full regression per the procedure; old-save upgrade test | All green on both devices and the emulator matrix |
| P4-S38-06 | `chore/release-1.4.1` | Maintenance release, staged rollout, tag `v1.4.1-platform` | Rollout started |
| P4-S38-07 | `docs/platform-update` | `docs/platform-update.md` written for next year | Reviewed by Spiro |

**Implementation notes for the agent**

- Do not bundle any feature work in this branch.
- If the Godot upgrade changes `.tscn` formats, let the editor re-save scenes in one dedicated commit and review the diff for uid changes (never hand-edit uids).

**Tests**

- Everything. Plus: install the previous production build, play one rock, update to the new build, confirm progress and profile intact.

**Charlie playtest.** Regular play on the updated build; no new content to test.

### Sprint 39 (Aug 9–13): Zone 9 curriculum and generators

**Goal.** Zone 9's 15 skills, generators, cross-checks; poem word bank.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S39-01 | `feat/z9-skill-graph` | `curriculum/skills/z09_pattern_grotto.json`; vocabulary (sequence, term, rule, triangular number, Fibonacci, golden ratio) | Graph test passes |
| P4-S39-02 | `feat/z9-sequence-generators` | `SequenceGenerator`, `FigurateGenerator` | Seeded tests; cross-check |
| P4-S39-03 | `feat/z9-fib-gauss-generators` | `FibGenerator`, `GaussGenerator`, `ProofGenerator` | Same |
| P4-S39-04 | `content/z9-poem-words` | `curriculum/poem_words.json`: about 150 kid-friendly words with human-checked syllable counts; `FibPoemGenerator.count_check` | Reviewed by Spiro; no banned themes |
| P4-S39-05 | `content/z9-text-lines` | All `z9.*` lines, about 70 | Lint passes |
| P4-S39-06 | `chore/z9-reviewer-pack` | Samples to the reviewer; artist brief | Sent |

**Implementation notes for the agent**

- Fibonacci ratio to hundredths: compute `F(n+1) * 100 / F(n)` with integer division and round half up; the checker uses `fractions.Fraction` and `round`. Store as `{mantissa, scale: 2}`.
- Gauss's sum: `n * (n + 1) / 2` with integer arithmetic; `forgot_halve` is `n * (n + 1)`.
- Proof-without-words problems are matching tasks (`proof.words.match`): the answer is a diagram id, and the distractors are other diagram ids. There is no arithmetic to cross-check; the Python checker instead validates that each diagram id exists in `curriculum/proof_diagrams.json`.
- Syllable counts are data, never computed; the generator only sums.

**Tests**

- Sequence tests: arithmetic sequences never produce negative terms in Explorer params; geometric terms stay under `max_value`.
- `tools/crosscheck/sequences.py`, `figurate.py`, `fibonacci.py`, `gauss.py`.

**Charlie playtest.** Gem staircase on paper: build triangular numbers with real gems or blocks; try pairing 1+10, 2+9… for Gauss.

### Sprint 40 (Aug 16–20): Zone 9 mechanics, art, voice, polish, Version 1.5 release

**Goal.** Zone 9 playable and shipped; Version 1.5 tagged. This sprint compresses the zone pattern's Sprints B and C, which the master plan allows because Zone 9's mechanics reuse the drag-tile framework.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P4-S40-01 | `feat/z9-pattern-wall` | `pattern_wall.tscn`: tile slots, drag tiles, rule tap | Sequence and figurate skills playable with touch, stylus, mouse, keyboard |
| P4-S40-02 | `feat/z9-proof-board` | `proof_board.tscn`: two staircases into a rectangle, two triangles into a square | Proof skills playable |
| P4-S40-03 | `feat/z9-fib-poem` | `fib_poem.tscn`: six lines, word tiles, glow on correct counts; Scholar-mode free text via `KeyboardEntry` | Poems save per profile (text only) |
| P4-S40-04 | `feat/z9-dig-integration` | Rocks routed; hint ladder; Word Gems | Full session on both devices |
| P4-S40-05 | `content/z9-art` | Artist batch; credits | No placeholders |
| P4-S40-06 | `content/z9-voice` | Voice batch (ask first) | Coverage 100% |
| P4-S40-07 | `feat/z9-badge-gauss` | Gauss badge with a 30-second narrated story | Plays once earned |
| P4-S40-08 | `chore/release-1.5` | Full regression; checklist; AAB; internal; staged rollout; tag `v1.5.0-zone9`; store listing update with four new screenshots | Rollout started; Phase 4 retrospective written in `docs/decisions.md` |

**Implementation notes for the agent**

- Pattern tiles and proof tiles reuse the Phase 2 drag-tile framework (`scenes/input/DragTarget.tscn`).
- Free-text poems: store in the profile save as `Array[String]` lines; the schema change needs a migration and Spiro's sign-off (schema change). Nothing from free text is exported unless a parent exports progress.
- If the artist batch slips, ship Zone 9 with placeholder art on the internal track only and hold production until the batch lands; record the slip.

**Tests**

- `tests/zones/test_pattern_wall.gd`, `test_proof_board.gd`, `test_fib_poem.gd` (line glows when count matches; mismatched lines never penalize).
- Full regression; narration coverage for `z9.*`; device matrix with keyboard-only and mouse-only passes.

**Charlie playtest.** Full Zone 9 session. Does he write a Fib poem? Read it back to him with the narration voice if he asks.

---

## Testing and quality

### Generator cross-checks

Every generator in Phase 4 gets a 10,000-problem run in CI (`python tools/crosscheck/run.py --all --n 10000`) plus the seeded GdUnit4 suite. Rules specific to this phase:

| Family | Exact-arithmetic rule | Checker approach |
|---|---|---|
| GCF/LCM/gears | Integers only; `lcm` guarded against overflow | `math.gcd`, `math.lcm` |
| Fractions | `{num, den}` in lowest terms, positive `den`; equality by cross-multiplication; never `float` | `fractions.Fraction` |
| Decimals/percents | `{mantissa, scale}` integers; compare after aligning scale | `decimal.Decimal` with explicit scale |
| Ratio | `{a, b}` in lowest terms; order fixed by the generator | `math.gcd` |
| Negatives | Plain `int`; the gauge handles the sign | Integer arithmetic |
| Exponents/roots | Values capped; roots only of perfect squares | `pow`, `math.isqrt` |
| Bases | Digit arrays, most-significant first | `int(s, base)` and an independent `to_base` |
| Scientific notation | Mantissa normalized to `[1, 10)` with one decimal place | `decimal.Decimal` |
| Sequences/figurate/Fibonacci/Gauss | Integer recurrences; Fibonacci ratio rounded half-up at scale 2 | `fractions.Fraction`, explicit loops |
| Proof matching, poems | No arithmetic; validate ids and syllable sums against data | JSON validation |

Invariants asserted for every generator: `distractors` never equal `answer`, no duplicates, at least two distractors, every `prompt_line_id` exists in `text/lines.csv`, every `misconception_id` exists in `curriculum/misconceptions.json`, the `representation` is one the skill lists, and generation with the same seed is byte-identical (determinism test).

### Scholar-mode and input passes

From Sprint 37 the Friday device matrix adds a **keyboard-only** pass: every Zone 7–8 screen completed on the 2-in-1 in laptop posture with the trackpad disabled, using `KeyboardEntry`. The existing passes stay: touch-only, stylus-only, mouse-only (emulator desktop profile). Every pass is logged in the sprint's Friday notes with the build number.

### Platform update regression (Sprint 38)

The regression suite for the platform update is the union of: all GdUnit4 suites, all cross-checks, lint, debug APK on both devices (all postures), emulator matrix (tablet, resizable/desktop, x86_64 Chromebook), airplane-mode session, previous-version save upgrade, handwriting spot check, and a Play Console pre-launch report with zero crashes. Any failure blocks Zone 9 work.

### Narration coverage

`tests/narration/test_coverage.gd` asserts 100% audio coverage for `z6.*`, `z7.*`, `z8.*`, `z9.*` and every `frag.*` fragment before each content release. `tools/voice/coverage.py --zone NN` is the same check as a CLI for the release checklist. Changing a line's text without regenerating audio fails CI (the `voice_version` mismatch check from Phase 3).

### Accessibility and content checks

- Touch targets ≥ 64 dp via `UI.min_target_px()`; `lint_content.py` flags hard-coded sizes in `scenes/zones/z0[6-9]_*`.
- Color never the only clue: shaded shards carry an icon; lamps show a label as well as glow; gears differ by tooth count label.
- Explorer lines ≤ 12 words; Scholar variants may be longer but are gated.
- Banned-content keywords (bees, honeycomb, cats, dogs, smoke, fire, campfire, torch, alcohol, gambling, shellfish, octopus) fail lint across lines, asset names and `poem_words.json`.

---

## Exit criteria

Phase 4 is complete, and Version 1.5 is released, when all of these hold:

1. Zones 6, 7, 8 and 9 are live in production on Google Play, each released as a content update with a git tag, and the 1.5 staged rollout has reached 100% with no new crash clusters in Play Console vitals.
2. Every Phase 4 generator passes its seeded GdUnit4 suite and the 10,000-problem independent cross-check in CI.
3. The math reviewer has signed off on Zones 6–9 (four entries in `docs/decisions.md`).
4. Narration coverage is 100% for `z6.*` through `z9.*` and all fragments.
5. Scholar mode part 1 (keyboard entry, notation) works behind the gate; Explorer mode is unchanged for profiles that stay in it.
6. The app targets the 2027 Google Play API requirement; `docs/platform-update.md` exists.
7. The Friday device matrix (2-in-1 all postures, tablet, emulators, touch/stylus/mouse/keyboard passes) is green on the 1.5 build.
8. Saves from Version 1.0 and every Phase 4 release load into 1.5 (fixtures in `tests/save/fixtures/`).
9. No new SDK or permission was added; `docs/sdk-audit.md` and the data safety form are unchanged in substance.
10. Charlie has completed one full session in each of Zones 6–9 (or as far as his frontier allows), and the Phase 4 retrospective is written.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Fraction and decimal arithmetic drifts into `float` somewhere (display code, narration splicing) and produces 0.30000000000000004-style bugs | Medium | High (math must be correct) | `Rational` and `{mantissa, scale}` everywhere; lint rule flagging `float` in `scripts/generators/` and `scripts/core/rational.gd`; cross-check with `Fraction`/`Decimal` |
| Charlie's frontier is far below Zone 6 when the zones ship, so playtests test mechanics he can't yet reach | Medium | Medium | Playtest with a "sandbox profile" that has Zones 1–5 marked mastered (parent-area debug toggle, dev builds only); keep content ahead of him by design |
| Artist batches slip against 4-day sprints | Medium | Medium | Brief the artist in Sprint A of each zone; ship to internal with placeholders, hold production |
| Superscript/notation rendering in Godot 4.7 is weaker than assumed | Medium | Low | Composed `Label` scenes (`exponent_display.tscn`) instead of relying on BBCode; verify early in Sprint 35 |
| The yearly platform update forces a Godot minor upgrade mid-roadmap | Low–Medium | High | Check the requirement in Sprint 35, three weeks early; ask Spiro; keep Sprint 38 feature-free |
| Keyboard detection on Android/ChromeOS is unreliable, enabling keyboard entry on a tablet with no keyboard | Medium | Medium | Conservative detection (enable after a key event); numpad always available; parent override |
| Voice cost creeps with four zones plus fragments | Low | Low | Batch per zone; dry run first; Spiro approves each paid run |
| Fib poem word bank includes a banned theme or a word above reading level | Low | Medium | Human review of `poem_words.json`; lint keyword check; reading-level spot check |
| Content updates dismissed by Play review for a changed data-safety answer | Low | High | Nothing in Phase 4 collects data; re-read the form before each release |
| Scope creep from "fun" ideas (gear physics, free-form crystals) | Medium | Medium | Backlog, not sprint; the zone pattern is fixed |

---

## Decisions for Spiro

1. **Confirm Phase 4 after launch.** Recommendation: proceed if the 1.0 review passed and Charlie still plays three days a week.
2. **Superscript rendering approach** (Sprint 35): composed `Label` scene (recommended, predictable) vs. `RichTextLabel` BBCode if 4.7 supports it cleanly. Record in `docs/decisions.md`.
3. **Cross-zone prerequisite for simplest form.** `simplify.fraction.gcf` (Zone 6) needs unit fractions (Zone 7). Recommendation: move `fraction.unit.identify` and `fraction.part.of_whole` into the Zone 6 JSON as preview skills. This is a prerequisite change and needs your sign-off and the reviewer's.
4. **Save-schema changes** for the `interface_mode` profile field (Sprint 37) and saved poems (Sprint 40). Recommendation: approve both with migrations; they are additive.
5. **Keyboard presence detection** (Sprint 37): conservative (after first key event) vs. posture-based. Recommendation: conservative.
6. **Godot version for the platform update** (Sprint 38): patch within 4.7 if possible; only move to 4.8 if the target SDK requires it. Decide when the requirement is known (check in Sprint 35).
7. **Zone 9 compression.** Zone 9 gets two sprints, not three. Recommendation: accept, since it reuses drag tiles, but allow Zone 9 art to land in a 1.5.1 patch if the batch slips.
8. **Paid voice runs**: one approval per zone batch (four approvals), or a standing approval for Phase 4 with a per-run cost cap. Recommendation: per-zone approval, as `CLAUDE.md` requires.
9. **Staged rollout cadence**: 20% → 100% after 48 hours (recommended) or 10% → 50% → 100%.
10. **Badge additions in Phase 4**: Gauss in Sprint 40 (recommended); Fibonacci-themed badge deferred to Phase 5's remaining badges.

---

## Hand-off to Phase 5

Phase 5 (`docs/phases/phase-5-deep-mountain.md`) builds Zones 10–12, completes Scholar mode and adds the web version. Phase 4 leaves these in place for it:

- **Notation scenes** in `scenes/ui/math/`, including the `congruence_display.tscn` stub for `a ≡ b (mod n)`; Zone 10 fills it in.
- **`Rational` and the exact-arithmetic conventions**, which Zone 10's modular arithmetic and Zone 11's Euclidean algorithm extend (add `mod_inverse`, `extended_gcd` to `scripts/core/` in Phase 5, with the same pure-static pattern and independent checkers).
- **`ModeGate`** with four features; Phase 5 adds the rest of Scholar mode (full notation set, reduced narration, Master Miner ranks) by extending the `Feature` enum, not by adding a second gate.
- **`KeyboardEntry`** as the Scholar input path; Zone 11's secret-message feature and Zone 12's proof journal reuse it.
- **The drag-tile proof board** (`proof_board.tscn`), which becomes the base of the Zone 12 Mathematician's Journal.
- **The zone pattern checklist and release checklist**, proven four times; Phase 5 follows them unchanged.
- **`docs/platform-update.md`**, reused in August 2028 during maintenance.
- **Web export readiness:** Phase 4 adds nothing web-specific, but keeps GDScript-only code, no Android-only calls outside `addons/digit_ink` wrappers (the `FakeRecognizer` fallback path is the one the web build will use), and OGG audio, so Sprint 51's web export has no Phase 4 blockers. Any Android-only API introduced in Phase 4 must be wrapped the same way and listed in `docs/decisions.md`.
- **Open backlog items** from Phase 4 retrospectives, triaged into Phase 5 sprints or the long-term backlog by Spiro at the Phase 5 planning session.
