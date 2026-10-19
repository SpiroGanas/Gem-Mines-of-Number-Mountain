## Gives layout-sensitive tests a realistic window.
##
## GdUnit4's headless runner opens a 64x64 window. UI.min_target_px() divides by the stretch
## scale (window size / 1920x1080), so in that window every 64 dp target measures about 1,900
## canvas pixels and any test that checks positions or hit areas sees an absurd layout. Call
## use_design_size() in before_test() and restore() in after_test().
##
## use_phone() plays a landscape phone: a 20:9 window and the phone's screen density (through
## UI.simulate_dpi), so UI.min_target_px() and UI.is_compact() answer as they would on the device.
## restore() puts the density back too.
class_name TestWindow
extends RefCounted

const DESIGN_SIZE: Vector2i = Vector2i(1920, 1080)
## Landscape phones the layout must fit (window size in pixels, screen dpi): a common 20:9 phone
## (about 411 dp tall) and a small one (360 dp tall, the shortest Android phone class in landscape).
const PHONE: Vector2i = Vector2i(2400, 1080)
const PHONE_DPI: int = 420
const SMALL_PHONE: Vector2i = Vector2i(1600, 720)
const SMALL_PHONE_DPI: int = 320
## The tablet and Chromebook shapes (16:9, 16:10, 3:2, 4:3) at the design density.
const TABLET_SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(1620, 1080), Vector2i(1440, 1080)]

static var _saved_size: Vector2i = Vector2i.ZERO


## Sets the root window to the 1920x1080 design size (scale 1.0, min target 64 px at 96 dpi).
static func use_design_size(window: Window) -> void:
	_saved_size = window.size
	window.size = DESIGN_SIZE


## Sets the root window to a landscape phone: `size` pixels at `dpi` (defaults: PHONE at PHONE_DPI).
static func use_phone(window: Window, size: Vector2i = PHONE, dpi: int = PHONE_DPI) -> void:
	if _saved_size == Vector2i.ZERO:
		_saved_size = window.size
	window.size = size
	UI.simulate_dpi(dpi)


## Back to a tablet-like density at `size` (the design size by default), keeping restore()'s saved size.
static func use_tablet(window: Window, size: Vector2i = DESIGN_SIZE) -> void:
	if _saved_size == Vector2i.ZERO:
		_saved_size = window.size
	window.size = size
	UI.simulate_dpi(0)


static func restore(window: Window) -> void:
	if UI.dpi_override != 0:
		UI.simulate_dpi(0)
	if _saved_size != Vector2i.ZERO:
		window.size = _saved_size
		_saved_size = Vector2i.ZERO
