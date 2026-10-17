## UI autoload: DPI-aware sizing, the Explorer theme, and window-size handling.
## Rule 7 (CLAUDE.md): every interactive control sizes itself from min_target_px(),
## never from a hard-coded pixel value. Call make_touch_target() on a control and
## it is sized now and re-sized whenever the window changes (posture switches).
extends Node

## Emitted after the window size changes and the cached sizes/theme are refreshed.
signal metrics_changed

## Minimum touch-target size in density-independent pixels (dp).
const MIN_TARGET_DP: int = 64
## Android's baseline density: 1 dp == 1 px at 160 dpi.
const BASELINE_DPI: float = 160.0
## Controls registered with make_touch_target() live in this group.
const TARGET_GROUP: StringName = &"touch_target"
const META_WIDTH_MULTIPLE: StringName = &"touch_target_width"
const META_HEIGHT_MULTIPLE: StringName = &"touch_target_height"

var _theme: Theme


func _ready() -> void:
	get_window().size_changed.connect(_on_window_size_changed)


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


## The Explorer theme for the current screen metrics. Assign it to a screen's root
## Control (theme = UI.theme()) and every child is styled.
func theme() -> Theme:
	if _theme == null:
		_theme = ExplorerTheme.build(min_target_px())
	return _theme


## Sizes a control to at least width_multiple x height_multiple touch targets
## (1.0 = exactly the 64 dp minimum) and keeps it that size when the window changes.
func make_touch_target(control: Control, width_multiple: float = 1.0, height_multiple: float = 1.0) -> void:
	control.set_meta(META_WIDTH_MULTIPLE, width_multiple)
	control.set_meta(META_HEIGHT_MULTIPLE, height_multiple)
	if not control.is_in_group(TARGET_GROUP):
		control.add_to_group(TARGET_GROUP)
	_apply_target_size(control)


## The size make_touch_target() gave (or would give) a control, for tests and layout code.
func target_size(width_multiple: float = 1.0, height_multiple: float = 1.0) -> Vector2:
	var side: float = float(min_target_px())
	return Vector2(side * width_multiple, side * height_multiple)


func _apply_target_size(control: Control) -> void:
	var width_multiple: float = control.get_meta(META_WIDTH_MULTIPLE, 1.0)
	var height_multiple: float = control.get_meta(META_HEIGHT_MULTIPLE, 1.0)
	control.custom_minimum_size = target_size(width_multiple, height_multiple)


func _on_window_size_changed() -> void:
	_theme = null
	for node: Node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Control:
			_apply_target_size(node)
	metrics_changed.emit()
