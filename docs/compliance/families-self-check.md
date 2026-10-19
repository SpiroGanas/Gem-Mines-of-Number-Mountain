# Families Policy self-check (P3-S24-07)

**Re-run before every release** (`docs/release-checklist.md`). Copy the "Run" block, fill it in, and keep older runs below it.

The checklist was drafted on 2026-10-19 from the project's understanding of Google Play's Families Policy requirements; it was **not** checked against the live policy page (the cloud session that wrote it has no web access, and the policy changes). Items marked **Spiro: verify** need a person to compare them with the current pages:

- Families Policy: https://support.google.com/googleplay/android-developer/answer/9893335
- Designed for Families / Families Self-Certified Ads SDK program, Data safety help, and the Play Console "Target audience and content" help (follow the links on the page above).

## Run

| | |
|---|---|
| Date | ____ |
| Checked by | ____ |
| Policy page "last updated" date / version seen | ____ |
| Build checked (version name, version code, commit) | ____ |
| `check_manifest.py` output pasted into the release notes | yes / no |

## Checklist

| # | Requirement (paraphrased) | Status | Evidence |
|---|---|---|---|
| 1 | Target audience and content declared accurately in Play Console | Draft ready | `docs/compliance/target-audience.md` (6-8, 9-12) |
| 2 | Content appropriate for children; IARC rating questionnaire completed | Draft ready | `docs/compliance/content-rating.md`; content rules in `CLAUDE.md` enforced by `tools/ci/lint_content.py` |
| 3 | Ads: none, or only from Families Self-Certified ad SDKs, with child-appropriate ads | Met (no ads) | `docs/sdk-audit.md`; no ad SDK; `AD_ID` permission banned (`tools/ci/check_manifest.py`) |
| 4 | Every SDK in the app that handles user data is approved for Families use, and its data practices are disclosed | Met (no such SDK) | `docs/sdk-audit.md`: only the Godot engine, which collects nothing; `tools/ci/check_sdk_audit.py` keeps the table complete |
| 5 | No transmission of device identifiers (advertising ID, Android ID, IMEI, MAC, serial) from children | Met | Nothing is transmitted (no `INTERNET`); the device label is random and local (`DeviceSettings.device_id`) |
| 6 | No precise location; no location permission requested from children | Met | `check_manifest.py` bans `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` |
| 7 | Permissions limited to what the app needs; none of camera, microphone, contacts without a clear need | Met | Presets request no permissions (`tools/ci/test_export_presets.py`); built manifest checked (`check_manifest.py`) |
| 8 | Privacy policy: link in Play Console **and** inside the app; it covers children's data accurately | Policy drafted; **links pending** | `docs/privacy-policy.md` (effective date and contact to fill). In-app: the Phase 3 parent area page shows the policy URL as text (no browser intent); **check it is there.** URL recorded in `docs/decisions.md` once published |
| 9 | Data safety section completed and consistent with the policy | Draft ready | `docs/compliance/data-safety.md`, `docs/compliance/policy-verification.md` |
| 10 | Legal compliance for children's data (COPPA, GDPR, UK Children's Code and local laws) | Met by design (nothing collected) | `docs/privacy-policy.md`, "Children's privacy". **Spiro: verify** no other obligation applies to the developer account's country |
| 11 | No simulated gambling or gambling-like reward mechanics | Met | `CLAUDE.md` rule 9; rare gems from rare numbers (deterministic) |
| 12 | Purchases and links out of the app, if any, are behind a parental gate; no deceptive purchase flows | Met (none exist) | No purchases, no external links (lint rule 9 bans `OS.shell_open` and URLs in game code). The parent area is gated anyway: `docs/compliance/parental-gate.md` |
| 13 | Accounts and sign-in: none required of children; if accounts exist, deletion is offered | Met (no accounts) | No sign-in anywhere |
| 14 | No user-generated content shared with others, no chat | Met | No network |
| 15 | No AR or features that need extra safety notices | Met (none) | |
| 16 | App does not use device features inappropriately for children (background location, face detection, etc.) | Met (none) | |
| 17 | The app meets the current target API level requirement | Met for 2026 (target SDK 36) | `.android-target-sdk`, `tools/ci/test_export_presets.py`; yearly bump: `docs/platform-update.md` |
| 18 | Store listing assets and description appropriate for children; no misleading claims | Draft ready | `marketing/listing.md` (content checks there) |
| 19 | Licences for bundled content allow distribution | **Open** | `assets/CREDITS.md`; the MNIST licence question (CC BY-SA 3.0 on the handwriting training data) is a "Needs Spiro" item in `docs/decisions.md` (Sprint 13) and must be settled before the **public** release |
| 20 | Anything new in the current policy page that this list does not cover | **Spiro: verify** | Add a row per new requirement, with evidence or a backlog item |

Every row needs evidence or a linked backlog item before submission (P3-S24-07 "done when").

## Notes

- Handwriting: recognition is the project's own network running in GDScript, on the device, with strokes kept in memory only (no plugin, no LiteRT, no ML Kit). Older plan text that mentions a `digit_ink` Android plugin or LiteRT is out of date (`docs/decisions.md`, Sprint 13).
- There is no narration and no AI voice in the app (Spiro, 2026-10-19), so no AI-voice disclosure is needed.
