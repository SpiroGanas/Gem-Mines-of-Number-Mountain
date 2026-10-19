# Yearly platform update (Sprint 38 procedure, reused every year)

Google Play raises the required target API level every year, with the deadline usually on **August 31** for updates to existing apps. This page is the procedure (from `docs/phases/phase-4-middle-mountain.md`, "Yearly platform update procedure", corrected for the build as it is). Budget a full sprint, keep the branch feature-free, and do not start the next zone until the regression passes.

**Pinned today:** Godot `4.7.2-stable` (`.godot-version`), target SDK **36** (`.android-target-sdk`), ABIs `arm64-v8a` + `x86_64`, no permissions, phones excluded (`screen/support_small` and `screen/support_normal` off). `tools/ci/test_export_presets.py` fails if the presets drift from these pins or if CI installs a different SDK platform than `.android-target-sdk` names.

## Godot version policy

- **Stay on 4.7.x.** A newer 4.7 patch (4.7.3, ...) is the first choice when one is needed: patches keep the scene format and the GDScript language, and the Android export template is replaced as a whole.
- **Move to 4.8 only if 4.7.x cannot target the required SDK**, and only after asking Spiro (`CLAUDE.md`: never upgrade Godot without asking). Decide when the requirement is known; check it about three weeks ahead (the Phase 4 plan checks in Sprint 35).
- Record the decision (version, why, what was checked) in `docs/decisions.md`.

## Procedure

1. **Read the requirement.** Play Console's "target API level requirements" help page, and the Godot Android export docs for the pinned 4.7.x (which target SDK the export template supports, and the recommended JDK and build tools). Note the required target SDK and the lowest Godot version that supports it.
2. **Decide on Godot** (policy above). Ask Spiro before any upgrade.
3. **Branch** `chore/platform-update-YYYY`. Update the toolchain:
   - Godot, if upgraded: `.godot-version`, `GODOT_VERSION` in `.github/workflows/ci.yml`, the local `GODOT` path; then re-install the Gradle build template (`"$GODOT" --headless --path . --install-android-build-template --export-debug "Android" build/gem-mines-debug.apk`, as CI does; `android/build/` is gitignored and made per machine).
   - Android SDK: `sdkmanager "platforms;android-NN" "build-tools;NN.0.0"`, locally and in the `android-debug` CI job (both the `sdkmanager` line and the `aapt2` path).
   - JDK only if the Godot docs changed the recommendation (today 17, Temurin).
4. **Bump the target SDK in one commit:** `.android-target-sdk`, `gradle_build/target_sdk` in **both** presets, and the CI SDK packages. `python -m pytest tools/ci/test_export_presets.py` must pass. Keep `gradle_build/min_sdk` at Godot's default. Diff `export_presets.cfg` and confirm nothing else changed: ABIs, permissions (none, no `INTERNET`), screen sizes (phones excluded), `user_data_backup/allow=false`. Export settings are on the "ask Spiro" list; the target SDK bump is the approved purpose of this sprint, anything else in the diff is not.
5. **Re-run the SDK audit** (`docs/sdk-audit.md`, `python tools/ci/check_sdk_audit.py`): the Godot version row, and confirm nothing new arrived. There is **no Android plugin to rebuild**: handwriting runs in GDScript (`scripts/input/`, weights in `assets/handwriting/digit_net.json`); `android/plugins/digit_ink/` is an empty placeholder. (The Phase 4 plan's "rebuild the digit_ink AAR and its LiteRT dependency" step predates that decision and does not apply.)
6. **Full regression** (any failure blocks the next zone):
   - `--import`, all GdUnit4 suites, `python -m pytest tools`, the cross-check (`--all --n 10000`, and `--difficulty -1` / `-2`), `lint_content.py`, `curriculum_check.py`, `perf_check.py`.
   - Export the release AAB and run `python tools/ci/check_manifest.py build/gem-mines.aab` (no banned permission, phones excluded). Check the manifest's `targetSdkVersion` is the new value (bundletool's dump, or `aapt2 dump badging` on the debug APK).
   - Debug APK on both of Charlie's devices: every posture, touch, stylus and keyboard; the mouse-only pass; the emulator matrix (`tools/ci/emulators.md`); an airplane-mode session; a handwriting spot check (20 digits per device).
   - **Old save:** install the previous production build, play one rock, update to the new build, confirm progress and every profile are intact.
   - Play Console pre-launch report with zero crashes.
7. **CI:** green on the branch, including the `android-debug` job (run it with `workflow_dispatch`).
8. **Release** through `docs/release-checklist.md` as a maintenance update (version name like `1.4.1`, tag `v1.4.1-platform`): staged rollout at 20%, watch vitals for 48 hours, then 100%.
9. **Data safety and privacy policy:** re-read both (`docs/compliance/data-safety.md`, `docs/privacy-policy.md`). A platform update should change nothing; the review confirms it. Re-run `docs/compliance/families-self-check.md`.

## If a step fails

- The pinned Godot cannot target the new SDK and Spiro has not yet approved an upgrade: stop at step 2 and raise it; there is time until August 31 only if this starts early.
- A Godot upgrade changes `.tscn` formats: let the editor re-save the scenes in one dedicated commit and review that diff for `uid://` changes (never hand-edit uids).
- A regression on a device: fix it in this branch only if it is caused by the update; anything else goes to the backlog.
