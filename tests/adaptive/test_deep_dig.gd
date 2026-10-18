# The weekly Deep Dig (Sprint 19): ten review problems over the mastered skills, deterministic for a
# seed and a mastered set, once per ISO week, and never twice by turning the clock back.
class_name DeepDigTest
extends GdUnitTestSuite

const MASTERED: Array[StringName] = [&"add.to_10.sums", &"sub.to_10.diff", &"count.to_120.next", &"pv.tens_ones.read"]


func test_the_same_seed_and_mastered_set_give_the_same_dig() -> void:
	var first: Array[StringName] = MotivationRules.deep_dig_skills(MASTERED, 77)
	assert_int(first.size()).is_equal(MotivationRules.DEEP_DIG_PROBLEMS)
	assert_array(MotivationRules.deep_dig_skills(MASTERED, 77)).is_equal(first)
	assert_array(MotivationRules.deep_dig_skills(MASTERED, 78)).is_not_equal(first)


func test_every_mastered_skill_comes_before_any_repeats() -> void:
	var picks: Array[StringName] = MotivationRules.deep_dig_skills(MASTERED, 3)
	var first_round: Array[StringName] = picks.slice(0, MASTERED.size())
	for skill: StringName in MASTERED:
		assert_bool(first_round.has(skill)).is_true()
	for skill: StringName in picks:
		assert_bool(MASTERED.has(skill)).is_true()


func test_iso_weeks_follow_the_standard() -> void:
	assert_str(MotivationRules.iso_week_key("2027-03-08")).is_equal("2027-W10") # a Monday
	assert_str(MotivationRules.iso_week_key("2027-03-14")).is_equal("2027-W10") # the Sunday after
	assert_str(MotivationRules.iso_week_key("2027-03-15")).is_equal("2027-W11")
	assert_str(MotivationRules.iso_week_key("2027-01-01")).is_equal("2026-W53") # a Friday: last week of 2026
	assert_str(MotivationRules.iso_week_key("2026-12-28")).is_equal("2026-W53")
	assert_str(MotivationRules.iso_week_key("2025-12-29")).is_equal("2026-W01")


func test_once_per_week_and_not_again_by_turning_the_clock_back() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	assert_bool(MotivationRules.deep_dig_available(save, "2027-03-22", 5)).is_true()
	assert_bool(MotivationRules.finish_deep_dig(save, "2027-03-22", 5)).is_true()
	assert_int(RewardsRules.gem_count(save["rewards"], MotivationRules.DEEP_DIG_GEM)).is_equal(1)
	assert_bool(MotivationRules.deep_dig_available(save, "2027-03-26", 5)).is_false() # same week
	assert_bool(MotivationRules.finish_deep_dig(save, "2027-03-26", 5)).is_false()
	assert_bool(MotivationRules.deep_dig_available(save, "2027-03-10", 5)).is_false() # clock set back
	assert_bool(MotivationRules.deep_dig_available(save, "2027-03-29", 5)).is_true() # next week
	assert_int(RewardsRules.gem_count(save["rewards"], MotivationRules.DEEP_DIG_GEM)).is_equal(1)


func test_missing_a_week_costs_nothing() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	MotivationRules.finish_deep_dig(save, "2027-03-01", 5)
	assert_bool(MotivationRules.deep_dig_available(save, "2027-04-19", 5)).is_true()
	assert_int(RewardsRules.gem_count(save["rewards"], MotivationRules.DEEP_DIG_GEM)).is_equal(1)


func test_it_needs_a_few_mastered_skills_first() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	assert_bool(MotivationRules.deep_dig_available(save, "2027-03-22", MotivationRules.DEEP_DIG_MIN_MASTERED - 1)).is_false()
	assert_bool(MotivationRules.deep_dig_available(save, "2027-03-22", MotivationRules.DEEP_DIG_MIN_MASTERED)).is_true()
