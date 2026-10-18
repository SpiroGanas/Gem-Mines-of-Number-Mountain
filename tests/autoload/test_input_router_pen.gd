# Mirrors the stroke signals and palm rejection of autoload/input_router.gd (Sprint 14).
# Synthetic events only: a pen drag carries a tilt (or the eraser end), a palm or finger does not.
class_name InputRouterPenTest
extends GdUnitTestSuite

const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"
const PEN_TILT: Vector2 = Vector2(0.2, 0.1)

var _router: Node
var _log: Array[String] = []


func before_test() -> void:
	_log.clear()
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router)
	_router.pointer_down.connect(func(pos: Vector2, kind: int, index: int) -> void: _log.append("down %d %d" % [kind, index]))
	_router.pointer_up.connect(func(pos: Vector2, kind: int, index: int) -> void: _log.append("up %d %d" % [kind, index]))
	_router.pointer_cancelled.connect(func(index: int) -> void: _log.append("dropped %d" % index))
	_router.stroke_started.connect(func(pos: Vector2, pressure: float, is_pen: bool) -> void: _log.append("start %s %s" % [pos, is_pen]))
	_router.stroke_moved.connect(func(pos: Vector2, pressure: float) -> void: _log.append("stroke %s %.2f" % [pos, pressure]))
	_router.stroke_ended.connect(func() -> void: _log.append("end"))
	_router.stroke_cancelled.connect(func() -> void: _log.append("cancel"))


func _strokes() -> Array[String]:
	return _log.filter(func(line: String) -> bool: return line.begins_with("start") or line.begins_with("stroke") or line == "end" or line == "cancel")


func test_a_finger_stroke_reports_start_moves_and_end_with_full_pressure() -> void:
	InputSim.drag_path(_router, Vector2(10, 10), Vector2(50, 10), 2)
	assert_array(_strokes()).is_equal(["start (10.0, 10.0) false", "stroke (30.0, 10.0) 1.00", "stroke (50.0, 10.0) 1.00", "end"])
	assert_bool(_router.pen_stroke_active).is_false()


func test_a_pen_drag_carries_its_pressure_and_marks_the_pen_stroke_active() -> void:
	InputSim.touch(_router, Vector2(10, 10), true)
	InputSim.drag(_router, Vector2(20, 10), 0, 0.4, PEN_TILT)
	assert_bool(_router.pen_stroke_active).is_true()
	assert_array(_strokes()).contains(["stroke (20.0, 10.0) 0.40"])
	InputSim.touch(_router, Vector2(20, 10), false)
	assert_bool(_router.pen_stroke_active).is_false()


func test_a_palm_that_lands_while_the_pen_writes_adds_nothing() -> void:
	InputSim.touch(_router, Vector2(10, 10), true, 0)
	InputSim.drag(_router, Vector2(20, 10), 0, 0.4, PEN_TILT)
	var before: Array[String] = _log.duplicate()
	InputSim.touch(_router, Vector2(300, 300), true, 1) # the palm
	InputSim.drag(_router, Vector2(310, 305), 1, 0.9)
	InputSim.drag(_router, Vector2(320, 310), 1, 0.9)
	InputSim.touch(_router, Vector2(320, 310), false, 1)
	assert_array(_log).is_equal(before)
	InputSim.drag(_router, Vector2(30, 10), 0, 0.5, PEN_TILT) # the pen goes on
	assert_array(_strokes()).contains(["stroke (30.0, 10.0) 0.50"])


func test_a_pen_that_arrives_after_a_resting_palm_takes_the_stroke_over() -> void:
	InputSim.touch(_router, Vector2(300, 300), true, 0) # the palm rests first
	InputSim.drag(_router, Vector2(302, 301), 0, 1.0)
	InputSim.touch(_router, Vector2(40, 40), true, 1) # then the pen comes down
	InputSim.drag(_router, Vector2(50, 40), 1, 0.5, PEN_TILT)
	assert_array(_strokes()).is_equal([
		"start (300.0, 300.0) false", "stroke (302.0, 301.0) 1.00",
		"cancel", "start (40.0, 40.0) true", "stroke (50.0, 40.0) 0.50",
	])
	# the palm is cancelled, never lifted (a lift would be a tap or a drop on a drag board); the pen goes down (PEN, index 1)
	assert_array(_log).contains(["dropped 0", "down 1 1"])
	assert_array(_log).not_contains(["up 0 0"])
	# the palm's later movement and lift change nothing
	var count: int = _log.size()
	InputSim.drag(_router, Vector2(305, 303), 0, 1.0)
	InputSim.touch(_router, Vector2(305, 303), false, 0)
	assert_int(_log.size()).is_equal(count)
	InputSim.touch(_router, Vector2(60, 40), false, 1)
	assert_str(_strokes().back()).is_equal("end")


func test_a_second_finger_never_takes_over_from_a_finger() -> void:
	InputSim.touch(_router, Vector2(10, 10), true, 0)
	InputSim.touch(_router, Vector2(200, 10), true, 1)
	InputSim.drag(_router, Vector2(210, 10), 1, 0.5) # fractional pressure but no tilt: still not a pen
	assert_array(_strokes()).is_equal(["start (10.0, 10.0) false"])


func test_a_stylus_sent_as_mouse_motion_makes_touches_palms() -> void:
	InputSim.mouse_button(_router, Vector2(10, 10), true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(20, 10)
	motion.pressure = 0.5
	motion.tilt = PEN_TILT
	_router.process_event(motion)
	assert_bool(_router.pen_stroke_active).is_true()
	assert_array(_strokes()).contains(["stroke (20.0, 10.0) 0.50"])
	var before: int = _log.size()
	InputSim.tap(_router, Vector2(300, 300), 3) # a palm on the touch screen
	assert_int(_log.size()).is_equal(before)
	InputSim.mouse_button(_router, Vector2(20, 10), false)
	assert_bool(_router.pen_stroke_active).is_false()
	assert_str(_strokes().back()).is_equal("end")


func test_a_mouse_click_and_drag_make_a_stroke() -> void:
	InputSim.mouse_button(_router, Vector2(10, 10), true)
	InputSim.mouse_move(_router, Vector2(30, 10))
	InputSim.mouse_button(_router, Vector2(30, 10), false)
	assert_array(_strokes()).is_equal(["start (10.0, 10.0) false", "stroke (30.0, 10.0) 1.00", "end"])
