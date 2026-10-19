## What this device offers for input: is there a touch screen, or is it a mouse-only Chromebook?
##
## Phase 3, Sprint 25 (the mouse-only path, docs/phases/phase-3-public-release-readiness.md 3.8).
## The Shell runs the check once at startup (check_at_startup) and the answer is kept for the
## session. Without a touch screen:
## - the ChalkSlate is not offered (DigitInk.is_available asks here) and the NumberPad is used;
## - every drop target is 25% bigger for the drop (drop_rect), because a trackpad or a mouse in a
##   six-year-old's hand lands less precisely than a finger.
## Scenes never fork for this: the same widgets read the same InputRouter signals, and only the
## drop test and the answer mode change.
##
## Developers simulate a mouse-only device with the user argument --no-touch, given after "--" so
## Godot passes it through to the game (OS.get_cmdline_user_args):
##   "$GODOT" --path . -- --no-touch
## Tests set touch_override instead and call reset() afterwards.
class_name DeviceCaps
extends RefCounted

## The user argument that makes this device count as having no touch screen.
const NO_TOUCH_ARG: String = "--no-touch"
## How much bigger a drop target is without a touch screen: 0.25 = 25% wider and 25% taller.
const MOUSE_ONLY_DROP_GROWTH: float = 0.25

## Tests (and nothing else) set this to true or false to ignore the device. null = ask the device.
static var touch_override: Variant = null

static var _checked: bool = false
static var _touch: bool = false


## Runs the capability check now (the Shell calls this once, at startup) and returns its answer.
static func check_at_startup() -> bool:
	_checked = false
	var touch: bool = has_touchscreen()
	print_verbose("DeviceCaps: touch screen %s%s" % ["yes" if touch else "no", " (--no-touch)" if no_touch_flag() else ""])
	return touch


## True when the device has a touch screen and --no-touch was not given.
static func has_touchscreen() -> bool:
	if touch_override != null:
		return bool(touch_override)
	if not _checked:
		_touch = DisplayServer.is_touchscreen_available() and not no_touch_flag()
		_checked = true
	return _touch


## True when click and drag are the only way in (no touch screen): the mouse-only path.
static func is_mouse_only() -> bool:
	return not has_touchscreen()


## True when the game was started with --no-touch after "--".
static func no_touch_flag() -> bool:
	return has_no_touch_arg(OS.get_cmdline_user_args())


## True when `args` (user arguments, as OS.get_cmdline_user_args returns them) ask for no touch.
static func has_no_touch_arg(args: PackedStringArray) -> bool:
	return args.has(NO_TOUCH_ARG)


## How much a drop target's size is multiplied by on this device: 1.0 with touch, 1.25 without.
static func drop_scale() -> float:
	return 1.0 if has_touchscreen() else 1.0 + MOUSE_ONLY_DROP_GROWTH


## The area that counts as "dropped on" a target whose on-screen rectangle is `rect`. With a touch
## screen it is the rectangle itself; without one it grows by 25% in each direction, keeping the
## same centre (12.5% of the width on the left and on the right, and the same for the height).
static func drop_rect(rect: Rect2) -> Rect2:
	var extra: float = drop_scale() - 1.0
	if extra <= 0.0:
		return rect
	var grow_x: float = rect.size.x * extra * 0.5
	var grow_y: float = rect.size.y * extra * 0.5
	return rect.grow_individual(grow_x, grow_y, grow_x, grow_y)


## Which of `rects` (on-screen target rectangles) a drop at `pos` lands on, or -1. A rectangle that
## holds the point itself wins; otherwise, without a touch screen, the grown rectangles (drop_rect)
## are tried and the one whose centre is nearest wins, so two neighbouring targets never both claim
## the drop.
static func drop_index(rects: Array[Rect2], pos: Vector2) -> int:
	for index: int in rects.size():
		if rects[index].has_point(pos):
			return index
	var best: int = -1
	var best_distance: float = INF
	for index: int in rects.size():
		if not drop_rect(rects[index]).has_point(pos):
			continue
		var distance: float = rects[index].get_center().distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## Forget the cached answer and the override (tests).
static func reset() -> void:
	touch_override = null
	_checked = false
	_touch = false
