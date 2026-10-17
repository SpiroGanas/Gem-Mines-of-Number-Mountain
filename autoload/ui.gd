## UI autoload: DPI-aware sizing for interactive controls.
## Sprint 1 slice. Sprint 3 adds the Explorer theme and posture/aspect handling.
## Rule 7 (CLAUDE.md): every interactive control sizes itself from min_target_px(),
## never from a hard-coded pixel value.
extends Node

## Minimum touch-target size in density-independent pixels (dp).
const MIN_TARGET_DP: int = 64
## Android's baseline density: 1 dp == 1 px at 160 dpi.
const BASELINE_DPI: float = 160.0


## Smallest allowed size, in canvas pixels, for a tappable control.
## Converts 64 dp to physical pixels using the screen DPI, then divides by the
## stretch scale so the control measures 64 dp on screen after canvas scaling.
## Never returns less than MIN_TARGET_DP, so desktop and headless runs stay safe.
func min_target_px() -> int:
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		dpi = int(BASELINE_DPI)
	var physical_px: float = MIN_TARGET_DP * (float(dpi) / BASELINE_DPI)
	var canvas_px: float = physical_px / scale_factor()
	return maxi(int(ceil(canvas_px)), MIN_TARGET_DP)


## How many physical pixels one canvas pixel covers under the project's
## canvas_items stretch mode with "expand" aspect (the smaller axis ratio).
func scale_factor() -> float:
	var window: Window = get_window()
	if window == null:
		return 1.0
	var content: Vector2i = window.content_scale_size
	if content.x <= 0 or content.y <= 0:
		return 1.0
	var sx: float = float(window.size.x) / float(content.x)
	var sy: float = float(window.size.y) / float(content.y)
	return maxf(minf(sx, sy), 0.01)
