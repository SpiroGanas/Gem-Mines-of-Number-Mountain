# Google Play Data safety form: answers and reasoning (P3-S24-02)

Drafted 2026-10-19 against the code on the Phase 3 branch. **Spiro:** enter these in Play Console (App content > Data safety) and re-read Google's current help text for each question while doing so ("Provide information for Google Play's Data safety section"); the form's wording changes. Record the date entered here: ____.

Review this against the manifest check output of the build being submitted (`python tools/ci/check_manifest.py build/gem-mines.aab`), and against `docs/privacy-policy.md` via `docs/compliance/policy-verification.md`.

## The facts the answers rest on

| Fact | Evidence |
|---|---|
| The app requests no `INTERNET` permission, and no other dangerous permission | Both export presets have `permissions/internet=false` and no custom permissions (`tools/ci/test_export_presets.py`); the built APK is checked by `tools/ci/check_manifest.py` (CI job `android-debug`) and by `aapt2 dump permissions` |
| No network code in the game | `tools/ci/lint_content.py` fails on network classes (`HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, ...) in game code; the Godot engine contains such classes, but without `INTERNET` Android blocks every socket |
| No third-party SDK in the APK besides the Godot engine | `docs/sdk-audit.md`; GdUnit4 (tests) is excluded from both presets |
| Nothing leaves the device unless a parent exports a file | `SaveSystem.export_bundle` is called only from the parent dashboard (`scenes/shell/parent_area/dashboard.gd`), behind the parental gate, through Android's own file picker (`FileDialog`, native) |
| Handwriting strokes stay in memory and are discarded | `scenes/input/chalk_slate/` and `scripts/input/` (`StrokeRaster`, `DigitNet`); recognition runs in GDScript. There is **no** `digit_ink` Android plugin and no LiteRT runtime (decision of 2026-10-17; `android/plugins/digit_ink/` is an empty placeholder). The only code that saves strokes is the capture screen, which exists only in debug builds (`StrokeCapture.is_enabled` requires `OS.is_debug_build()`), never in a release AAB |
| Android auto backup is off | `user_data_backup/allow=false` in both presets (writes `android:allowBackup="false"`) |
| The device id is random, local and not a hardware or advertising ID | `DeviceSettings.device_id()` (`scripts/core/device_settings.gd`): random bytes from Godot's `Crypto`, stored in `user://device_settings.cfg` |

Google's definitions (as of drafting): data is **collected** when it is transmitted off the device by the app; data processed only on the device is not collected. Data is **shared** when it is transferred to a third party. A user-initiated transfer that the user reasonably expects (here, a parent saving a file to a place they pick) is not sharing. **Spiro to confirm both definitions against the live help page.**

## Top-level questions

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Nothing is transmitted off the device by the app. The parent's export writes a file through the system file picker; any upload after that is done by the app the parent chooses (for example Drive), at the parent's request |
| Is all of the user data collected by your app encrypted in transit? | Not asked once "No" is answered above (if asked: not applicable, nothing is transmitted) | |
| Do you provide a way for users to request that their data is deleted? | Not asked once "No" is answered above. The policy still explains deletion: delete the profile, or uninstall | |
| Has the app been independently security reviewed (MASA)? | No (optional) | |
| Is the app designed for children / follows the Families Policy? | Yes (shown as a badge when the target audience includes children) | `docs/compliance/target-audience.md` |

## Per data type (why each is "not collected")

| Play data type | What the app does | Collected? | Shared? |
|---|---|---|---|
| Location (approximate, precise) | Never accessed; no location permission (checked by `check_manifest.py`) | No | No |
| Personal info: name | A parent may type a nickname for a profile (Phase 3 profiles). Stored on the device only; included in a parent's export file | No (stays on device) | No |
| Personal info: email, user IDs, address, phone, race, political or religious beliefs, sexual orientation, other | None; there are no accounts | No | No |
| Financial info | None; no purchases | No | No |
| Health and fitness | None | No | No |
| Messages | None; no chat | No | No |
| Photos and videos | None; no camera permission; handwriting is never made into a picture | No | No |
| Audio files, voice or sound recordings, music files | None; no microphone permission; the game's own music ships in the APK | No | No |
| Files and docs | Only the progress file a parent picks to export or import, written or read through the system picker at the parent's request | No | No |
| Calendar, Contacts | None; no permissions | No | No |
| App activity: app interactions, in-app search, installed apps, other user-generated content, other actions | Answer history and progress are stored on the device to adapt the next problem; never transmitted | No (on-device processing) | No |
| Web browsing | None; no browser, no links | No | No |
| App info and performance: crash logs, diagnostics, other | No crash reporting or diagnostics leave the device | No | No |
| Device or other IDs | A random device label stored on the device; written into export files to tell devices apart. No Android ID, IMEI or advertising ID is read; no `AD_ID` permission (checked by `check_manifest.py`) | No | No |

## If the build changes

Re-answer this form when any of these change: a permission in the manifest check output, a new entry in `docs/sdk-audit.md`, anything that transmits data (which would also break `CLAUDE.md` rule 1 and needs Spiro), or what the export file contains (for example the Phase 3 "Copy diagnostics" helper, which puts text on the clipboard for a parent to paste; clipboard text the parent pastes elsewhere is a user action, but list what it contains in the policy).
