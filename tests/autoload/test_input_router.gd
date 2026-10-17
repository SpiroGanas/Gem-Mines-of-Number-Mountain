# Mirrors autoload/input_router.gd. A fresh router per test; events are synthetic (InputSim).
class_name InputRouterTest
extends GdUnitTestSuite

const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"

var _router: Node
var _log: Array[String] = []


func before_test() -> void:
	_log.clear()
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router) # in the tree so _ready runs and get_window() works
	_router.pointer_down.connect(func(pos: Vector2, kind: int, index: int) -> void: _log.append("down %s %d %d" % [pos, kind, index]))
	_router.pointer_move.connect(func(pos: Vector2, kind: int, index: int) -> void: _log.append("move %s %d %d" % [pos, kind, index]))
	_router.pointer_up.connect(func(pos: Vector2, kind: int, index: int) -> void: _log.append("up %s %d %d" % [pos, kind, index]))


func test_a_tap_reports_down_then_up_once() -> void:
	InputSim.tap(_router, Vector2(100, 200))
	assert_array(_log).has_size(2)
	assert_str(_log[0]).starts_with("down")
	assert_str(_log[1]).starts_with("up")


func test_a_drag_reports_moves_between_down_and_up() -> void:
	InputSim.drag_path(_router, Vector2(0, 0), Vector2(100, 0), 4)
	assert_array(_log).has_size(6) # down + 4 moves + up
	assert_str(_log[0]).starts_with("down")
	assert_str(_log[1]).starts_with("move")
	assert_str(_log[5]).starts_with("up (100.0, 0.0)")


func test_only_the_first_finger_counts() -> void:
	InputSim.touch(_router, Vector2(10, 10), true, 0)
	InputSim.touch(_router, Vector2(300, 300), true, 1) # second finger: ignored
	InputSim.drag(_router, Vector2(300, 320), 1) # its drag: ignored
	InputSim.touch(_router, Vector2(300, 300), false, 1) # its release: ignored
	assert_array(_log).has_size(1)
	InputSim.touch(_router, Vector2(10, 10), false, 0)
	assert_array(_log).has_size(2)


func test_a_new_touch_is_accepted_after_the_first_finger_lifts() -> void:
	InputSim.tap(_router, Vector2(1, 1), 0)
	InputSim.tap(_router, Vector2(2, 2), 1)
	assert_array(_log).has_size(4)


func test_emulated_mouse_events_from_touch_are_ignored() -> void:
	# Android makes a mouse event for every touch; counting it would report each tap twice.
	InputSim.mouse_button(_router, Vector2(5, 5), true, MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)
	InputSim.mouse_button(_router, Vector2(5, 5), false, MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)
	assert_array(_log).is_empty()
	assert_bool(_router.is_touch_first()).is_true()


func test_a_real_mouse_click_and_drag_work_like_touch() -> void:
	InputSim.mouse_button(_router, Vector2(10, 10), true)
	InputSim.mouse_move(_router, Vector2(20, 10))
	InputSim.mouse_button(_router, Vector2(20, 10), false)
	assert_array(_log).has_size(3)
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.MOUSE)
	assert_bool(_router.is_touch_first()).is_false()


func test_mouse_motion_without_a_pressed_button_is_not_a_drag() -> void:
	InputSim.mouse_move(_router, Vector2(50, 50))
	assert_array(_log).is_empty()


func test_only_the_left_mouse_button_counts() -> void:
	InputSim.mouse_button(_router, Vector2(1, 1), true, MOUSE_BUTTON_RIGHT)
	assert_array(_log).is_empty()


func test_device_kind_changes_are_announced_once() -> void:
	monitor_signals(_router)
	InputSim.tap(_router, Vector2.ZERO) # already TOUCH: no change
	InputSim.mouse_button(_router, Vector2.ZERO, true) # MOUSE
	InputSim.mouse_button(_router, Vector2.ZERO, false)
	await assert_signal(_router).is_emitted("device_kind_changed", [InputRouter.DeviceKind.MOUSE])
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.MOUSE)
	InputSim.tap(_router, Vector2.ZERO)
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.TOUCH)


func test_pressure_or_tilt_marks_a_stylus_but_it_still_drags_like_touch() -> void:
	InputSim.touch(_router, Vector2(0, 0), true)
	InputSim.drag(_router, Vector2(5, 5), 0, 0.4, Vector2(0.2, 0.0))
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.PEN)
	assert_array(_log).has_size(2) # down + move: the pen is not filtered out
	InputSim.touch(_router, Vector2(5, 5), false)


func test_a_flat_drag_is_touch() -> void:
	InputSim.touch(_router, Vector2(0, 0), true)
	InputSim.drag(_router, Vector2(5, 5), 0, 0.0)
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.TOUCH)
	InputSim.touch(_router, Vector2(5, 5), false)


func test_escape_requests_pause_and_switches_to_keyboard() -> void:
	monitor_signals(_router)
	InputSim.key(_router, KEY_ESCAPE)
	await assert_signal(_router).is_emitted("pause_requested")
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.KEYBOARD)


func test_a_lone_modifier_key_is_not_keyboard_use() -> void:
	InputSim.key(_router, KEY_SHIFT)
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.TOUCH)


func test_key_release_and_echo_do_nothing() -> void:
	monitor_signals(_router)
	InputSim.key(_router, KEY_ESCAPE, false)
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_ESCAPE
	echo.pressed = true
	echo.echo = true
	_router.process_event(echo)
	await assert_signal(_router).is_not_emitted("pause_requested")


func test_posture_changed_carries_the_window_size() -> void:
	monitor_signals(_router)
	_router._on_window_size_changed()
	await assert_signal(_router).is_emitted("posture_changed", [get_window().size])
