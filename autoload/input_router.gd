## InputRouter autoload: one place that turns touch, pen, mouse and keyboard into the
## same few game signals, so finger, stylus and mouse behave identically.
##
## Scenes that need drag-and-drop (DragTarget, tap targets) listen to pointer_down /
## pointer_move / pointer_up instead of reading InputEvents themselves. Buttons keep
## using their normal `pressed` signal; Godot's GUI already handles those.
##
## Rules this enforces:
## - Only the first finger counts. Extra fingers are ignored (no multi-finger gestures).
## - Android makes an emulated mouse event for every touch. Those carry
##   InputEvent.DEVICE_ID_EMULATION and are dropped here, so a tap is reported once.
## - Mouse movement only counts as a drag while the left button is held.
## - Escape (and Android's back gesture, handled by the Shell) asks for the pause menu.
##
## Strokes (the chalk slate, Sprint 14): stroke_started / stroke_moved / stroke_ended carry the
## pen pressure for writing. Palm rejection lives here and nowhere else:
## - while a pen stroke is active, every other touch is a palm and is ignored;
## - if a palm is already down when the pen arrives, a drag that is clearly a pen (it reports a tilt
##   or the eraser end) takes the stroke over: the palm's stroke is cancelled (stroke_cancelled, and
##   pointer_cancelled so nothing is left held and nothing is dropped or tapped) and the pen starts a
##   fresh one.
## How a ChromeOS stylus arrives is still unverified on the real devices (docs/decisions.md,
## Sprint 1): a stylus may come as touch with pressure, or as mouse motion with pressure. Both paths
## are handled; the takeover needs the stronger tilt or eraser signal so a finger is never mistaken
## for a pen.
extends Node

enum DeviceKind { TOUCH, PEN, MOUSE, KEYBOARD }

signal pointer_down(pos: Vector2, kind: DeviceKind, index: int)
signal pointer_move(pos: Vector2, kind: DeviceKind, index: int)
signal pointer_up(pos: Vector2, kind: DeviceKind, index: int)
## The pointer that was down was not the child's (a resting palm the pen took over from): drop
## whatever it was holding without acting, as if it had never come down.
signal pointer_cancelled(index: int)
## The last kind of device used changed. Drives hints such as "tap" vs. "click".
signal device_kind_changed(kind: DeviceKind)
## The window changed size: a posture switch on a 2-in-1, a resize on desktop.
signal posture_changed(size: Vector2i)
## Escape was pressed.
signal pause_requested
## A stroke began at `pos`. `is_pen` is a best guess from the device (a finger or a mouse is false;
## a pen is only known once its first drag arrives, so it can be false here and true after).
signal stroke_started(pos: Vector2, pressure: float, is_pen: bool)
## The stroke moved to `pos`. `pressure` is 0..1 (1.0 for a finger or mouse).
signal stroke_moved(pos: Vector2, pressure: float)
## The stroke ended normally (finger, pen or mouse lifted).
signal stroke_ended
## The stroke was not the child's: a resting palm that a pen took over from. Drop it.
signal stroke_cancelled
## The first typing key of the session was pressed: a real keyboard is there (Scholar mode's typing).
signal keyboard_detected

const NO_TOUCH: int = -1

## True while a pen (not a finger or mouse) is drawing. Other touches are palms and are ignored.
var pen_stroke_active: bool = false

var _last_kind: DeviceKind = DeviceKind.TOUCH
var _mouse_seen: bool = false
var _active_touch: int = NO_TOUCH
var _active_position: Vector2 = Vector2.ZERO
var _mouse_down: bool = false
## Touches that came down while another was active: index -> where. Ignored unless a pen drag proves
## one is the pen (then it takes over from a palm).
var _waiting_touches: Dictionary[int, Vector2] = {}
## A typing key was pressed this session (has_keyboard).
var _keyboard_seen: bool = false


func _ready() -> void:
	# Keep routing while the game is paused, so Escape can close the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size_changed.connect(_on_window_size_changed)


func _input(event: InputEvent) -> void:
	process_event(event)


func last_device_kind() -> DeviceKind:
	return _last_kind


## True until a real mouse event has been seen this session. A stylus counts as touch.
func is_touch_first() -> bool:
	return not _mouse_seen


## Converts one InputEvent into router signals. Public so tests (and tools/helpers)
## can feed synthetic events without relying on the engine delivering them.
func process_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _active_touch != NO_TOUCH or _mouse_down or pen_stroke_active:
			_waiting_touches[event.index] = event.position # a second finger or a palm: ignore, but remember
			return
		_start_touch(event.index, event.position)
	elif event.index == _active_touch:
		_active_touch = NO_TOUCH
		pen_stroke_active = false
		_waiting_touches.clear()
		pointer_up.emit(event.position, _last_kind if _last_kind == DeviceKind.PEN else DeviceKind.TOUCH, event.index)
		stroke_ended.emit()
	else:
		_waiting_touches.erase(event.index)


func _start_touch(index: int, position: Vector2) -> void:
	_active_touch = index
	_active_position = position
	_set_kind(DeviceKind.TOUCH)
	pointer_down.emit(position, DeviceKind.TOUCH, index)
	stroke_started.emit(position, 1.0, false)


