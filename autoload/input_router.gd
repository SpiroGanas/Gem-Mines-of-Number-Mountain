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
## Palm rejection during pen strokes arrives with the chalk slate in Phase 2; this is
## the single place it will be added.
extends Node

enum DeviceKind { TOUCH, PEN, MOUSE, KEYBOARD }

signal pointer_down(pos: Vector2, kind: DeviceKind, index: int)
signal pointer_move(pos: Vector2, kind: DeviceKind, index: int)
signal pointer_up(pos: Vector2, kind: DeviceKind, index: int)
## The last kind of device used changed. Drives hints such as "tap" vs. "click".
signal device_kind_changed(kind: DeviceKind)
## The window changed size: a posture switch on a 2-in-1, a resize on desktop.
signal posture_changed(size: Vector2i)
## Escape was pressed.
signal pause_requested

const NO_TOUCH: int = -1

var _last_kind: DeviceKind = DeviceKind.TOUCH
var _mouse_seen: bool = false
var _active_touch: int = NO_TOUCH
var _mouse_down: bool = false


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
		if _active_touch != NO_TOUCH:
			return # a second finger: ignore
		_active_touch = event.index
		_set_kind(DeviceKind.TOUCH)
		pointer_down.emit(event.position, DeviceKind.TOUCH, event.index)
	elif event.index == _active_touch:
		_active_touch = NO_TOUCH
		pointer_up.emit(event.position, DeviceKind.TOUCH, event.index)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _active_touch:
		return
	var kind: DeviceKind = DeviceKind.PEN if _looks_like_pen(event.pressure, event.tilt, event.pen_inverted) else DeviceKind.TOUCH
	_set_kind(kind)
	pointer_move.emit(event.position, kind, event.index)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_seen = true
	_set_kind(DeviceKind.MOUSE)
	if event.pressed:
		_mouse_down = true
		pointer_down.emit(event.position, DeviceKind.MOUSE, 0)
	elif _mouse_down:
		_mouse_down = false
		pointer_up.emit(event.position, DeviceKind.MOUSE, 0)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	_mouse_seen = true
	if not _mouse_down:
		return
	var kind: DeviceKind = DeviceKind.PEN if _looks_like_pen(event.pressure, event.tilt, event.pen_inverted) else DeviceKind.MOUSE
	_set_kind(kind)
	pointer_move.emit(event.position, kind, 0)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
	if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return # a lone modifier is not "using the keyboard"
	_set_kind(DeviceKind.KEYBOARD)


## Best-effort stylus detection: a pen reports pressure strictly between 0 and 1, a tilt,
## or an inverted (eraser) end; a mouse reports a flat 0 or 1. How a ChromeOS stylus
## actually arrives is recorded by the Sprint 1 device test (docs/decisions.md); until then
## PEN is treated exactly like TOUCH by every consumer.
func _looks_like_pen(pressure: float, tilt: Vector2, inverted: bool) -> bool:
	return inverted or tilt != Vector2.ZERO or (pressure > 0.0 and pressure < 1.0)


func _set_kind(kind: DeviceKind) -> void:
	if kind == _last_kind:
		return
	_last_kind = kind
	device_kind_changed.emit(kind)


func _on_window_size_changed() -> void:
	posture_changed.emit(get_window().size)
