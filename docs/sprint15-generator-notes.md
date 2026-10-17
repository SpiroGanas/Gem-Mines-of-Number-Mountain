# Sprint 15 notes: Zone 4 skills, generators and text

Written by the content/generator half of Sprint 15 (P2-S15-01 to P2-S15-04 and P2-S15-07).
`docs/decisions.md` is deliberately untouched (another branch is editing it): the entries below are
written in its format, ready to paste under a "Zone 4 generator choices (Sprint 15)" heading.

Date of every entry: 2026-10-17.

## Needs Spiro sign-off: prerequisites (P2-S15-01)

Every prerequisite points at Zone 1-3 skills or at earlier Zone 4 skills, and the graph is a DAG
(`tools/ci/curriculum_check.py`, `tests/curriculum/test_skill_graph.gd`). No Zone 1-3 skill was
changed. The math reviewer should check the order below.

| Skill | Prerequisites | Why |
|---|---|---|
| `mult.facts.0_5` | `mult.facts.2_5_10`, `mult.commutative.match` | Builds on Zone 3's equal groups, arrays and skip counting. `mult.facts.2_5_10` already needs `mult.equal_groups.total` and `skip.by_5.to_100`; the commutative match brings in `arr.rows_cols.build`. |
| `mult.facts.6_10` | `mult.facts.0_5` | Next block of tables. |
| `mult.facts.mixed` | `mult.facts.6_10` | All tables together. |
| `div.sharing.equal_shares` | `mult.equal_groups.total`, `mult.facts.2_5_10` | Sharing is the opposite of making equal groups; the 2, 5 and 10 facts keep the first shares easy. |
| `div.facts.by_2_5` | `div.sharing.equal_shares`, `mult.facts.0_5` | Division as the opposite of multiplication. |
| `div.facts.by_6_10` | `div.facts.by_2_5`, `mult.facts.6_10` | |
| `fac.pairs.rectangles` | `mult.facts.0_5`, `arr.rows_cols.build` | The first factor skill: a factor pair is the two sides of a rectangle. |
| `fac.check.is_factor` | `fac.pairs.rectangles`, `div.sharing.equal_shares` | "Goes in with none left over" is sharing with no remainder. |
| `fac.list.find_all` | `fac.check.is_factor`, `div.facts.by_2_5` | Listing needs the quick check and division by 2 to 5. |
| `mul.list.first_k` | `mult.facts.6_10` | Multiples of 2 to 9 need the tables to 9. (Skip counting is already behind `mult.facts.0_5`.) |
| `mul.check.is_multiple` | `mul.list.first_k`, `fac.check.is_factor` | Teaches multiple against factor side by side. |
| `mul.common.first` | `mul.check.is_multiple` | |
| `prime.classify.single` | `fac.list.find_all` | A prime has only two factors, so the child must be able to list factors first. |
| `prime.classify.set` | `prime.classify.single` | |
| `prime.explain.factor_pairs` | `prime.classify.set`, `fac.pairs.rectangles` | Where 1 first appears as a candidate. |

Not done: `mul.*` skills do not depend on the `prime.*` chain, and the `prime.*` chain does not
depend on `mul.*`; the plan did not ask for either link.

## Needs Spiro: new Word Gems, misconceptions and lines

- **Word Gems** `factor`, `multiple`, `prime`, `composite` (zone 4, in `curriculum/vocabulary.json`).
  `array` already existed. The `prime` gem also says "One is not a prime" and "Primes are the
  unbreakable rocks", so the plan's "1 is not prime, with a line and a Word Gem" is met by the gem
  plus the line `z4.prime.one_not_prime`.
- **14 new misconception names** (42 to 56). Each has a parent-facing description and a matching
  `bolt.misconception.<name>` line: `added_factors`, `counted_factors_not_pairs`,
  `factor_not_multiple`, `missing_one_and_n`, `multiple_not_factor`, `multiplied_instead`,
  `no_check_made`, `odd_means_prime`, `off_by_b`, `one_is_prime`, `skip_middle_pair`,
  `square_is_prime`, `two_is_not_prime`, `used_the_product`.
