# digit_ink: not used

The plan once called for a Kotlin plugin here that ran a LiteRT digit model. On 2026-10-17 Spiro chose to run the network in GDScript instead (`docs/decisions.md`, Sprint 13), so there is no Android plugin, no LiteRT and no ML Kit. Handwriting recognition lives in:

- `scripts/input/` (`StrokeRaster`, `DigitNet`, `NetRecognizer`, `FakeRecognizer`, `DigitInk`)
- `assets/handwriting/digit_net.json` (the weights)
- `tools/handwriting/` (training and evaluation, PyTorch, build-time only)

This folder is kept empty on purpose so a plugin could be added later if a device ever needs one.
