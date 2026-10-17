# Mirrors scenes/input/chalk_slate/digit_box.gd. A private InputRouter feeds synthetic strokes
# (InputSim), so finger, pen and palm are all exercised without the engine delivering input.
class_name DigitBoxTest
extends GdUnitTestSuite

const PEN_TILT: Vector2 = Vector2(0.2, 0.1)

var _router: Node
var _box: DigitBox


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)
	_box = load("res://scenes/input/chalk_slate/digit_box.tscn").instantiate()
	_box.router = _router
	_box.position = Vector2(100, 100)
	add_child(_box)
	auto_free(_box)
	_box.size = _box.custom_minimum_size # no container here to lay it out


func after_test() -> void:
	TestWindow.restore(get_window())


## A stroke through `fractions` (x, y from 0 to 1 of the box) with a finger.
func _stroke(fractions: Array, index: int = 0) -> void:
	var rect: Rect2 = _box.get_global_rect()
	var points: Array[Vector2] = []
	for f: Vector2 in fractions:
		points.append(rect.position + f * rect.size)
	InputSim.touch(_router, points[0], true, index)
	for i: int in range(1, points.size()):
		InputSim.drag(_router, points[i], index)
	InputSim.touch(_router, points[points.size() - 1], false, index)


func test_the_box_is_at_least_two_touch_targets_wide_and_three_tall() -> void:
	assert_float(_box.custom_minimum_size.x).is_greater_equal(2.0 * UI.min_target_px())
	assert_float(_box.custom_minimum_size.y).is_greater_equal(3.0 * UI.min_target_px())


func test_a_stroke_inside_the_box_is_kept_and_normalized_to_the_box() -> void:
	monitor_signals(_box)
	_stroke([Vector2(0.2, 0.1), Vector2(0.5, 0.5), Vector2(0.8, 0.9)])
	await assert_signal(_box).is_emitted("strokes_changed")
	assert_bool(_box.has_ink()).is_true()
	var strokes: Array[PackedVector2Array] = _box.strokes()
	assert_int(strokes.size()).is_equal(1)
	for point: Vector2 in strokes[0]:
		assert_float(point.x).is_between(0.0, 1.0)
		assert_float(point.y).is_between(0.0, 1.0)
	assert_float(strokes[0][0].x).is_equal_approx(0.2, 0.01)
	assert_float(strokes[0][strokes[0].size() - 1].y).is_equal_approx(0.9, 0.01)


func test_a_stroke_that_starts_outside_the_box_writes_nothing() -> void:
	InputSim.touch(_router, Vector2(2000, 2000), true)
	InputSim.drag(_router, _box.get_global_rect().get_center())
	InputSim.touch(_router, _box.get_global_rect().get_center(), false)
	assert_bool(_box.has_ink()).is_false()


func test_sliding_out_of_the_box_keeps_the_stroke_on_the_edge() -> void:
	var rect: Rect2 = _box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.5, 0.5), true)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.9, 0.5))
	InputSim.drag(_router, rect.position + rect.size * Vector2(1.6, 0.5))
	InputSim.touch(_router, rect.position + rect.size * Vector2(1.6, 0.5), false)
	var points: PackedVector2Array = _box.strokes()[0]
	assert_float(points[points.size() - 1].x).is_equal_approx(1.0, 0.001)


func test_a_touch_that_is_only_a_dot_is_not_a_stroke() -> void:
	var centre: Vector2 = _box.get_global_rect().get_center()
	InputSim.touch(_router, centre, true)
	InputSim.drag(_router, centre + Vector2(1, 1))
	InputSim.touch(_router, centre + Vector2(1, 1), false)
	assert_bool(_box.has_ink()).is_false()


func test_close_points_are_thinned_and_a_stroke_is_capped() -> void:
	var rect: Rect2 = _box.get_global_rect()
	InputSim.touch(_router, rect.position + Vector2(10, 10), true)
	for i: int in 600: # a very long scribble in tiny steps
		InputSim.drag(_router, rect.position + Vector2(10 + (i % 100) * 1.0, 10 + (i / 100) * 20.0))
	InputSim.touch(_router, rect.position + Vector2(50, 100), false)
	assert_int(_box.strokes()[0].size()).is_less_equal(DigitBox.MAX_POINTS_PER_STROKE)