- **Reused names:** `off_by_group`, `digit_swap`, `off_by_one`, `rows_cols_swapped`.
- **Why `added_factors` and not the plan's `added_instead`:** `added_instead`'s targeted hint is
  "Look at the sign. This one takes away", which is wrong for `3 x 4 = 7`. Names are never edited,
  so a new name was added. For the same reason `multiplied_instead` is new (the plan listed it).
- **Plan names not used:** `remainder_ignored` (the plan says "later skills only"; no Zone 4 skill has
  a remainder), and `off_by_one_group` (the shipped name `off_by_group` is used).
- **`no_check_made`** is new and generic: a yes/no answer that no more specific mistake explains.
  Yes/no questions have exactly one wrong answer, so its hint is "Make equal groups. Is anything left over?".

## Decisions (date, decision, why, alternatives)

### 2026-10-17: Zone 4 uses only existing answer widgets (no scenes touched)

- **Decision:** `NumberPad` for facts, counts and the common multiple; `ChoiceButtons` with Yes/No
  (`ui.common.yes` and `ui.common.no`, through `meta.label_lines`) for the check skills; an unordered
  `TileBoard` for "find all the factors" and "find the unbreakable rocks"; an ordered `TileBoard` for
  "the first k multiples"; `ArrayBuilder` (6 by 6) for rectangles.
  `tests/scenes/test_zone4_answer_panel.gd` answers every Zone 4 problem right and wrong through the
  real panel and draws every hint picture.
- **Why:** the brief forbids new widgets. **Widget gaps** (closest mode used):
  1. No "tap every that applies" widget. A fixed-slot tile board shows how many factors there are
     ("Find all {k} factors"), which a real tap-all would not. The count is stated in the prompt so it
     is fair, and the board still makes the child produce the list (a guess is about 1 in 70).
  2. The tile board shows at most 8 tiles, so a number with 8 or more factors (24, 30, 36...) cannot
     be listed with wrong tiles to choose from. `fac.list.find_all` skips them (n up to 30 uses 4, 6,
     8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 25, 26, 27, 28). 24 and 30 are never asked.
  3. A tile board holds one fixed number of slots, so a "wrong board" cannot leave something out and
     stay shorter. Omissions are modelled as a board where the missing numbers are replaced by
     non-factors (see below).
  4. The array builder is 64 dp per cell, so rectangles are limited to 6 by 6 (Zone 3 used 5 by 5).
  5. The Yes/No buttons are labeled with the generic `ui.common.yes`/`ui.common.no` lines.
- **Alternatives:** four-option list buttons ("Which list has all the factors of 12?") would fit the
  three named misconceptions exactly but are recognition, not production (25% guess rate).

### 2026-10-17: How the "find all factors" wrong boards stand for the named mistakes

