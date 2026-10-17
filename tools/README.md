# Offline tools (Python 3.12)

Build-time only. Nothing here ships in the game.

| Folder | Purpose | Phase |
|---|---|---|
| `crosscheck/` | Independent re-computation of generator answers from exported problem JSON (`run.py --all --n 10000`). Must not share code with the GDScript generators. | 1 |
| `ci/` | `lint_content.py` (hard-coded child strings, `LineEdit` in child scenes, banned content keywords), `copy_plugin.py` | 1–2 |
| `bkt/` | `fit.py`: expectation-maximization fit of BKT parameters from parent-exported play logs | 2 |
| `handwriting/` | Digit-model training and evaluation (MNIST/EMNIST + augmentation), LiteRT export | 2 |
| `voice/` | `generate.py`: narration pipeline (CSV diff by `voice_version`, TTS provider adapter, ffmpeg normalize + OGG) | 3 |

Tests: `python -m pytest tools`
