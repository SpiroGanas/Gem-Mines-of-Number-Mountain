# How to add a zone

A checklist for adding a zone (or deepening one) in this repo. Zones 10 and 11 were built this way and are the best examples: read their diff (`git show 0dec000 --stat`). **Read `CLAUDE.md` first**: its rules (no network, text from the text table, wrong answers never cost anything, 64 dp targets, independent math checkers, ask before changing prerequisites, schema, export or dependencies) apply to every step.

> If you are following this guide to build a throw-away stub "Zone 13" to test the guide, delete the branch afterwards. Nothing from it merges.

## 1. The pattern

Three steps, usually one branch each: **(1) curriculum and generators** (skill graph, pure generators, tests, independent Python checkers, text lines, Word Gems), **(2) mechanics and project** (input scenes, pictures, the build project, badges), **(3) look, sound and polish** (palette and banner, music loop, layout checks on phone and tablet shapes). Nothing in step 2 starts before step 1's checks pass. Record the zone in `docs/decisions.md` (date, decision, why, alternatives, a "Needs reviewer" line) and update `status.md` in the same commit.

## 2. Curriculum file

`curriculum/skills/zNN_name.json`, with `zone`, `zone_id`, `name`, `status: "detailed"` and a `skills` list. One record:

```json
{"id": "cipher.caesar.encode", "name": "Encode with a Caesar shift", "prereqs": ["mod.add.wrap"],
 "generator": "CipherGenerator", "params": {"mode": "caesar_encode", "min_len": 3},
 "representations": ["concrete", "abstract"], "answer_modes": ["tap"], "terms": ["cipher"],
 "bkt_type": "procedure", "is_fact_skill": false, "misconceptions": ["shifted_backward"]}
```

- IDs are `topic.subtopic.action` (lowercase, underscores) and are never renamed. Prerequisites must form a DAG; `tests/curriculum/test_skill_graph.gd` and `tools/ci/curriculum_check.py` enforce it. Point the zone's first skills at a skill in the zone before it so the zone opens in order (see `tests/curriculum/test_zone11_order.gd`).
- `representations` run concrete, pictorial, abstract, in the order a child meets them. `bkt_type` keys into `curriculum/bkt_defaults.json`. New misconception names go in `curriculum/misconceptions.json`.
- **Changing prerequisites of an existing skill needs Spiro's sign-off** and a decisions entry.
- Add the generator class name to `KNOWN_GENERATORS` in `tools/ci/curriculum_check.py`.

## 3. Generators

Contract (`scripts/generators/generator_kit.gd` has the shared helpers): a pure `static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem`. No nodes, no globals, **only the passed `rng`** (never `randi()`), so a seed always gives the same problem. Use `GeneratorKit.new_problem`, `pick_representation`, `difficulty_of` / `eased_max` (hint rung 4 asks for easier problems with difficulty -1 and -2), `add_distractor` (rejects a distractor equal to the answer, a repeat, or a name the skill does not list) and `add_hints` (all four hint rungs).

Steps:

1. Write the GdUnit4 test first in `tests/generators/` with fixed seeds and edge cases. `generator_checks.gd` holds invariants shared across suites.
2. Write `scripts/generators/<name>.gd` (`class_name XGenerator`) and add one line to `table()` in `scripts/generators/registry.gd`.
3. Write the **independent Python checker** `tools/crosscheck/checkers/<name>.py` with `check(problem: dict) -> list[str]`. It recomputes the answer and the distractors from the exported JSON with a different method (e.g. `pow(a, -1, 26)` against a brute-force search; Python `%` against `posmod`). It must not import or port the generator's code. Register it in `tools/crosscheck/run.py` and add pytest tests (`tools/crosscheck/test_checkers_zoneNN.py`) showing it rejects a wrong answer.
4. Run it: `python tools/crosscheck/run.py --all --n 10000`, plus `--difficulty -1` and `--difficulty -2`. One skill: `--skill cipher.caesar.encode --n 500 --seed 7`.
5. A new picture type goes into `Problem.VISUAL_TYPES`, both validators (GDScript and Python), the Word Gem picture list and `scenes/mine/visual_model.gd`.

