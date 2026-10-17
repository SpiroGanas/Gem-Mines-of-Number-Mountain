# Curriculum data

Human-readable skill graph and vocabulary, checked by the math reviewer without reading code.

- `skills/zNN_<zone>.json` — one file per zone. Each skill: `id` (`topic.subtopic.action`), `prereqs`, `generator`, `params`, `representations`, `terms`, `answer_modes`.
- `vocabulary.json` — Word Gems: every math term with its kid-sized definition and picture reference.
- `bkt_defaults.json` — Bayesian Knowledge Tracing parameter defaults per skill type (do not change without asking Spiro).

Prerequisites must form a directed acyclic graph; a test in `tests/` enforces this.
Skill map v1 (Zones 1–3 in detail, Zones 4–12 outlined) is written in Phase 1, Sprint 2. See `docs/phases/phase-1-ramp-up-to-mvp.md`.
