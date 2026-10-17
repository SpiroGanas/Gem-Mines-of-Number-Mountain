# Mirrors scenes/input/choice_buttons.tscn.
class_name ChoiceButtonsTest
extends GdUnitTestSuite

const SCENE: String = "res://scenes/input/choice_buttons.tscn"

var _choices: ChoiceButtons


func before_test() -> void:
	_choices = load(SCENE).instantiate()
	add_child(_choices)
	auto_free(_choices)


func _options(values: Array) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for value: Variant in values:
		options.append({"value": value, "label": str(value)})
	return options


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_every_option_appears_exactly_once_whatever_the_seed() -> void:
	for seed_value: int in range(1, 60):
		_choices.setup(_options([34, 43, 7, 70]), _rng(seed_value))
		var shown: Array = _choices.values_in_order()
		shown.sort()
		assert_array(shown).override_failure_message("seed %d" % seed_value).contains_exactly([7, 34, 43, 70])
		assert_int(_choices.button_count()).is_equal(4)


func test_the_same_seed_gives_the_same_order() -> void:
	_choices.setup(_options([1, 2, 3, 4]), _rng(99))
	var first: Array = _choices.values_in_order()
	_choices.setup(_options([1, 2, 3, 4]), _rng(99))
	assert_array(_choices.values_in_order()).is_equal(first)


func test_different_seeds_do_not_always_give_the_same_order() -> void:
	var orders: Dictionary[String, bool] = {}
	for seed_value: int in range(1, 40):
		_choices.setup(_options([1, 2, 3, 4]), _rng(seed_value))
		orders[str(_choices.values_in_order())] = true
	assert_int(orders.size()).is_greater(8)


func test_the_right_answer_is_not_always_first() -> void:
	var first_counts: Dictionary[int, int] = {}
	for seed_value: int in range(1, 200):
		_choices.setup(_options([10, 20, 30]), _rng(seed_value))
		var first: int = _choices.values_in_order()[0]
		first_counts[first] = first_counts.get(first, 0) + 1
	assert_int(first_counts.size()).is_equal(3)
	for count: int in first_counts.values():
		assert_int(count).is_greater(30) # roughly a third each


func test_labels_follow_their_values() -> void:
	var options: Array[Dictionary] = [{"value": &"lt", "label": "<"}, {"value": &"gt", "label": ">"}, {"value": &"eq", "label": "="}]
	_choices.setup(options, _rng(5))
	for i: int in 3:
		var value: StringName = _choices.values_in_order()[i]
		var expected: String = {&"lt": "<", &"gt": ">", &"eq": "="}[value]
		assert_str(_choices.button(i).text).is_equal(expected)


func test_pressing_a_button_reports_its_value() -> void:
	_choices.setup(_options([5, 6, 7]), _rng(3))
	var heard: Array = []
	_choices.chosen.connect(func(value: Variant) -> void: heard.append(value))
	_choices.button(1).pressed.emit()
	assert_array(heard).contains_exactly([_choices.values_in_order()[1]])


func test_values_can_be_arrays_and_dictionaries() -> void:
	var options: Array[Dictionary] = [{"value": [30, 4], "label": "30 + 4"}, {"value": {"tens": 3, "ones": 4}, "label": "3 tens 4 ones"}]
	_choices.setup(options, _rng(1))
	var heard: Array = []
	_choices.chosen.connect(func(value: Variant) -> void: heard.append(value))
	for i: int in 2:
		_choices.button(i).pressed.emit()
	assert_int(heard.size()).is_equal(2)


func test_buttons_are_full_size_touch_targets() -> void:
	_choices.setup(_options([1, 2, 3]), _rng(1))
	for i: int in 3:
		assert_float(_choices.button(i).custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(_choices.button(i).custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_a_disabled_set_ignores_presses_and_stays_disabled_after_a_new_setup() -> void:
	_choices.setup(_options([1, 2]), _rng(1))
	_choices.set_enabled(false)
	var heard: Array = []
	_choices.chosen.connect(func(value: Variant) -> void: heard.append(value))
	_choices.button(0).pressed.emit()
	assert_array(heard).is_empty()
	assert_bool(_choices.button(0).disabled).is_true()
	_choices.setup(_options([3, 4]), _rng(2))
	assert_bool(_choices.button(1).disabled).is_true()


func test_setup_again_replaces_the_buttons() -> void:
	_choices.setup(_options([1, 2, 3, 4]), _rng(1))
	_choices.setup(_options([8, 9]), _rng(1))
	assert_int(_choices.button_count()).is_equal(2)
