# Version 1.0 performance (Sprint 20, P2-S20-02 and the Phase 2 testing table)

## Measured here (build environment, no device)

| Check | Result | How |
|---|---|---|
| Draw calls per screen, every screen at 16:9, 16:10, 3:2 and 4:3 | 15 (title) to about 90 (hub); see `docs/qa/draw-calls-1.0.md` | `tools/qa/capture_screens.tscn` under Xvfb with the GL Compatibility (opengl3) renderer; draw calls depend on the scene, not the GPU |
| No allocations in `_process` hot paths, OGG audio only, exported-size budget | see the `perf_check.py` line in the Sprint 20 entry of `docs/decisions.md` | `python tools/ci/perf_check.py` |
| Particles | `CPUParticles2D`, one emitter per effect (rock crack, celebration), with Kenney textures | code review; CPU particles were kept instead of `GPUParticles2D` because they behave the same on every GL Compatibility driver, including the ARM Chromebook's |

## To measure on the devices (Spiro)

The plan's frame-time capture needs the real hardware: the build machine has only a software renderer, so its frame times say nothing about the Chromebook or the tablet.

For each device (ARM 2-in-1 Chromebook in tablet posture; Android tablet):

1. Install the debug APK (`"$GODOT" --headless --path . --export-debug "Android" build/gem-mines-debug.apk`, then `adb install -r`).
2. Run the remote debugger (Godot editor > Debugger > Monitors) and play: hub (machines running), a mine wall with a crack and a gem flight, the crafting bench, a build step, the Challenge Door, a Deep Dig wall, a Zone 5 sieve.
3. Record here: average and worst frame time per screen, and whether any screen drops below 60 fps.

| Device | Screen | Avg frame (ms) | Worst frame (ms) | 60 fps? | Notes |
|---|---|---|---|---|---|
| 2-in-1 | hub | | | | |
| 2-in-1 | mine | | | | |
| tablet | hub | | | | |
| tablet | mine | | | | |