func _handle_drag(event: InputEventScreenDrag) -> void:
	var is_pen: bool = _looks_like_pen(event.pressure, event.tilt, event.pen_inverted)
	if event.index != _active_touch:
		# A waiting touch that proves to be the pen takes the stroke from a resting palm.
		if _waiting_touches.has(event.index) and not pen_stroke_active and _is_clearly_pen(event.tilt, event.pen_inverted):
			_take_over(event.index)
		else:
			return
	var kind: DeviceKind = DeviceKind.PEN if is_pen else DeviceKind.TOUCH
	if kind == DeviceKind.PEN:
		pen_stroke_active = true
	_set_kind(kind)
	_active_position = event.position
	pointer_move.emit(event.position, kind, event.index)
	stroke_moved.emit(event.position, event.pressure if is_pen else 1.0)


## The pen at `index` replaces the stroke of whatever touch was active (a palm).
func _take_over(index: int) -> void:
	var start: Vector2 = _waiting_touches.get(index, _active_position)
	if _active_touch != NO_TOUCH:
		# Not pointer_up: a palm resting on a drag board would read as a tap or a drop there.
		pointer_cancelled.emit(_active_touch)
		stroke_cancelled.emit()
	_waiting_touches.erase(index)
	_active_touch = index
	_active_position = start
	pen_stroke_active = true
	_set_kind(DeviceKind.PEN)
	pointer_down.emit(start, DeviceKind.PEN, index)
	stroke_started.emit(start, 1.0, true)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_seen = true
	if event.pressed:
		if _active_touch != NO_TOUCH:
			return # a touch is already drawing: this mouse press is a palm or a second device
		_set_kind(DeviceKind.MOUSE)
		_mouse_down = true
		pointer_down.emit(event.position, DeviceKind.MOUSE, 0)
		stroke_started.emit(event.position, 1.0, false)
	elif _mouse_down:
		_mouse_down = false
		var was_pen: bool = pen_stroke_active
		pen_stroke_active = false
		pointer_up.emit(event.position, DeviceKind.PEN if was_pen else DeviceKind.MOUSE, 0)
		stroke_ended.emit()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	_mouse_seen = true
	if not _mouse_down:
		return
	var is_pen: bool = _looks_like_pen(event.pressure, event.tilt, event.pen_inverted)
	var kind: DeviceKind = DeviceKind.PEN if is_pen else DeviceKind.MOUSE
	if is_pen:
		pen_stroke_active = true # a stylus delivered as mouse motion: touches while it draws are palms
	_set_kind(kind)
	pointer_move.emit(event.position, kind, 0)
	stroke_moved.emit(event.position, event.pressure if is_pen else 1.0)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
	if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return # a lone modifier is not "using the keyboard"
	_set_kind(DeviceKind.KEYBOARD)
	if not _keyboard_seen and is_typing_key(event.keycode):
		_keyboard_seen = true
		keyboard_detected.emit()


## True once a key that only a real keyboard sends was pressed this session (Scholar mode, Sprint 37).
## Conservative on purpose (Spiro's decision): Android and ChromeOS do not reliably report whether a
## keyboard is attached, and a tablet's volume, media and back buttons arrive as key events too, so
## only typing keys count (letters, digits, Enter, Backspace, Space, Tab, arrows, - . /). Until then the
## on-screen pads are the only way to type, and they always stay available.
func has_keyboard() -> bool:
	return _keyboard_seen


## Tests (and a fresh session): forget that a keyboard was seen.
func reset_keyboard() -> void:
	_keyboard_seen = false


## Keys only a real keyboard sends (has_keyboard).
static func is_typing_key(keycode: Key) -> bool:
	if (keycode >= KEY_A and keycode <= KEY_Z) or (keycode >= KEY_0 and keycode <= KEY_9) or (keycode >= KEY_KP_0 and keycode <= KEY_KP_9):
		return true
	return keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE, KEY_SPACE, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_PERIOD, KEY_KP_PERIOD, KEY_SLASH, KEY_KP_DIVIDE]


## Best-effort stylus detection: a pen reports pressure strictly between 0 and 1, a tilt,
## or an inverted (eraser) end; a mouse reports a flat 0 or 1. How a ChromeOS stylus
## actually arrives is recorded by the Sprint 1 device test (docs/decisions.md); until then
## PEN is treated exactly like TOUCH by every consumer.
func _looks_like_pen(pressure: float, tilt: Vector2, inverted: bool) -> bool:
	return inverted or tilt != Vector2.ZERO or (pressure > 0.0 and pressure < 1.0)


## A drag that can only come from a pen: it reports a tilt, or the eraser end. Pressure alone is not
## enough, because some touch screens report a fractional pressure for a finger.
func _is_clearly_pen(tilt: Vector2, inverted: bool) -> bool:
	return inverted or tilt != Vector2.ZERO


func _set_kind(kind: DeviceKind) -> void:
	if kind == _last_kind:
		return
	_last_kind = kind
	device_kind_changed.emit(kind)


func _on_window_size_changed() -> void:
	posture_changed.emit(get_window().size)
