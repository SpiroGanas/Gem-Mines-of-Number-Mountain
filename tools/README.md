# Offline tools (Python 3.12)

Build-time only. Nothing here ships in the game.

| Folder | Purpose | Phase |
|---|---|---|
| `sfx/` | `generate_placeholder_sfx.py`: synthesizes the placeholder sound effects and encodes them as OGG (standard library plus `ffmpeg`; deterministic). The game plays Kenney's CC0 sounds since 2026-10-17 (`assets/sfx/kenney/`); this stays as a fallback that can synthesize a stand-in for any sound. | 1 |
| `music/` | `generate_placeholder_music.py`: synthesizes the calm workshop and mine loops as OGG, the same way. | 1 |
| `crosscheck/` | Independent re-computation of generator answers and distractors from exported problem JSON. `export_problems.gd` (run by Godot) writes 10,000 seeded problems per generator as JSON lines; `run.py --all --n 10000` runs the per-generator checkers in `checkers/` (one per generator, 13 for Zones 1–3) on them. Needs `GODOT` set and the project imported. Must not share code with the GDScript generators. Add one checker module and one `CHECKERS` entry per new generator. | 1 |
| `ci/` | `lint_content.py` (hard-coded child strings, `LineEdit` in child scenes, banned content keywords, text-table and curriculum checks, network code), `curriculum_check.py` (skill graph rules, used by pytest and the lint), `perf_check.py` (no allocations in `_process`, OGG audio, exported-size budget), `copy_plugin.py` (Phase 2) | 1–2 |
| `bkt/` | `fit.py`: expectation-maximization fit of BKT parameters from a parent-exported bundle (writes `curriculum/bkt_fitted.json`; the game uses a skill's fitted values from 30 first tries). `gate_report.py`: the decision-gate numbers (days per week, mastered by week, ceiling and floor skills, answers by input) as Markdown. Standard library only. | 2 |
| `handwriting/` | The digit network: `raster.py` (strokes to the 28x28 picture; twin of `scripts/input/stroke_raster.gd`), `thin.py`, `augment.py`, `train.py` (PyTorch), `export_weights.py` (writes `assets/handwriting/digit_net.json`), `evaluate.py` (accuracy and confidence sweep), `make_fixtures.py` (GDScript parity fixtures), `synth.py`, `dataset.py` (MNIST fetched at build time; `private/handwriting/` optional). Needs `pip install -r tools/handwriting/requirements.txt` (numpy, PyTorch) to train; the rest runs on numpy. | 2 |
| `voice/` | `generate.py`: narration pipeline (CSV diff by `voice_version`, TTS provider adapter, ffmpeg normalize + OGG) | 3 |

Tests: `python -m pytest tools`. CI installs only `pytest` (`tools/requirements.txt`); the handwriting tests need numpy and skip the PyTorch and MNIST ones when those are missing. Training needs `tools/handwriting/requirements.txt` (numpy, PyTorch; build-time only).
