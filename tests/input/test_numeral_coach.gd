# Mirrors scripts/input/numeral_coach.gd and scripts/input/digit_paths.gd.
class_name NumeralCoachTest
extends GdUnitTestSuite


func test_the_third_backwards_writing_of_a_digit_brings_the_demo_once() -> void:
	var coach: NumeralCoach = NumeralCoach.new()
	assert_bool(coach.note(3, true, true)).is_false()
	assert_bool(coach.note(3, true, true)).is_false()
	assert_bool(coach.note(3, true, true)).is_true()
	assert_bool(coach.note(3, true, true)).is_false() # never twice in a session
	assert_int(coach.mirrored_count(3)).is_equal(4)


func test_each_digit_counts_on_its_own() -> void:
	var coach: NumeralCoach = NumeralCoach.new()
	for i: int in 2:
		coach.note(3, true, true)
		coach.note(5, true, true)
	assert_bool(coach.note(5, true, true)).is_true()
	assert_bool(coach.note(3, true, true)).is_true()


func test_forwards_digits_and_a_switched_off_setting_never_count() -> void:
	var coach: NumeralCoach = NumeralCoach.new()
	for i: int in 5:
		assert_bool(coach.note(2, false, true)).is_false()
		assert_bool(coach.note(2, true, false)).is_false()
	assert_int(coach.mirrored_count(2)).is_equal(0)


func test_a_new_session_starts_counting_again_and_shows_the_demo_again() -> void:
	var coach: NumeralCoach = NumeralCoach.new()
	for i: int in 3:
		coach.note(7, true, true)
	coach.reset()
	assert_int(coach.mirrored_count(7)).is_equal(0)
	assert_bool(coach.note(7, true, true)).is_false()
	assert_bool(coach.note(7, true, true)).is_false()
	assert_bool(coach.note(7, true, true)).is_true()


func test_every_digit_has_strokes_inside_the_unit_box() -> void:
	for digit: int in 10:
		var strokes: Array[PackedVector2Array] = DigitPaths.strokes_for(digit)
		assert_int(strokes.size()).is_between(1, 2)
		for stroke: PackedVector2Array in strokes:
			assert_int(stroke.size()).is_greater(8)
			for point: Vector2 in stroke:
				assert_float(point.x).is_between(-0.05, 1.05)
				assert_float(point.y).is_between(-0.05, 1.05)
