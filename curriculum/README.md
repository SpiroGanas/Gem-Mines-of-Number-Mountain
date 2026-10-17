# Curriculum data

Human-readable skill graph and vocabulary, checked by the math reviewer without reading code.

| File | What it holds |
|---|---|
| `skills/zNN_<zone>.json` | One file per zone (12 files). `"status": "detailed"` zones carry full skill records; `"status": "outline"` zones carry only `id` and `name` until their sprint. Zones 1-3 are detailed (45 skills, the MVP). |
| `vocabulary.json` | Word Gems: every math term, the zone that introduces it, and the line ids of its name and kid-sized definition in `text/lines.csv`. `picture` is `null` until Sprint 7. |
| `misconceptions.json` | The allowed names for problem distractors, each with a parent-facing description. Generators and tests reject any other name. |
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
- A skill's `generator` must be in `GeneratorRegistry.table()` (scripts/generators/registry.gd) or be one of the generators still listed as not built in `tests/curriculum/test_skill_graph.gd`. The four Zone 1 generators are built; Zone 2 arrives in Sprint 7 and Zone 3 in Sprint 9.
- The generator's `params` are merged with per-problem overrides (`representation`, `difficulty`); a generator never reads anything else.
- Changing prerequisites or removing a skill needs Spiro's sign-off; note it in `docs/decisions.md`.
- Child-facing words (including Word Gem definitions) live in `text/lines.csv`, never here.

Skill map v1 was written in Phase 1, Sprint 2 from the Zone 1-3 table in `docs/phases/phase-1-ramp-up-to-mvp.md` (the shipped files win if the two differ) and the zone skill lists in the Phase 2, 4 and 5 plans.
