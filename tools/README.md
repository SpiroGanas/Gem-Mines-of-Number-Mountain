# Offline tools (Python 3.12)

Build-time only. Nothing here ships in the game.

| Folder | Purpose | Phase |
|---|---|---|
| `sfx/` | `generate_placeholder_sfx.py`: synthesizes the placeholder sound effects and encodes them as OGG (standard library plus `ffmpeg`; deterministic). To be replaced by a licensed CC0 pack once Spiro picks one. | 1 |
| `music/` | `generate_placeholder_music.py`: synthesizes the calm workshop and mine loops as OGG, the same way. | 1 |
| `crosscheck/` | Independent re-computation of generator answers and distractors from exported problem JSON. `export_problems.gd` (run by Godot) writes 10,000 seeded problems per generator as JSON lines; `run.py --all --n 10000` runs the per-generator checkers in `checkers/` (one per generator, 13 for Zones 1–3) on them. Needs `GODOT` set and the project imported. Must not share code with the GDScript generators. Add one checker module and one `CHECKERS` entry per new generator. | 1 |
| `ci/` | `lint_content.py` (hard-coded child strings, `LineEdit` in child scenes, banned content keywords, text-table and curriculum checks, network code), `curriculum_check.py` (skill graph rules, used by pytest and the lint), `perf_check.py` (no allocations in `_process`, OGG audio, exported-size budget), `copy_plugin.py` (Phase 2) | 1–2 |
| `bkt/` | `fit.py`: expectation-maximization fit of BKT parameters from parent-exported play logs | 2 |
| `handwriting/` | Digit-model training and evaluation (MNIST/EMNIST + augmentation), LiteRT export | 2 |
| `voice/` | `generate.py`: narration pipeline (CSV diff by `voice_version`, TTS provider adapter, ffmpeg normalize + OGG) | 3 |

Tests: `python -m pytest tools`. The only third-party Python package is `pytest` (`tools/requirements.txt`); everything else is the standard library.