- **Decision:** the answer is the sorted factors; a wrong answer is a whole board of the same size.
  `missing_one_and_n`: the middle factors plus two non-factors. `skip_middle_pair`: one middle pair
  (f and n / f; a square's middle is one number) replaced by non-factors. `multiple_not_factor`: one
  middle factor replaced by 2n. A wrong board is only added if the tile board still needs 8 tiles or
  fewer (priority: the two non-factor boards, then the multiple).
- **Why:** exact whole-board matching is how targeted hints work; this keeps each hint tied to a
  concrete board. The hit rate on a real child's wrong board will be modest.

### 2026-10-17: Multiplication starts with arrays, zeros only in abstract problems

- **Decision:** `mult.facts.*`: concrete is an array of gems (a rows of b), pictorial is a skip-count
  number line (a hops of b), abstract is the equation alone. `mult.facts.0_5` includes 0 and 1, but
  zero is only drawn in abstract problems (an array or a hop line cannot show 0 groups), and `0 x 0`
  is never asked (it leaves no wrong answer). The hint for a zero fact is a number line with a marker
  on 0 and no hops.
- **Wrong answers:** `off_by_group` (product plus or minus a or b), `added_factors` (a + b),
  `digit_swap` (not when the product ends in 0, so 20 is never offered as 2).
- **Alternatives:** leaving zero out of `0_5` (loses the zero property); drawing zero as an empty
  frame (needs a new visual type).

### 2026-10-17: Division is exact, shown as sharing gems

- **Decision:** `div.*`: concrete shares n gems drawn as single gems (up to 30) or tens and ones
  (above), pictorial puts the multiples of b on a number line, abstract is "What is n / b?".
  Quotients are 2 to 10, so there are no remainders. Wrong answers: `multiplied_instead` (n x b, only
  if three digits at most so the number pad could type it) and `off_by_one` (both neighbours).
- **Why concrete does not show the carts:** showing b carts of q gems would give the answer away; it
  is the rung 2 hint instead.

### 2026-10-17: Factor, multiple and prime shapes

- **`fac.pairs.rectangles`:** "Build a rectangle with {rows} rows. Use {n} gems in all." (one
  answer per problem: `{rows, cols}`), not "build every rectangle" (the array builder gives one
  answer). Pairs are covered over many problems. Rows 2 to 6, columns 1 to 6. Wrong answers:
  `rows_cols_swapped`, `off_by_one` (a column too many or too few).
- **`fac.check.is_factor`:** four kinds with a fixed mapping from the wrong button to a mistake: a
  middle factor (`no_check_made`), 1 or n itself (`missing_one_and_n`), a smaller non-factor
  (`no_check_made`), 2n or 3n (`multiple_not_factor`). About 45% of the answers are Yes.
  Pictorial draws hops of d from 0 with a marker on n; it never asks about 1.
- **`mul.list.first_k`:** the plan's "next 3 multiples" became "first k multiples" (k 3 to 5, no
  numbers given), because "next" needs a shown strip and Zone 3's skip-counting already trains that.
  Wrong boards: `factor_not_multiple` (first k factors of b, only if b has k), `off_by_b` (start a
  multiple late, or count 0 as the first).
- **`mul.check.is_multiple`:** `off_by_b` is "said No to b itself" (left out the first multiple),
  `factor_not_multiple` is "said Yes to a smaller factor of b".
- **`mul.common.first`:** a and b differ, 2 to 9. Wrong: `used_the_product` (when a x b is not the
  answer), `factor_not_multiple` (the biggest number that goes into both), `off_by_b` (one hop of a
  or b away). No pictorial version.
- **`prime.classify.single`:** "Is {n} unbreakable?" 2 to 30 by default (override `max` up to 100 for
  the hardest setting; the skill file ships 30). The number is drawn by kind: 10% the even prime 2, 25%
  an odd prime, 15% an odd composite that is not a square, 15% a square composite, 35% any other even
  composite. The wrong button names the mistake from the number alone (2: `two_is_not_prime`, a
  square: `square_is_prime`, an odd composite: `odd_means_prime`, otherwise `no_check_made`).
  1 is never a candidate. The prompt says "unbreakable"; the Word Gem chip gives "prime".
- **`prime.classify.set`:** six rocks, 2 or 3 primes, always an odd composite or square to trip over.
  The prompt names how many primes ("Find the {k} unbreakable rocks"). The rocks are also stored in
  the prompt params as `r1`..`r6` (unused by the line) so a worked example with the same k is a
  different problem.
- **`prime.explain.factor_pairs`:** two shapes in one skill: "How many factor pairs does {n}
  have?" (a number, 6 x 6 counts once) and "Look at the factor pairs of {n}. Is {n} a prime?"
  (Yes/No, n from 1, with 1 about 20% and 2 about 10%). This is where 1 first appears.
  Its prompt uses the real word "prime"; the classify skills say "unbreakable".

