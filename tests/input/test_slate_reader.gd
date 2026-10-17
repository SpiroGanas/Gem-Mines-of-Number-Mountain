# Mirrors scripts/input/slate_reader.gd: what a row of digit-box readings means.
class_name SlateReaderTest
extends GdUnitTestSuite

const SURE: float = 0.97
const UNSURE: float = 0.4
const THRESHOLD: float = 0.85


func _read(digit: int, confidence: float = SURE) -> Dictionary:
	return {"digit": digit, "confidence": confidence}


func _interpret(readings: Array[Dictionary]) -> Dictionary:
	return SlateReader.interpret(readings, THRESHOLD)


func test_no_ink_anywhere_is_empty() -> void:
	assert_int(_interpret([{}, {}])["status"]).is_equal(SlateReader.Status.EMPTY)


func test_confident_digits_make_the_number_left_to_right() -> void:
	var result: Dictionary = _interpret([_read(4), _read(7)])
	assert_int(result["status"]).is_equal(SlateReader.Status.SURE)
	assert_int(result["value"]).is_equal(47)
	assert_array(result["digits"]).is_equal([4, 7])


func test_boxes_left_of_the_first_ink_are_leading_zeros_not_part_of_the_number() -> void:
	var result: Dictionary = _interpret([{}, {}, _read(7)])
	assert_int(result["status"]).is_equal(SlateReader.Status.SURE)
	assert_int(result["value"]).is_equal(7)


func test_a_blank_box_after_the_first_digit_is_not_finished() -> void:
	var result: Dictionary = _interpret([_read(4), {}, _read(2)])
	assert_int(result["status"]).is_equal(SlateReader.Status.INCOMPLETE)
	assert_array(result["boxes"]).is_equal([1])
	assert_int(_interpret([_read(4), {}])["status"]).is_equal(SlateReader.Status.INCOMPLETE)


func test_marks_that_are_not_a_digit_are_unreadable() -> void:
	var result: Dictionary = _interpret([_read(4), {"digit": -1, "confidence": 0.0}])
	assert_int(result["status"]).is_equal(SlateReader.Status.UNREADABLE)
	assert_array(result["boxes"]).is_equal([1])


func test_an_unsure_digit_asks_and_lists_which_boxes() -> void:
	var result: Dictionary = _interpret([_read(4, UNSURE), _read(7), _read(1, UNSURE)])
	assert_int(result["status"]).is_equal(SlateReader.Status.UNSURE)
	assert_int(result["value"]).is_equal(471)
	assert_array(result["boxes"]).is_equal([0, 2])


func test_the_threshold_itself_counts_as_sure() -> void:
	assert_int(_interpret([_read(5, THRESHOLD)])["status"]).is_equal(SlateReader.Status.SURE)
	assert_int(_interpret([_read(5, THRESHOLD - 0.001)])["status"]).is_equal(SlateReader.Status.UNSURE)


func test_unreadable_wins_over_unsure_and_incomplete_wins_over_both() -> void:
	assert_int(_interpret([_read(1, UNSURE), {"digit": -1}])["status"]).is_equal(SlateReader.Status.UNREADABLE)
	assert_int(_interpret([_read(1, UNSURE), {}, {"digit": -1}])["status"]).is_equal(SlateReader.Status.INCOMPLETE)


func test_a_leading_zero_written_by_the_child_is_a_zero() -> void:
	var result: Dictionary = _interpret([_read(0), _read(7)])
	assert_int(result["value"]).is_equal(7)
	assert_array(result["digits"]).is_equal([0, 7])
