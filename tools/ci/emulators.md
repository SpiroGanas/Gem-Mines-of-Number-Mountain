# Emulator matrix (P3-S25-06)

The Android emulator profiles for the broad-device passes (`docs/phases/phase-3-public-release-readiness.md` 3.8, `docs/release-checklist.md` section 4). Recreate them on a fresh machine with the Android SDK command-line tools (`sdkmanager`, `avdmanager`, `emulator`; Git Bash or Linux). Not run in CI (no hardware acceleration there).

```bash
SDK="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
"$SDK/cmdline-tools/latest/bin/sdkmanager" "emulator" "platform-tools" \
  "system-images;android-36;google_apis;x86_64"
# Pick device definitions from the list (names vary between SDK releases):
"$SDK/cmdline-tools/latest/bin/avdmanager" list device | grep -i -E "tablet|desktop|nexus 7|nexus 9"
```

| Profile | AVD name | Create with (`avdmanager create avd -n <name> -k "system-images;android-36;google_apis;x86_64" -d <device>`) | Then edit `~/.android/avd/<name>.avd/config.ini` | Covers |
|---|---|---|---|---|
| 10" tablet | `gm-tablet` | `-d pixel_tablet` | `hw.ramSize=4096` | Charlie's tablet class, touch |
| 8" small tablet, 1280 x 800 | `gm-tablet-8` | a 7-8" definition from the list (e.g. `"Nexus 7 2013"`) | `hw.lcd.width=1280`, `hw.lcd.height=800`, `hw.lcd.density=213` | small tablets; the 600 dp boundary |
| Low-end tablet, 2 GB | `gm-lowend` | `-d pixel_tablet` | `hw.ramSize=2048`, `hw.cpu.ncore=2` | 60 fps on the dig loop and hub |
| x86_64 Chromebook, mouse only | `gm-desktop` | a "Desktop" or resizable definition from the list | `hw.screen=no-touch`, `hw.mainKeys=yes`, `hw.keyboard=yes` | Intel/AMD Chromebooks; the mouse-only pass (the slate must never appear) |
| Phone (supported) | `gm-phone` | `-d pixel_8` | | landscape phone, about 20:9 (about 411 dp tall): the compact layouts (`UI.is_compact()`); every screen fits, every target is at least 64 dp, nothing is cut off (headless: `tests/scenes/test_phone_layout.gd` at 2400x1080 @ 420 dpi) |
| Small phone | `gm-phone-small` | `-d pixel_8` | `hw.lcd.width=720`, `hw.lcd.height=1600`, `hw.lcd.density=320` | the shortest landscape phone, 360 dp tall: the same checks (headless at 1600x720 @ 320 dpi) |

Run one: `"$SDK/emulator/emulator" -avd gm-desktop`, then `adb install -r build/gem-mines-debug.apk`.

Notes:

- The AAB from Play Console installs per device; to test the exact AAB locally, use bundletool (`build-apks --connected-device`), which needs Spiro's approval as a build-time tool if it is not already installed.
- The Windows editor run that simulates a mouse-only device: `"$GODOT" --path . -- --no-touch` (`scripts/input/device_caps.gd`).
- ARM system images do not run on x86_64 hosts at useful speed; the arm64 build is covered by the real devices.
