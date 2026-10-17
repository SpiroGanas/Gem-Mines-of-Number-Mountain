# Tests

GdUnit4 suites mirroring `scripts/` and `scenes/`. GdUnit4 is installed in Phase 1, Sprint 3 (see `docs/phases/phase-1-ramp-up-to-mvp.md`); until then this folder only holds the layout.

- `generators/` — seeded tests per problem generator (10,000-problem runs, edge cases, distractor rules).
- `adaptive/` — BKT unit tests and simulated-learner suites (random guesser never masters; fast learner tests out).
- `save/` — migration tests; `save/fixtures/` holds one save file from every past schema version.
- `scenes/` — scene-loading and input-mode smoke tests.

Run everything: `GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh -a res://tests`
