# Mirrors scenes/mine/boulder_split/boulder_split.gd (Sprint 15): split points from factors, a drag
# with finger, pen and mouse, a tap, the prime bounce, and the panel hook (meta.boulder_split).
class_name BoulderSplitTest
extends GdUnitTestSuite

const PEN_TILT: Vector2 = Vector2(0.2, 0.1)

var _router: Node
var _split: BoulderSplit
var _splits: Array[Vector3i] = []
var _primes: Array[int] = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_splits.clear()
	_primes.clear()
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(value: int, factors: Array[int]) -> BoulderSplit:
	_split = load("res://scenes/mine/boulder_split/boulder_split.tscn").instantiate()
	_split.router = _router
	_split.speed_scale = 30.0
	_split.size = Vector2(1200, 800)
	add_child(_split)
	auto_free(_split)
	_split.split_chosen.connect(func(v: int, a: int, b: int) -> void: _splits.append(Vector3i(v, a, b)))
	_split.prime_declared.connect(func(v: int) -> void: _primes.append(v))
	_split.setup(value, factors)
	await await_idle_frame()
	await await_idle_frame()
	return _split


func _drag_to_notch(index: int, kind: String = "finger") -> void:
	var start: Vector2 = _split.pickaxe().get_global_rect().get_center()
	var target: Vector2 = _split.notches()[index].get_global_rect().get_center()
	InputSim.touch(_router, start, true)
	for step: int in range(1, 5):
		var at: Vector2 = start.lerp(target, float(step) / 4.0)
		if kind == "pen":
			InputSim.drag(_router, at, 0, 0.5, PEN_TILT)
		else:
			InputSim.drag(_router, at)
	InputSim.touch(_router, target, false)


func test_the_split_points_are_the_factor_pairs_smallest_first_without_repeats() -> void:
	assert_array(BoulderSplit.pairs_for(12, [2, 3, 4, 6])).is_equal([Vector2i(2, 6), Vector2i(3, 4)])
	assert_array(BoulderSplit.pairs_for(36, [6, 2, 18, 9, 4, 3, 12])).is_equal([Vector2i(2, 18), Vector2i(3, 12), Vector2i(4, 9), Vector2i(6, 6)])
	assert_array(BoulderSplit.pairs_for(16, [8, 4, 2])).is_equal([Vector2i(2, 8), Vector2i(4, 4)])


func test_numbers_that_are_not_factors_never_become_split_points() -> void:
	assert_array(BoulderSplit.pairs_for(12, [5, 7, 12, 1, 0, 24])).is_equal([Vector2i(1, 12)])


func test_a_prime_has_only_the_trivial_split_point() -> void:
	assert_array(BoulderSplit.pairs_for(7, [])).is_equal([Vector2i(1, 7)])
	assert_array(BoulderSplit.pairs_for(2, [])).is_equal([Vector2i(1, 2)])


