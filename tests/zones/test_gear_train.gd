# Mirrors scripts/zones/gear_train.gd (P4-S30-01): turns until the marks line up, gear ratios, and the
# alternating direction along a train. Expected values are worked out by hand (and by counting teeth).
class_name GearTrainTest
extends GdUnitTestSuite


func test_turns_to_align_from_the_plan() -> void:
	assert_int(GearTrain.turns_to_align([8, 12])).is_equal(3)
	assert_int(GearTrain.turns_to_align([6, 8, 12])).is_equal(4)
	assert_int(GearTrain.turns_to_align([10])).is_equal(1)


func test_turns_to_align_by_counting_teeth() -> void:
	for a: int in range(4, 25):
		for b: int in range(4, 25):
			var passed: int = 1
			while passed % a != 0 or passed % b != 0:
				passed += 1
			assert_int(GearTrain.turns_to_align([a, b]) * a).is_equal(passed)


func test_a_gear_that_divides_the_first_lines_up_after_one_turn() -> void:
	assert_int(GearTrain.turns_to_align([24, 8])).is_equal(1)
	assert_int(GearTrain.turns_to_align([12, 12])).is_equal(1)


func test_the_ratio_is_exact() -> void:
	assert_dict(GearTrain.ratio([24, 8], 1)).is_equal({"num": 3, "den": 1})
	assert_dict(GearTrain.ratio([24, 16], 1)).is_equal({"num": 3, "den": 2})
	assert_dict(GearTrain.ratio([8, 12, 16], 2)).is_equal({"num": 1, "den": 2})
	assert_dict(GearTrain.ratio([8, 12], 0)).is_equal({"num": 1, "den": 1})


func test_direction_alternates_along_the_train() -> void:
	assert_int(GearTrain.direction_of(0)).is_equal(1)
	assert_int(GearTrain.direction_of(1)).is_equal(-1)
	assert_int(GearTrain.direction_of(2)).is_equal(1)
	assert_int(GearTrain.direction_of(3)).is_equal(-1)


func test_angles_follow_the_teeth_and_turn_opposite_ways() -> void:
	var train: GearTrain = GearTrain.new([24, 8, 12])
	assert_float(train.angle_of(0, 1.0)).is_equal_approx(TAU, 0.0001)
	assert_float(train.angle_of(1, 1.0)).is_equal_approx(-3.0 * TAU, 0.0001)
	assert_float(train.angle_of(2, 0.5)).is_equal_approx(TAU, 0.0001)
	assert_float(train.turns_per_driver_turn(1)).is_equal_approx(3.0, 0.0001)
	train.set_teeth([10, 4])
	assert_int(train.size()).is_equal(2)
	assert_float(train.turns_per_driver_turn(1)).is_equal_approx(2.5, 0.0001)


func test_marked_teeth_meet_again_after_turns_to_align() -> void:
	var train: GearTrain = GearTrain.new([8, 12])
	var turns: int = GearTrain.turns_to_align(train.teeth)
	for index: int in train.size():
		var whole_turns: float = absf(train.angle_of(index, turns)) / TAU
		assert_float(whole_turns - roundf(whole_turns)).is_equal_approx(0.0, 0.0001)


func test_the_first_shared_drop_of_two_conveyors() -> void:
	assert_int(GearTrain.first_shared_drop(4, 6)).is_equal(12)
	assert_int(GearTrain.first_shared_drop(3, 5)).is_equal(15)
	assert_int(GearTrain.first_shared_drop(4, 8)).is_equal(8)