## 4. Text and vocabulary

- Every child-facing string is a row in `text/lines.csv` (`id,text,context,voice_version,mode`), through `Text.get_line(&"id", params)`. ID format `zone.context.purpose`, e.g. `z11.euclid.prompt_gcd`; never reuse or rename an ID. `voice_version` is always `0` (no narration). Numbers are placeholders (`{n}`), never baked in. Explorer lines: 12 words or fewer per sentence, first-grade words, one instruction per line, "Not quite. Let's look again." for feedback.
- Each math term is a Word Gem in `curriculum/vocabulary.json` (term, definition, optional picture), defined the first time it appears; lint rule 11 fails if a line uses a term that is not a Word Gem.
- Run `python tools/ci/lint_content.py`. It also checks the banned content list (alcohol, gambling, smoking, smoke or fire effects, bees, pets, shellfish and octopus), the 12-word rule, line references in code and credits for every asset.

## 5. Scenes

- Layout: `scenes/zones/zNN_name/` for the zone's inputs and widgets, `scenes/workshop/builds/<build>/` for its project. A mechanic is an input mode under `drag`/`tap` in `scenes/mine/answer_panel.gd` (see how `WHEEL_SCENE` and `COINS_SCENE` are chosen from `problem.meta`); the mine loads zones through the skill catalogue, so no per-zone wiring is needed for the dig itself.
- Child answer input never uses `LineEdit`/`TextEdit` (rule 6). Interactive targets are at least `UI.min_target_px()`. Drag must work the same with finger, pen and mouse, through `InputRouter`; give every drag a tap alternative.
- Art is drawn in code (a `*_art.gd` per zone). Zone look: a palette entry in `scenes/shell/backdrop.gd` (raise `LAST_PALETTE_ZONE`), the banner name line `zNN.zone.name`, the celebration line `zNN.zone.done`, and a music loop (add a `mine_zNN` entry to the `TRACKS` dictionary in `tools/music/generate_placeholder_music.py`, then run it with `--track mine_zNN`; a track mapping in `scenes/mine/mine.gd`; a `assets/CREDITS.md` row).
- Check small shapes: `tests/scenes/test_phone_layout.gd` loads screens at phone and tablet sizes; add yours.

## 6. Rewards

Gems come from the value of the rock's number, not the zone; rare gems come from rare numbers (`curriculum/rare_numbers.json`) - deterministic, never chance. Badges: add an entry to `curriculum/badges.json` (unlock = skills mastered, a code-drawn `emblem`, story lines in `lines.csv`; never rename IDs). Builds: `curriculum/builds.json` (`zone_unlocks`, `locks_zone`, `unlock_after_skill`), a scene that shows each step as a real problem, progress saved after every step. Anything that needs a new saved field is a **save schema change**: stop and ask Spiro; it needs a migration in `scripts/save/migrations/` and a fixture test.

## 7. Math reviewer hand-off

`"$GODOT" --headless --path . res://tools/qa/math_review_packet.tscn -- --zones 12 --samples 30` writes `docs/reviews/math-review-packet-z12.md`: sample problems with wording and answers for every skill. Add a "Needs reviewer" entry in `docs/decisions.md` listing the skills, prerequisites, wording, Word Gem definitions and new misconception names. Reviewer findings go in that entry, and `docs/curriculum-data-guide.md` tells the reviewer how to read the files.

## 8. Before you call it done

- [ ] GdUnit4: the new suites and the full run (`GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests`).
- [ ] `python tools/crosscheck/run.py --all --n 10000` (and `--difficulty -1`, `-2`), `python -m pytest tools`.
- [ ] `python tools/ci/lint_content.py`, `curriculum_check.py`, `perf_check.py`, `check_sdk_audit.py`.
- [ ] Phone, tablet and mouse-only shapes checked; `docs/release-checklist.md` device passes before a public release.
- [ ] `status.md` and `docs/decisions.md` updated; README zone table updated.
