# Mirrors scenes/zones/z05_prime_caverns/sieve_grid.gd (Sprint 18): tap to cross out and back, rocks
# crossed from the start stay crossed, Done hands in every crossed rock, and every rock is a full touch
# target on a 10 x 10 grid even at 4:3.
class_name SieveGridTest
extends GdUnitTestSuite

var _grid: SieveGrid
var _handed_in: Array = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_handed_in.clear()


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(size: int, precrossed: Array) -> SieveGrid:
	_grid = load("res://scenes/zones/z05_prime_caverns/sieve_grid.tscn").instantiate()
	_grid.size = Vector2(1000, 900)
	add_child(_grid)
	auto_free(_grid)
	_grid.setup(size, 10, precrossed)
	_grid.submitted.connect(func(crossed: Array) -> void: _handed_in = crossed)
	await await_idle_frame()
	return _grid


func test_a_tap_crosses_a_rock_out_and_a_second_tap_brings_it_back() -> void:
	var grid: SieveGrid = await _make(30, [1])
	grid.cell(9).pressed.emit()
	assert_bool(grid.is_crossed(9)).is_true()
	grid.cell(9).pressed.emit()
	assert_bool(grid.is_crossed(9)).is_false()


func test_rocks_crossed_from_the_start_cannot_come_back() -> void:
	var grid: SieveGrid = await _make(30, [1, 4, 6])
	assert_bool(grid.is_crossed(4)).is_true()
	assert_bool(grid.toggle(4)).is_false()
	assert_bool(grid.is_crossed(4)).is_true()
	assert_bool(grid.cell(4).disabled).is_true()


func test_done_hands_in_every_crossed_rock_smallest_first() -> void:
	var grid: SieveGrid = await _make(20, [1, 4])
	for number: int in [15, 9, 6]:
		grid.toggle(number)
	grid.done_button().pressed.emit()
	assert_array(_handed_in).is_equal([1, 4, 6, 9, 15])


func test_a_disabled_grid_ignores_taps_and_done() -> void:
	var grid: SieveGrid = await _make(20, [])
	grid.set_enabled(false)
	assert_bool(grid.toggle(5)).is_false()
	grid.submit()
	assert_array(_handed_in).is_empty()
	grid.set_enabled(true)
	assert_bool(grid.toggle(5)).is_true()


func test_every_rock_is_at_least_a_touch_target_on_a_100_grid() -> void:
	var grid: SieveGrid = await _make(100, [])
	await await_idle_frame()
	var side: float = float(UI.min_target_px())
	for number: int in range(1, 101):
		var rect: Rect2 = grid.cell(number).get_global_rect()
		assert_bool(rect.size.x >= side and rect.size.y >= side).override_failure_message("rock %d is %s" % [number, rect.size]).is_true()
	assert_bool(grid.done_button().size.y >= side).is_true()


func test_ten_rocks_to_a_row_in_reading_order() -> void:
	var grid: SieveGrid = await _make(30, [])
	await await_idle_frame()
	var first: Rect2 = grid.cell(1).get_global_rect()
	assert_float(grid.cell(10).get_global_rect().position.y).is_equal_approx(first.position.y, 0.5)
	assert_bool(grid.cell(11).get_global_rect().position.y > first.position.y).is_true()
	assert_bool(grid.cell(2).get_global_rect().position.x > first.position.x).is_true()


func test_the_state_is_one_byte_per_rock_and_no_rock_is_rebuilt_on_a_tap() -> void:
	var grid: SieveGrid = await _make(50, [1])
	var before: Button = grid.cell(17)
	grid.toggle(17)
	assert_object(grid.cell(17)).is_same(before)
	assert_int(grid.crossed().size()).is_equal(2)


func test_the_mine_layout_at_4_to_3_keeps_full_size_rocks() -> void:
	# The answer area of the mine at 1440 x 1080 (4:3): the right column is about 5/9 of the width.
	get_window().size = Vector2i(1440, 1080)
	await await_idle_frame()
	var grid: SieveGrid = await _make(100, [])
	_grid.size = Vector2(730, 700)
	await await_idle_frame()
	var side: float = float(UI.min_target_px())
	assert_bool(grid.cell(100).get_global_rect().size.x >= side).is_true()
	assert_bool(grid.scroll().get_combined_minimum_size().x <= 730.0).is_true()
