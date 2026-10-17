## Gives layout-sensitive tests a realistic window.
##
## GdUnit4's headless runner opens a 64x64 window. UI.min_target_px() divides by the stretch
## scale (window size / 1920x1080), so in that window every 64 dp target measures about 1,900
## canvas pixels and any test that checks positions or hit areas sees an absurd layout. Call
## use_design_size() in before_test() and restore() in after_test().
class_name TestWindow
extends RefCounted

const DESIGN_SIZE: Vector2i = Vector2i(1920, 1080)

static var _saved_size: Vector2i = Vector2i.ZERO


## Sets the root window to the 1920x1080 design size (scale 1.0, min target 64 px at 96 dpi).
static func use_design_size(window: Window) -> void:
	_saved_size = window.size
	window.size = DESIGN_SIZE


static func restore(window: Window) -> void:
	if _saved_size != Vector2i.ZERO:
		window.size = _saved_size
		_saved_size = Vector2i.ZERO
