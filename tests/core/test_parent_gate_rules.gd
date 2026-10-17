# Mirrors scripts/core/parent_gate_rules.gd (P1-S09-03).
class_name ParentGateRulesTest
extends GdUnitTestSuite


func _gate(seed_value: int = 1) -> ParentGateRules:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return ParentGateRules.new(rng)


func test_the_question_is_two_digits_times_one_digit() -> void:
	for seed_value: int in range(1, 200):
		var gate: ParentGateRules = _gate(seed_value)
		assert_int(gate.a).is_between(12, 99)
		assert_int(gate.b).is_between(3, 9)
		assert_int(gate.answer()).is_equal(gate.a * gate.b)


func test_the_right_answer_opens_the_gate() -> void:
	var gate: ParentGateRules = _gate()
	assert_int(gate.submit(gate.answer(), 0)).is_equal(ParentGateRules.Result.PASSED)


func test_a_miss_brings_a_new_question_and_three_misses_lock_it_for_30_seconds() -> void:
	var gate: ParentGateRules = _gate(3)
	var first: int = gate.answer()
	assert_int(gate.submit(first + 1, 0)).is_equal(ParentGateRules.Result.MISSED)
	assert_int(gate.submit(gate.answer() + 1, 1000)).is_equal(ParentGateRules.Result.MISSED)
	assert_int(gate.submit(gate.answer() + 1, 2000)).is_equal(ParentGateRules.Result.LOCKED)
	assert_bool(gate.is_locked(2000 + ParentGateRules.COOLDOWN_MS - 1)).is_true()
	assert_int(gate.submit(gate.answer(), 10000)).is_equal(ParentGateRules.Result.LOCKED) # even the right answer waits
	assert_bool(gate.is_locked(2000 + ParentGateRules.COOLDOWN_MS)).is_false()
	assert_int(gate.submit(gate.answer(), 2000 + ParentGateRules.COOLDOWN_MS)).is_equal(ParentGateRules.Result.PASSED)


func test_random_taps_never_get_through_in_twenty_tries() -> void:
	# A child tapping the number pad: one to three random digits, then Go, as fast as they like.
	for seed_value: int in range(1, 51):
		var taps: RandomNumberGenerator = RandomNumberGenerator.new()
		taps.seed = seed_value * 7919
		var gate: ParentGateRules = _gate(seed_value)
		var now: int = 0
		for attempt: int in 20:
			var digits: int = taps.randi_range(1, 3)
			var typed: int = taps.randi_range(0, int(pow(10, digits)) - 1)
			assert_int(gate.submit(typed, now)).override_failure_message("seed %d try %d got through" % [seed_value, attempt]).is_not_equal(ParentGateRules.Result.PASSED)
			now += 1500
