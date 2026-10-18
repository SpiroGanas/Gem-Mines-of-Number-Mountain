# SDK, plugin and dependency audit

Every third-party dependency, plugin or SDK in the shipped app or the build must be listed here before it is added (CLAUDE.md rule 3). This table feeds Google Play's Data safety form and the Families Policy review. The shipped game requests no `INTERNET` permission and contains no analytics, ads, crash-reporting, accounts or live AI.

| Name | Version | Where used | Ships in app? | Network? | Data handled | License | Approved by | Date |
|---|---|---|---|---|---|---|---|---|
| Godot Engine | 4.7.2-stable | Engine | Yes | No | None | MIT | Spiro | 2026-10-17 |
| Andika font (SIL International) | 6.200 (Regular and Bold) | `assets/fonts/andika/`, loaded by `ExplorerTheme` as the default font | Yes | No | None | SIL Open Font License 1.1 (`assets/fonts/andika/OFL.txt` ships with the fonts) | Spiro | 2026-10-17 |
| GdUnit4 | 6.2.2 | `addons/gdUnit4/`, tests only; excluded from both export presets (`addons/gdUnit4/*` in `exclude_filter`, enforced by `tools/ci/test_export_presets.py`) | No (dev/CI only) | No | None | MIT | Spiro | 2026-10-17 |
| digit_ink (the project's own handwriting reader: `scripts/input/`, weights in `assets/handwriting/digit_net.json`) | v1 (Sprint 13) | Runs in GDScript inside the game; no plugin, no library | Yes (a 283 KB weights file and ordinary GDScript) | No | Stroke points in memory only, discarded when the answer is submitted or erased; never saved, never made into a picture | Project (weights trained on MNIST, credited in `assets/CREDITS.md`; MNIST is CC BY-SA 3.0, **Needs Spiro:** see `docs/decisions.md`, Sprint 13) | Spiro (GDScript inference chosen 2026-10-17) | 2026-10-17 |
| PyTorch + numpy (`tools/handwriting/requirements.txt`) | torch 2.14.1, numpy 2.5.3 (as trained; `torch>=2.4`, `numpy>=2.0`) | Offline training and evaluation of the digit network on the developer's machine | **No** (build-time only; nothing from them is in the app) | Only to fetch MNIST at build time (a public mirror, hash pinned) | MNIST pictures (public), and Charlie's captured digits **only as a test set**, kept in the gitignored `private/handwriting/` | BSD-3-Clause (PyTorch), BSD-3-Clause (numpy) | Spiro (PyTorch chosen 2026-10-17; numpy is used alongside it) | 2026-10-17 |

**Rejected or deferred:**

| Name | Reason |
|---|---|
| Google ML Kit Digital Ink Recognition | Needs a one-time ~20 MB model download (network) and is a third-party data flow to disclose. The Sprint 13 benchmark was skipped on Spiro's decision (2026-10-17); the project's own network is measured instead. |
| Kotlin plugin with LiteRT for recognition | Replaced by running the network in GDScript (Spiro, 2026-10-17): no plugin, no extra SDK to disclose, one code path on every device. |
| Any analytics / crash-reporting SDK | Violates rule 1. Play logs are exported by a parent instead. |
| Google Play Games Services (cloud saves) | Sprint 17: needs a Google sign-in (an account) and a Google SDK, against rule 1 and harder for the Families Policy. Cross-device progress is a parent-exported file instead (Spiro, 2026-10-17). |
| An Android share-sheet plugin | Sprint 17: not needed; Godot's native file dialog opens the system picker, where a parent can choose Drive. No plugin was added. |

**Sprints 16 to 21 added no dependency.** The device id uses Godot's own `Crypto` class (random bytes, no network); the new art and sounds are Kenney CC0 files (assets, credited in `assets/CREDITS.md`, not code); the music is synthesized by the project's own script. `ffmpeg` (already used by `tools/sfx/`) normalized the music's loudness at build time only.
