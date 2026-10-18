# Version 1.0 release checklist (Sprint 21, P2-S21-03 to 05)

Version 1.0 (private) goes to the Google Play internal testing track when every box below is ticked. The automated half runs in CI and on the dev machine; the device half needs both of Charlie's devices.

## 1. Automated (any machine; paste the output into the release notes)

- [ ] `"$GODOT" --headless --path . --import`
- [ ] `GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh -c -a res://tests` (all suites green; includes the save fixtures v1 and v2 migrating and loading, the cross-device round trip, the simulated learners with the Challenge Door, and the readability audit of every screen)
- [ ] `python -m pytest tools`
- [ ] `python tools/crosscheck/run.py --all --n 10000` (all 72 skills of Zones 1-5)
- [ ] `python tools/ci/lint_content.py` and `python tools/ci/curriculum_check.py`
- [ ] `python tools/ci/perf_check.py` (exported size well under 150 MB)
- [ ] The Android preset still requests no `INTERNET` permission (`python -m pytest tools/ci/test_export_presets.py`)
- [ ] Regenerate `docs/reviews/math-review-packet-z1-5.md` and `docs/qa/screens-1.0/` if any generator, line or screen changed since the last run (`tools/qa/`)

## 2. Save migration matrix (both devices)

For each tagged release that was ever installed (today: the MVP internal build):

- [ ] Install that build, play a few rocks, craft nothing, close the app.
- [ ] Install 1.0 over it (`adb install -r build/gem-mines-debug.apk`, or the internal-testing update).
- [ ] The child's coins, gems, lantern days and mastered skills are all there; the dashboard shows the skill map; the parent area shows "This device: ..." (a new id).
- [ ] Craft one recipe, finish one build step, close mid-build and reopen: the build resumes at the same step.

## 3. Cross-device round trip

- [ ] 2-in-1: Export progress (parent area). Save the file to Drive or a shared folder.
- [ ] Tablet: Import it. The dashboard says "Progress imported."; the log shows the import.
- [ ] Tablet: play a few rocks; Export. 2-in-1: Import. Progress matches the tablet's; a backup appears (the log says "used the file").
- [ ] Import the first (older) file again on the 2-in-1: the parent is asked; "Keep this device's progress" changes nothing.
- [ ] Check whether the native picker hands back a writable file on ChromeOS and on the tablet (the open Sprint 9 question).

## 4. Posture and input matrix (P2-S21-04)

Every screen: title, first run, hub, mine (Zones 1-5, including the sieve and the factor tree), crafting bench, build site and a build, museum, badge case, Word Gems, Challenge Door, Deep Dig, garage, settings, pause, parent gate, dashboard, family rewards.

| Input | 2-in-1 laptop | 2-in-1 tent | 2-in-1 tablet | Android tablet |
|---|---|---|---|---|
| Touch only | | | | |
| Stylus only (the slate appears; palm resting while writing) | n/a | | | if a stylus exists |
| Mouse and keyboard (the slate never appears; drag works with the mouse) | | n/a | n/a | n/a |
| Posture switch mid-session (during a slate stroke, a drag and a build step) | | | | n/a |

Defects found: fix, or defer with Spiro's okay (write it here).

## 5. Release

- [ ] Spiro sets the Android version code and name for 1.0 in the export presets (an export setting: not changed by the agent).
- [ ] `"$GODOT" --headless --path . --export-release "Android AAB" build/gem-mines.aab` with the keystore environment variables.
- [ ] Upload to internal testing; install on both devices from Play.
- [ ] Airplane mode: a full session on each device.
- [ ] Charlie plays a full session on his own on each device.
- [ ] Tag `v1.0.0` on the release commit.
