# digit_ink: Android handwriting-recognition plugin (Phase 2, Sprint 13)

Kotlin Gradle project that exposes on-device digit recognition (LiteRT) to Godot through the Android plugin system. One digit per box; returns `{digit: int, confidence: float}`. Strokes are discarded after recognition and never stored.

Build with `./gradlew assembleRelease`, then `python tools/ci/copy_plugin.py` copies the AAR into `addons/digit_ink/bin/`. See `docs/phases/phase-2-version-1-0.md`.
