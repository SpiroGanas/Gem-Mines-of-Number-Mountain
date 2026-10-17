# SDK, plugin and dependency audit

Every third-party dependency, plugin or SDK in the shipped app or the build must be listed here before it is added (CLAUDE.md rule 3). This table feeds Google Play's Data safety form and the Families Policy review. The shipped game requests no `INTERNET` permission and contains no analytics, ads, crash-reporting, accounts or live AI.

| Name | Version | Where used | Ships in app? | Network? | Data handled | License | Approved by | Date |
|---|---|---|---|---|---|---|---|---|
| Godot Engine | 4.7.2-stable | Engine | Yes | No | None | MIT | Spiro | 2026-10-17 |
| Andika font (SIL) | TBD (Sprint 7) | `assets/fonts/` | Yes | No | None | SIL Open Font License 1.1 | Pending | |
| GdUnit4 | TBD (Sprint 3) | `addons/gdUnit4/`, tests only | No (dev/CI only) | No | None | MIT | Pending | |
| digit_ink (own Kotlin plugin, LiteRT runtime) | TBD (Sprint 13) | `addons/digit_ink/`, `android/plugins/digit_ink/` | Yes (Phase 2) | No | Stroke points in memory only, discarded after recognition | Project / Apache-2.0 (LiteRT) | Pending | |

**Rejected or deferred:**

| Name | Reason |
|---|---|
| Google ML Kit Digital Ink Recognition | Needs a one-time ~20 MB model download (network) and is a third-party data flow to disclose. Benchmark only, in Sprint 13. |
| Any analytics / crash-reporting SDK | Violates rule 1. Play logs are exported by a parent instead. |