func test_the_boulder_shows_its_number_and_one_big_button_per_split_point() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	assert_str(split.boulder_text()).is_equal("12")
	assert_int(split.notches().size()).is_equal(2)
	assert_str(split.notches()[0].text).is_equal("2 × 6")
	for notch: Button in split.notches():
		assert_float(notch.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(notch.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	assert_float(split.pickaxe().custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
	assert_str(split.message_text()).is_equal(Text.get_line(&"z4.split.prompt"))


func test_dragging_the_pickaxe_to_a_split_point_cracks_the_boulder_in_two() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	_drag_to_notch(1)
	assert_array(_splits).is_equal([Vector3i(12, 3, 4)])
	assert_bool(split.is_done()).is_true()
	assert_int(split.pieces().size()).is_equal(2)
	assert_str(split.message_text()).is_equal("12 cracked into 3 and 4!")
	assert_bool(split.pickaxe().visible).is_false()


func test_the_same_drag_works_with_a_pen_and_with_a_mouse() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	_drag_to_notch(0, "pen")
	assert_array(_splits).is_equal([Vector3i(12, 2, 6)])
	split = await _make(20, [2, 4, 5, 10])
	var start: Vector2 = split.pickaxe().get_global_rect().get_center()
	var target: Vector2 = split.notches()[1].get_global_rect().get_center()
	InputSim.mouse_button(_router, start, true)
	InputSim.mouse_move(_router, start.lerp(target, 0.5))
	InputSim.mouse_move(_router, target)
	InputSim.mouse_button(_router, target, false)
	assert_array(_splits).contains([Vector3i(20, 4, 5)])


func test_a_tap_on_a_split_point_works_without_dragging() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	split.notches()[0].pressed.emit()
	assert_array(_splits).is_equal([Vector3i(12, 2, 6)])


func test_dropping_the_pickaxe_on_nothing_loses_nothing() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	var start: Vector2 = split.pickaxe().get_global_rect().get_center()
	InputSim.touch(_router, start, true)
	InputSim.drag(_router, Vector2(900, 80))
	InputSim.touch(_router, Vector2(900, 80), false)
	assert_array(_splits).is_empty()
	assert_bool(split.is_done()).is_false()
	assert_bool(split.pickaxe().get_global_rect().has_point(start)).is_true() # back on the rail


func test_a_touch_that_misses_the_pickaxe_moves_nothing() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	InputSim.touch(_router, Vector2(5, 5), true)
	InputSim.drag(_router, split.notches()[0].get_global_rect().get_center())
	InputSim.touch(_router, split.notches()[0].get_global_rect().get_center(), false)
	assert_array(_splits).is_empty()


func test_a_prime_boulder_bounces_the_pickaxe_and_turns_into_a_gem() -> void:
	var split: BoulderSplit = await _make(7, [])
	assert_int(split.notches().size()).is_equal(1)
	_drag_to_notch(0)
	assert_array(_primes).is_equal([7])
	assert_array(_splits).is_empty()
	assert_str(split.message_text()).is_equal("7 is a prime. It won't break!")
	assert_bool(split.is_done()).is_true()


func test_pieces_that_are_prime_show_as_gems_and_the_rest_can_split_again() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	split.choose_pair(2) # 2 x 6: the 2 is prime, the 6 is not
	assert_bool(split.pieces()[0].get("is_gem")).is_true()
	assert_bool(split.pieces()[1].get("is_gem")).is_false()


func test_a_disabled_boulder_ignores_drags_and_taps() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	split.set_enabled(false)
	assert_bool(split.choose_pair(2)).is_false()
	_drag_to_notch(0)
	assert_array(_splits).is_empty()


func test_after_a_split_that_was_not_the_answer_the_boulder_is_whole_again() -> void:
	var split: BoulderSplit = await _make(12, [2, 3, 4, 6])
	split.choose_pair(3)
	split.set_enabled(false)
	split.set_enabled(true)
	assert_bool(split.is_done()).is_false()
	assert_int(split.pieces().size()).is_equal(0)
	assert_int(split.notches().size()).is_equal(2)
	split.choose_pair(2)
	assert_array(_splits).is_equal([Vector3i(12, 3, 4), Vector3i(12, 2, 6)])


func test_the_panel_hosts_the_boulder_for_a_split_problem() -> void:
	var problem: Problem = Problem.new()
	problem.skill_id = &"fac.pairs.test"
	problem.answer = [3, 4]
	problem.answer_modes = [&"drag"]
	problem.meta = {"boulder_split": {"value": 12, "factors": [2, 3, 4, 6]}}
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.SPLIT)
	assert_float(AnswerPanel.chance_for(problem)).is_equal_approx(0.5, 0.0001)
	assert_str(AnswerPanel.answer_mode_for(problem)).is_equal("drag")
	var panel: AnswerPanel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	panel.size = Vector2(1200, 800)
	add_child(panel)
	auto_free(panel)
	var given: Array = []
	panel.answered.connect(func(value: Variant) -> void: given.append(value))
	panel.setup(problem, RandomNumberGenerator.new())
	panel.set_enabled(true)
	await await_idle_frame()
	assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.SPLIT)
	panel.boulder_split().choose_pair(3)
	assert_array(given).is_equal([[3, 4]])
	assert_bool(problem.is_correct(given[0])).is_true()
