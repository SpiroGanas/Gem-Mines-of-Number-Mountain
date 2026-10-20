# Curriculum data

Human-readable skill graph and vocabulary, checked by the math reviewer without reading code.

| File | What it holds |
|---|---|
| `skills/zNN_<zone>.json` | One file per zone (12 files). `"status": "detailed"` zones carry full skill records; `"status": "outline"` zones carry only `id` and `name` until their sprint. Zones 1-3 are detailed (45 skills, the MVP), and so are Zone 4, Factor Workshop (16 more, Sprint 15), and Zone 5, Prime Caverns (11 more, Sprint 18). Phase 4: Zone 6, Gear Works, is detailed (12 skills, Sprint 29, plus the fraction preview skills `fraction.unit.identify` and `fraction.part.of_whole`, 14 in all) and so is Zone 7, Crystal Shards (18 skills, Sprint 32); fraction, decimal and ratio answers are exact Dictionaries, see `scripts/core/rational.gd`. Zone 9, Pattern Grotto, is detailed too (15 skills, Sprint 39); Zone 8 is built on its own branch. |
| `vocabulary.json` | Word Gems: every math term, the zone that introduces it, and the line ids of its name and kid-sized definition in `text/lines.csv`. `visual` is the small picture on the Word Gem card (a problem visual, drawn by the mine's visual model); `picture` stays `null` until commissioned art. |
| `misconceptions.json` | The allowed names for problem distractors, each with a parent-facing description. Generators and tests reject any other name. |
| `poem_words.json` | Zone 9: the Fib poem word bank. Each word's tile text is a line in `text/lines.csv` (`z9.word.<id>`) and its `syllables` were counted by a person; the game only adds them up. Words with two common pronunciations are left out. **Needs Spiro's review.** |
| `proof_diagrams.json` | Zone 9: the proof-without-words diagrams (`proof.words.match`): id, the fact line its button reads, the sizes it is drawn at, and a grown-up explanation. |
| `bkt_defaults.json` | Bayesian Knowledge Tracing parameters per skill type, plus `hint_weight` and the fact-skill `fluency_ms`. **Do not change without asking Spiro.** |

## Skill record (detailed zones)

```json
{
  "id": "pv.tens_ones.build",              // topic.subtopic.action; never renamed once shipped
  "name": "Build a number with tens and ones",   // parent-facing name (dashboard); not shown to the child
  "prereqs": ["count.to_120.read"],        // must form a directed acyclic graph
  "generator": "PlaceValueGenerator",      // class in scripts/generators/, listed in GeneratorRegistry.table()
  "params": {"mode": "build", "min": 11, "max": 99},
  "representations": ["concrete"],         // concrete, pictorial, abstract
  "answer_modes": ["drag"],                // tap, drag, number_pad, keyboard
  "terms": ["tens", "ones"],               // Word Gem ids in vocabulary.json
  "bkt_type": "concept",                   // key into bkt_defaults.json
  "is_fact_skill": false,                  // true enables the hidden fluency check (needs bkt_type "fact")
  "misconceptions": ["digit_swap", "counted_tens_as_ones"]   // names from misconceptions.json
}
```

The comments above are for explanation only; JSON files contain none.

## Rules

- Prerequisites form a DAG, only point at the same or an earlier zone, and never at an outline-only skill. `python -m pytest tools` enforces this (`tools/ci/curriculum_check.py`).
- A term may not be used by a skill in an earlier zone than the one that introduces it.
- A skill's `generator` must be in `GeneratorRegistry.table()` (scripts/generators/registry.gd) or be listed as not built in `tests/curriculum/test_skill_graph.gd`. Every Zone 1–5 generator is built.
- Every misconception name needs Bolt's targeted hint line, `bolt.misconception.<name>`, in `text/lines.csv`.
- The generator's `params` are merged with per-problem overrides (`representation`, `difficulty`); a generator never reads anything else, except the two Zone 9 data files above (`ProofGenerator`, `FibPoemGenerator` read them, and their checkers read the same files).
- Changing prerequisites or removing a skill needs Spiro's sign-off; note it in `docs/decisions.md`.
- Child-facing words (including Word Gem definitions) live in `text/lines.csv`, never here.

Skill map v1 was written in Phase 1, Sprint 2 from the Zone 1-3 table in `docs/phases/phase-1-ramp-up-to-mvp.md` (the shipped files win if the two differ) and the zone skill lists in the Phase 2, 4 and 5 plans.