### 2026-10-17: Shared pieces

- `MathUtil` (`scripts/core/math_util.gd`): `is_prime`, `factors`, `prime_factorization`, `gcd`,
  `lcm`, all integer-only. `lcm` divides before it multiplies. Tested against brute-force definitions
  inside the test for every n up to 1,000 (and every pair up to 60).
- `GeneratorKit` gained `array_picture`, `hops_line`, `yes_no_labels`, `ints_of` and
  `pool_size_with`. The older generators keep their own private copies; they were not refactored.
- Python checkers share a small `checkers/numbers.py` of brute-force helpers. It imports nothing from
  the game and nothing from the generators.
- The worked example for multiplication facts reuses the Zone 3 line `z3.hint.example_fact`.
- The plan's name `tools/crosscheck/zone4.py` is superseded by one module per generator, as in Zones 1-3.

## Child text

- 51 lines added: 29 `z4.*` (13 prompts, 15 worked examples and teaching lines such as
  `z4.prime.one_not_prime`, and `z4.prime.name_it`), 8 Word Gem lines and 14 `bolt.misconception.*`
  lines. That is a little under the brief's "about 60" because the 7 `z4.split.*` lines were
  dropped (the coordinator owns them). Sentences are 12 words or fewer (the lint
  warns above that). Numbers are placeholders, and the word "one" is spelled out in lines (never a
  baked digit). Nothing says "Wrong".
- **No `z4.split.*` lines.** The coordinator owns them (the boulder-split screen).
- `z4.prime.name_it` ("Unbreakable rocks have a real name: prime.") is not shown by any screen yet.
  It is for the zone intro or the first prime question; whoever builds that can use it.

## Things outside the brief that had to change

- `tools/ci/curriculum_check.py`: the five generator names were added to `KNOWN_GENERATORS`
  (a one-line change). Without it `test_repository_curriculum_has_no_problems` and the content lint
  fail on any Zone 4 skill. This is in a folder the brief said not to edit, so the merge should
  keep both sides.
- `tests/curriculum/test_skill_graph.gd`, `tests/generators/test_registry.gd`,
  `tools/crosscheck/test_checkers.py`: counts and zone lists updated (45 to 60 skills, 42 to 56
  misconceptions, Zones 1-4 have generators).
- `scripts/generators/generator_kit.gd`: helpers added (see above).

## Not done, and why

- No scene, autoload, adaptive, save or CI change (as instructed). The Adaptive engine will start
  offering Zone 4 skills as soon as the Zone 3 prerequisites are mastered.
- **Handwriting** is not added to any Zone 4 `answer_modes` (another branch decides the list; the
  brief lists handwriting for facts and division in the plan table).
- **Concrete versions** exist only for `mult.facts.0_5`, the division skills and `fac.pairs.rectangles`.
  The prime and multiple skills are pictorial or abstract; the concrete picture of a prime is the
  boulder-split screen, which another branch is building.
- Abstract problems draw no picture until the hint (the Sprint 5 decision, still "Needs Spiro").
- Charlie has not read the sample lines (needs the device).

## Results at the last commit

- GdUnit4, all of `res://tests`: 65 suites, 778 test cases, 0 failures (headless, Godot 4.7.2).
- `python3 tools/crosscheck/run.py --all --n 10000`: 60 skills checked, all passed (15 are Zone 4).
- `python3 -m pytest tools -q` (with `GODOT` set, so the Godot-backed tests ran): 740 passed.
- `python3 tools/ci/lint_content.py`: 0 errors, 0 warnings. `python3 tools/ci/perf_check.py`: 0 problems.
- Mutation spot checks (a wrong multiple in the factor boards, a wrong `a + b` distractor) were
  caught by the Python checker and reverted. They were not committed.
