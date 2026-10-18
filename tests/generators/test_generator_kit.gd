# Mirrors scripts/generators/generator_kit.gd: an eased upper limit shrinks with difficulty and never
# leaves the authored range, even for a range too narrow for its floor.
class_name GeneratorKitTest
extends GdUnitTestSuite


func test_eased_max_shrinks_by_difficulty_and_keeps_its_floor() -> void:
	assert_int(GeneratorKit.eased_max(1, 100, 0)).is_equal(100)
	assert_int(GeneratorKit.eased_max(1, 100, -1)).is_equal(70)
	assert_int(GeneratorKit.eased_max(1, 100, -2)).is_equal(49)
	assert_int(GeneratorKit.eased_max(10, 12, -3)).is_equal(12) # never closer than the span to `low`


func test_eased_max_never_exceeds_the_authored_limit() -> void:
	# A range narrower than the span used to return the floor, above `high` (piles of 4 for a max of 3).
	assert_int(GeneratorKit.eased_max(1, 3, -1, 3)).is_equal(3)
	assert_int(GeneratorKit.eased_max(2, 2, -1, 1)).is_equal(2)
	for high: int in range(1, 30):
		for difficulty: int in range(-4, 1):
			assert_int(GeneratorKit.eased_max(1, high, difficulty)).is_between(1, high)
