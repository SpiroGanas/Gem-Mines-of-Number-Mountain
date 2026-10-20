# Privacy policy verification (Phase 3, "Testing and quality")

For each claim in `docs/privacy-policy.md`, the evidence that the build does what it says. Re-run when the policy, the manifest or the save contents change, and before every store submission. If a code path contradicts the policy, that is a bug to fix, not a sentence to change (`CLAUDE.md` rule 2).

Run: date ____, build ____, by ____.

| Policy claim | Evidence | Checked |
|---|---|---|
| No internet access | `python tools/ci/check_manifest.py build/gem-mines.aab` prints no `INTERNET`; presets `permissions/internet=false` (`tools/ci/test_export_presets.py`) | |
| No ads, analytics, crash reporting, accounts | `docs/sdk-audit.md`; `tools/ci/check_sdk_audit.py`; lint rule 9 (no network code) | |
| What is stored per profile: nickname, avatar, starting grade, progress and answer history, rewards, settings, family points | Save schema `scripts/save/save_schema.gd` (Phase 3 v3 adds the profiles list; **check the v3 fields when the profiles work lands**); attempt fields `scripts/core/attempt.gd` `to_json` | |
| Device-wide: volumes, handwriting on/off, random device label, import/export log, up to five backups | `scripts/core/device_settings.gd`; `autoload/save_system.gd` (`BACKUP_DIR`, `SYNC_LOG_FILE`, the newest-5 rule) | |
| Device label is random, not a hardware or Google ID | `DeviceSettings.device_id` / `random_uuid` (Godot `Crypto` random bytes) | |
| Android auto backup is off | Presets `user_data_backup/allow=false`; manifest dump shows `android:allowBackup="false"` | |
| Handwriting strokes in memory only, discarded on submit or erase; no picture saved | `scenes/input/chalk_slate/`, `scripts/input/stroke_raster.gd` (28x28 input made in memory and dropped), `tests/input/test_chalk_slate.gd`; `StrokeCapture` (the only stroke writer) is debug-build only (`StrokeCapture.is_enabled`) | |
| No location, contacts, camera, microphone, advertising ID | `check_manifest.py` bans their permissions | |
| Data leaves only by a parent's export, behind the gate, through the system file picker | `SaveSystem.export_bundle` called only from `scenes/shell/parent_area/dashboard.gd`; the dashboard is reached only through `parent_gate` (`tests/scenes/test_shell.gd`) | |
| Export file holds the profile (with the nickname) and the answer history | `scripts/save/progress_bundle.gd` (`make`) | |
| Delete one child: delete the profile in the parent area | Phase 3 profiles work (**check when it lands**, including any "recently deleted" step) | |
| Uninstall removes everything | All data lives under `user://` (app-private storage); nothing is written elsewhere except files the parent exports | |
| Third parties: only the Godot engine; font and art files | `docs/sdk-audit.md`, `assets/CREDITS.md` | |
