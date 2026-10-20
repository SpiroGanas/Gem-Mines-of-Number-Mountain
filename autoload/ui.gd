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
## A screen whose short side is below this many dp is "compact" (a landscape phone, about 360 to
## 430 dp tall): 64 dp targets then take about twice the share of the height they take on a tablet,
## so screens tighten their pictures, margins and spacing (is_compact). Tablets and Chromebooks
## are 600 dp or more (Android's own "sw600dp" line between phones and tablets).
const COMPACT_SHORT_SIDE_DP: float = 600.0
## A 64 dp target on the 1920x1080 design canvas at the baseline density: what one target multiple
## measures in the layouts as they were designed (layout_unit_px on a compact screen).
const DESIGN_TARGET_PX: int = 64

## Tests only: the screen density to use instead of the device's (0, the default, asks the device).
## Set it with simulate_dpi(), which also refreshes every size, so tests can play a phone.
var dpi_override: int = 0

var _theme: Theme


func _ready() -> void:
	get_window().size_changed.connect(_on_window_size_changed)


## Smallest allowed size, in canvas pixels, for a tappable control.
## Converts 64 dp to physical pixels using the screen DPI, then divides by the
## stretch scale so the control measures 64 dp on screen after canvas scaling.
## Never returns less than MIN_TARGET_DP, so desktop and headless runs stay safe.
func min_target_px() -> int:
	var dpi: int = screen_dpi()
	var physical_px: float = MIN_TARGET_DP * (float(dpi) / BASELINE_DPI)
	var canvas_px: float = physical_px / scale_factor()
	return maxi(int(ceil(canvas_px)), MIN_TARGET_DP)


## The screen density in dots per inch: the device's, or dpi_override in tests. Never 0.
func screen_dpi() -> int:
	var dpi: int = dpi_override if dpi_override > 0 else DisplayServer.screen_get_dpi()
	return dpi if dpi > 0 else int(BASELINE_DPI)


## The window's short side in dp (density-independent pixels): about 360-430 on a landscape phone,
## 600 and up on a tablet or Chromebook.
func short_side_dp() -> float:
	var window: Window = get_window()
	if window == null:
		return 0.0
	var short_px: int = mini(window.size.x, window.size.y)
	return float(short_px) * BASELINE_DPI / float(screen_dpi())


## True on a phone-sized screen (short side under COMPACT_SHORT_SIDE_DP). Screens read it when they
## lay out (and again on metrics_changed) to shrink pictures, margins and gaps; interactive controls
## never shrink: they stay at min_target_px() or more.
func is_compact() -> bool:
	return short_side_dp() < COMPACT_SHORT_SIDE_DP


## A spacing (margin, gap) for the design canvas, scaled down on a compact screen. `compact_share`
## is the fraction kept there (0.5: half the gap). Never for a control's own size.
func spacing(design_px: int, compact_share: float = 0.5) -> int:
	return int(round(design_px * compact_share)) if is_compact() else design_px


## The canvas pixels one "target multiple" stands for in layout math: min_target_px() normally;
## on a compact screen the design canvas's own 64 px (DESIGN_TARGET_PX), so pictures, columns and
## panels keep their design-canvas size there instead of growing with the phone's big targets.
func layout_unit_px() -> float:
	return float(DESIGN_TARGET_PX) if is_compact() else float(min_target_px())


## Wraps `content` (a list that can outgrow the screen: badges, builds, garage items) in a vertical
## ScrollContainer that takes the free height. A list that fits does not scroll; one that does not is
## scrolled with one finger, the mouse wheel or the trackpad, never by shrinking its targets.
func vertical_scroll(content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## Tests only: pretend the screen has `dpi` dots per inch (0 goes back to the device's) and refresh
## every touch target, the theme and the screens that listen to metrics_changed.
func simulate_dpi(dpi: int) -> void:
	dpi_override = maxi(dpi, 0)
	_on_window_size_changed()


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
		_theme = ExplorerTheme.build(min_target_px(), int(layout_unit_px()))
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
## On a compact screen (a phone) a multiple above 1 measures in layout_unit_px() instead, so a key
## or picture keeps its design-canvas size, but never less than one whole target: a 2.5 x 1.75 key
## becomes one target square, a six-target picture stays 384 px wide. Below 1 (only pictures, such
## as a gem or a sign; never a control) the multiple is a share of the layout unit.
func target_size(width_multiple: float = 1.0, height_multiple: float = 1.0) -> Vector2:
	var side: float = float(min_target_px())
	if not is_compact():
		return Vector2(side * width_multiple, side * height_multiple)
	return Vector2(_compact_length(width_multiple, side), _compact_length(height_multiple, side))


## A picture's size (never a control's) in target multiples: target_size() on a tablet; on a phone
## the design-canvas size even below one target, so a picture does not crowd out the inputs.
func picture_size(width_multiple: float, height_multiple: float) -> Vector2:
	if not is_compact():
		return target_size(width_multiple, height_multiple)
	return Vector2(width_multiple, height_multiple) * layout_unit_px()


func _compact_length(multiple: float, side: float) -> float:
	var length: float = layout_unit_px() * multiple
	return maxf(side, length) if multiple >= 1.0 else length


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