func test_a_palm_resting_on_the_box_while_the_pen_writes_adds_no_stroke() -> void:
	var rect: Rect2 = _box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.3, 0.2), true, 0)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.4, 0.4), 0, 0.5, PEN_TILT)
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.9, 0.9), true, 1) # the palm
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.9, 0.8), 1, 1.0)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.5, 0.7), 0, 0.5, PEN_TILT)
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.5, 0.7), false, 0)
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.9, 0.8), false, 1)
	var strokes: Array[PackedVector2Array] = _box.strokes()
	assert_int(strokes.size()).is_equal(1)
	for point: Vector2 in strokes[0]:
		assert_float(point.x).is_less(0.6) # nothing from the palm at x = 0.9


func test_a_palm_that_was_there_first_is_dropped_when_the_pen_arrives() -> void:
	var rect: Rect2 = _box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.9, 0.9), true, 0) # palm first
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.88, 0.85), 0, 1.0)
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.2, 0.2), true, 1) # then the pen
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.4, 0.5), 1, 0.5, PEN_TILT)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.6, 0.8), 1, 0.5, PEN_TILT)
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.6, 0.8), false, 1)
	var strokes: Array[PackedVector2Array] = _box.strokes()
	assert_int(strokes.size()).is_equal(1)
	assert_float(strokes[0][0].x).is_equal_approx(0.2, 0.02)


func test_clear_discards_every_stroke_and_the_flag() -> void:
	_stroke([Vector2(0.2, 0.1), Vector2(0.8, 0.9)])
	_box.set_flagged(true)
	_box.clear()
	assert_bool(_box.has_ink()).is_false()
	assert_bool(_box.is_flagged()).is_false()
	assert_array(_box.strokes()).is_empty()


func test_a_disabled_box_ignores_strokes_and_drops_one_in_progress() -> void:
	_box.set_enabled(false)
	_stroke([Vector2(0.2, 0.1), Vector2(0.8, 0.9)])
	assert_bool(_box.has_ink()).is_false()
	_box.set_enabled(true)
	var rect: Rect2 = _box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.2, 0.2), true)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.5, 0.5))
	assert_bool(_box.is_drawing()).is_true()
	_box.set_enabled(false)
	assert_bool(_box.is_drawing()).is_false()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.5, 0.5), false)
	assert_bool(_box.has_ink()).is_false()


func test_a_new_stroke_clears_the_flag() -> void:
	_box.set_flagged(true)
	_stroke([Vector2(0.2, 0.1), Vector2(0.8, 0.9)])
	assert_bool(_box.is_flagged()).is_false()


func test_the_strokes_it_hands_out_are_a_copy() -> void:
	_stroke([Vector2(0.2, 0.1), Vector2(0.8, 0.9)])
	var copy: Array[PackedVector2Array] = _box.strokes()
	copy.clear()
	assert_int(_box.strokes().size()).is_equal(1)


func test_resizing_the_box_mid_stroke_rescales_the_drawing_without_losing_or_distorting_it() -> void:
	var rect: Rect2 = _box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.2, 0.2), true)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.5, 0.5))
	_box.size = _box.size * 1.5 # a posture change makes the box bigger while the stroke is in progress
	InputSim.drag(_router, _box.get_global_rect().position + _box.size * Vector2(0.8, 0.8))
	InputSim.touch(_router, _box.get_global_rect().position + _box.size * Vector2(0.8, 0.8), false)
	var points: PackedVector2Array = _box.strokes()[0]
	assert_float(points[0].x).is_equal_approx(0.2, 0.01)
	assert_float(points[1].y).is_equal_approx(0.5, 0.01) # drawn before the resize, still where it was
	assert_float(points[points.size() - 1].x).is_equal_approx(0.8, 0.01)
