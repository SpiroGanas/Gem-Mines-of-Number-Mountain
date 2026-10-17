# Mirrors scenes/input/array_builder.gd: building an array by dragging or tapping, with finger,
# pen and mouse events through a private InputRouter.
class_name ArrayBuilderTest
extends GdUnitTestSuite

var _router: Node


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)


func after_test() -> void:
	get_tree().paused = false
	TestWindow.restore(get_window())


func _make() -> ArrayBuilder:
	var builder: ArrayBuilder = load("res://scenes/input/array_builder.tscn").instantiate()
	builder.router = _router
	builder.size = Vector2(900, 700)
	add_child(builder)
	auto_free(builder)
	await get_tree().process_frame
	await get_tree().process_frame
	return builder


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_dragging_from_the_corner_builds_rows_and_columns() -> void:
	var builder: ArrayBuilder = await _make()
	InputSim.drag_path(_router, _center(builder.cell(0, 0)), _center(builder.cell(2, 3)), 8)
	assert_dict(builder.answer()).is_equal({"rows": 3, "cols": 4})
	assert_bool(builder.is_filled(2, 3)).is_true()
	assert_bool(builder.is_filled(3, 0)).is_false()


func test_a_tap_on_a_cell_builds_up_to_it_and_done_reports_it() -> void:
	var builder: ArrayBuilder = await _make()
	var given: Array = []
	builder.submitted.connect(func(answer: Dictionary) -> void: given.append(answer))
	assert_bool(builder.done_button().disabled).is_true()
	InputSim.tap(_router, _center(builder.cell(1, 4)))
	builder.done_button().pressed.emit()
	assert_array(given).contains_exactly([{"rows": 2, "cols": 5}])


func test_mouse_and_pen_work_like_a_finger() -> void:
	var builder: ArrayBuilder = await _make()
	InputSim.mouse_button(_router, _center(builder.cell(0, 0)), true)
	InputSim.mouse_move(_router, _center(builder.cell(3, 1)))
	InputSim.mouse_button(_router, _center(builder.cell(3, 1)), false)
	assert_dict(builder.answer()).is_equal({"rows": 4, "cols": 2})
	InputSim.touch(_router, _center(builder.cell(0, 0)), true)
	InputSim.drag(_router, _center(builder.cell(1, 2)), 0, 0.5, Vector2(0.3, 0.0))
	InputSim.touch(_router, _center(builder.cell(1, 2)), false)
	assert_dict(builder.answer()).is_equal({"rows": 2, "cols": 3})


func test_moving_without_pressing_changes_nothing_and_a_disabled_builder_ignores_input() -> void:
	var builder: ArrayBuilder = await _make()
	InputSim.mouse_move(_router, _center(builder.cell(2, 2)))
	assert_dict(builder.answer()).is_equal({"rows": 0, "cols": 0})
	builder.set_enabled(false)
	InputSim.tap(_router, _center(builder.cell(2, 2)))
	assert_dict(builder.answer()).is_equal({"rows": 0, "cols": 0})


func test_every_cell_is_a_full_touch_target() -> void:
	var builder: ArrayBuilder = await _make()
	assert_float(builder.cell(0, 0).custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
	assert_float(builder.cell(4, 4).size.y).is_greater_equal(float(UI.min_target_px()))


func test_a_paused_builder_ignores_taps_and_drags() -> void:
	var builder: ArrayBuilder = await _make()
	InputSim.touch(_router, _center(builder.cell(0, 0)), true)
	get_tree().paused = true
	InputSim.drag(_router, _center(builder.cell(3, 3))) # the press before the pause does not carry on
	InputSim.touch(_router, _center(builder.cell(3, 3)), false)
	InputSim.tap(_router, _center(builder.cell(2, 2)))
	get_tree().paused = false
	assert_dict(builder.answer()).is_equal({"rows": 1, "cols": 1})
	InputSim.tap(_router, _center(builder.cell(2, 2)))
	assert_dict(builder.answer()).is_equal({"rows": 3, "cols": 3})
