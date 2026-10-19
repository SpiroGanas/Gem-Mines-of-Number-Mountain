# Release checklist (public releases on Google Play)

Reusable for every release from the public 1.0.0 on: the launch (Sprint 28), the closed-test builds (Sprints 26-27), Phase 4 zone updates and the yearly platform update (`docs/platform-update.md`). Copy the "Run" block into the release notes and tick each box there.

The device matrices (save migration, cross-device round trip, posture x input) live in `docs/qa/release-1.0.md` sections 2-4 and are **not repeated here**; this checklist says when to run them. That file stays the record of the private Version 1.0 build.

## Run

| | |
|---|---|
| Release | e.g. `1.0.0` (version name) / `N` (version code) |
| Track | internal / closed / production |
| Commit | |
| Date | |
| Done by | |

## 1. Before the build

- [ ] Every launch-blocker card on the project board is closed (closed test: `docs/qa/closed-test-plan.md`, "Triage").
- [ ] **Spiro** sets `version/code` (always higher than the last upload) and `version/name` in **both** export presets. This is an export setting: the agent does not change it.
- [ ] Release notes written (what changed, for parents; under 500 characters for Play's "What's new").
- [ ] If the save schema changed: the migration, its fixture from every earlier version and Spiro's sign-off are in (`CLAUDE.md`, Save system).

## 2. Automated checks (paste the output into the release notes)

- [ ] `"$GODOT" --headless --path . --import`
- [ ] `GODOT_BIN="$GODOT" ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests` (all suites; includes `tests/scenes/test_mouse_only_pass.gd`)
- [ ] `python -m pytest tools` (includes the export-preset checks: no permissions, every screen size on (phones supported), the pinned target SDK, and the listing limits)
- [ ] `python tools/crosscheck/run.py --all --n 10000`, then `--n 2000 --difficulty -1` and `--difficulty -2`
- [ ] `python tools/ci/lint_content.py`, `python tools/ci/curriculum_check.py`, `python tools/ci/perf_check.py`, `python tools/ci/check_sdk_audit.py`
- [ ] CI is green on the release commit (`.github/workflows/ci.yml`)

## 3. Build and sign

- [ ] Release keystore in environment variables only (never in the repo or in `export_presets.cfg`): `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
- [ ] `"$GODOT" --headless --path . --export-release "Android AAB" build/gem-mines.aab`
- [ ] `python tools/ci/check_manifest.py build/gem-mines.aab` passes: no `INTERNET`, location, camera, microphone, contacts or `AD_ID`; nothing in `<supports-screens>` shuts phones out. Set `BUNDLETOOL` to the bundletool JAR to read it with bundletool too. Paste the output.
- [ ] The AAB holds both ABIs: `unzip -l build/gem-mines.aab | grep -E "lib/(arm64-v8a|x86_64)/"` lists both.
- [ ] Size: the download stays under 150 MB (Play Console shows the per-device download size after upload; record it).
- [ ] Archive the AAB with its SHA-256 (`sha256sum build/gem-mines.aab`) and the commit, outside the repo.

## 4. Device passes (the Friday device matrix)

Run on the build being released, installed from the Play track where possible.

- [ ] **Save upgrade:** `docs/qa/release-1.0.md` section 2, from the previous production build (install it, play one rock, update, progress and profiles intact).
- [ ] **Cross-device round trip:** `docs/qa/release-1.0.md` section 3 (when the save or the export changed).
- [ ] **Posture x input matrix:** `docs/qa/release-1.0.md` section 4: touch-only, stylus-only, mouse and keyboard.
- [ ] **Mouse-only pass:** every screen completed with click and drag only, the chalk slate never appears; on the x86_64 emulator with no touch screen (`tools/ci/emulators.md`) and in the editor with `"$GODOT" --path . -- --no-touch`. Drops land when slightly off the target (the 25% larger drop area).
- [ ] **Keyboard-only pass:** in laptop posture, every screen reachable with Tab, Enter and the arrow keys; the number pad takes the digit keys, Backspace and Enter.
- [ ] **Airplane mode:** Wi-Fi and data off, a full 20-minute session on each real device and on the x86_64 emulator; also a fresh install opened for the first time with no connection.
- [ ] **Emulator matrix** (`tools/ci/emulators.md`): installs and plays one rock on each profile.

## 5. Store paperwork (re-check every release)

- [ ] `docs/compliance/families-self-check.md`: a new dated run, against the live policy page.
- [ ] `docs/compliance/policy-verification.md`: every policy claim still has its evidence; if anything the app stores or shares changed, update `docs/privacy-policy.md` (version and effective date) **before** the release.
- [ ] Data safety, target audience and content rating in Play Console still match `docs/compliance/` (a platform update or a zone update should change nothing; confirm it).
- [ ] Store listing: `marketing/listing.md` updated if features changed (`python -m pytest tools/ci/test_listing.py`), screenshots still show the current game, pasted into Play Console.

## 6. Upload and roll out

- [ ] Upload the AAB to the track; check Play Console's pre-launch report (zero crashes, no accessibility blockers worth fixing first).
- [ ] **Internal track:** keep it on the same build as production so Charlie's devices match what families get.
- [ ] **Production: staged rollout at 20%.** Watch Play Console vitals (crashes, ANRs) and reviews for **48 hours**.
- [ ] No crash or ANR spike and no blocker in reviews: **raise to 100%**. A problem: halt the rollout, fix, and release a new version code (a halted rollout cannot be replaced by the same version code).
- [ ] First production release of a children's app: allow 7 days or more for Google's review; do not plan work that depends on the listing being live.

## 7. After the release

- [ ] Tag the release commit (`v1.0.0`; platform updates `v1.4.1-platform` style) and push the tag.
- [ ] Note the release, the rollout dates and the download size in `docs/decisions.md` if anything was decided along the way, and in `status.md`.

## 8. Zone content updates (Phase 4 on; added with Zone 9)

A zone update (`v1.1.0-zone6`, `v1.2.0-zone7`, `v1.3.0-zone8`, `v1.5.0-zone9`) is a normal release plus these steps, in the zone's Sprint C (`docs/phases/phase-4-middle-mountain.md`, "The three-sprint zone pattern").

- [ ] The zone's skill file is `"status": "detailed"`, and every one of its generators passes its GdUnit4 suite and `python tools/crosscheck/run.py --skill <id> --n 10000` at difficulty 0 and `--difficulty -1` (paste the per-skill lines).
- [ ] The zone opens only after the zone before it: `tests/curriculum/test_skill_graph.gd` (its zone-order test) and the zone's mine test (`deepest_zone`, music and banner) pass.
- [ ] The math review packet is regenerated (`"$GODOT" --headless --path . res://tools/qa/math_review_packet.tscn -- --zones N --samples 30`) and the zone's "Needs reviewer" entry in `docs/decisions.md` has the human reviewer's sign-off. No sign-off: internal track only.
- [ ] Art and sound: the zone has its own backdrop palette (`Backdrop.PALETTES`, and `LAST_PALETTE_ZONE` raised when every zone up to it has one), its banner line (`zN.zone.name`), its music loop (`tools/music/generate_placeholder_music.py --track mine_zN`) and its `zN.zone.done` line; every new file has its row in `assets/CREDITS.md`.
- [ ] Any badge the zone adds is earned by mastery only (`curriculum/badges.json`, `unlock.skills_mastered`) and its story reads without placeholders.
- [ ] If the zone added data a person must check (Zone 9's `curriculum/poem_words.json` syllable counts), Spiro has reviewed it.
- [ ] Store listing: one new screenshot of the zone and its "What's new" line.
- [ ] After 100%: tag `v1.N.0-zoneN` and push the tag.
