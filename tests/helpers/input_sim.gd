## Builds synthetic InputEvents and feeds them to an InputRouter, so tests can tap and
## drag without the engine delivering real input (it does not in headless CI; see the
## GdUnit4 entry in docs/decisions.md). Not shipped: tests/ is excluded from exports.
class_name InputSim
extends RefCounted


static func touch(router: Node, pos: Vector2, pressed: bool, index: int = 0) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	router.process_event(event)


static func drag(router: Node, pos: Vector2, index: int = 0, pressure: float = 0.0, tilt: Vector2 = Vector2.ZERO) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.pressure = pressure
	event.tilt = tilt
	router.process_event(event)


## Finger down, finger up, at one point.
static func tap(router: Node, pos: Vector2, index: int = 0) -> void:
	touch(router, pos, true, index)
	touch(router, pos, false, index)


## Finger down at `from`, `steps` drag events along a straight line, finger up at `to`.
static func drag_path(router: Node, from: Vector2, to: Vector2, steps: int = 5, index: int = 0) -> void:
	touch(router, from, true, index)
	for step: int in range(1, steps + 1):
		drag(router, from.lerp(to, float(step) / float(steps)), index)
	touch(router, to, false, index)


static func mouse_button(router: Node, pos: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT, device: int = 0) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.position = pos
	event.pressed = pressed
	event.device = device
	router.process_event(event)


static func mouse_move(router: Node, pos: Vector2, device: int = 0) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = pos
	event.device = device
	router.process_event(event)


static func key(target: Object, keycode: Key, pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	if target.has_method("process_event"):
		target.process_event(event)
	elif target.has_method("handle_key_event"):
		target.handle_key_event(event)
	return event
