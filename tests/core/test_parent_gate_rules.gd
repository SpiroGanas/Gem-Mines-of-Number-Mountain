# Mirrors scripts/core/parent_gate_rules.gd (P1-S09-03; the Sprint 23 parental gate review).
class_name ParentGateRulesTest
extends GdUnitTestSuite


func _gate(seed_value: int = 1) -> ParentGateRules:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return ParentGateRules.new(rng)


## Answers the current question right.
func _right(gate: ParentGateRules, now: int) -> ParentGateRules.Result:
	return gate.submit(gate.answer(), now)


func test_the_question_is_two_digits_times_one_digit_with_a_three_digit_answer() -> void:
	for seed_value: int in range(1, 200):
		var gate: ParentGateRules = _gate(seed_value)
		assert_int(gate.a).is_between(12, 99)
		assert_int(gate.b).is_between(3, 9)
		assert_int(gate.answer()).is_equal(gate.a * gate.b)
		assert_int(gate.answer()).is_between(ParentGateRules.MIN_ANSWER, 999)


func test_two_right_answers_in_a_row_open_the_gate() -> void:
	var gate: ParentGateRules = _gate()
	assert_int(gate.question_number()).is_equal(1)
	assert_int(_right(gate, 0)).is_equal(ParentGateRules.Result.NEXT)
	assert_int(gate.question_number()).is_equal(2)
	assert_int(_right(gate, 0)).is_equal(ParentGateRules.Result.PASSED)
	assert_int(gate.question_number()).is_equal(1) # the next visit starts over


func test_a_miss_after_one_right_answer_starts_over() -> void:
	var gate: ParentGateRules = _gate(5)
	_right(gate, 0)
	assert_int(gate.submit(gate.answer() + 1, 0)).is_equal(ParentGateRules.Result.MISSED)
	assert_int(gate.question_number()).is_equal(1)
	assert_int(_right(gate, 0)).is_equal(ParentGateRules.Result.NEXT) # one right is not enough again


func test_each_answer_brings_a_new_question() -> void:
	var gate: ParentGateRules = _gate(9)
	var asked: Array[String] = []
	for i: int in 6:
		asked.append("%dx%d" % [gate.a, gate.b])
		gate.submit(gate.answer() if i % 2 == 0 else -1, i * 100000)
	assert_int(asked.size()).is_equal(6)
	var distinct: Dictionary = {}
	for question: String in asked:
		distinct[question] = true
	assert_int(distinct.size()).is_greater(3) # random each time: nothing to memorise


func test_a_miss_brings_a_new_question_and_three_misses_lock_it_for_30_seconds() -> void:
	var gate: ParentGateRules = _gate(3)
	var first: int = gate.answer()
	assert_int(gate.submit(first + 1, 0)).is_equal(ParentGateRules.Result.MISSED)
	assert_int(gate.submit(gate.answer() + 1, 1000)).is_equal(ParentGateRules.Result.MISSED)
	assert_int(gate.submit(gate.answer() + 1, 2000)).is_equal(ParentGateRules.Result.LOCKED)
	assert_bool(gate.is_locked(2000 + ParentGateRules.COOLDOWN_MS - 1)).is_true()
	assert_int(_right(gate, 10000)).is_equal(ParentGateRules.Result.LOCKED) # even the right answer waits
	assert_bool(gate.is_locked(2000 + ParentGateRules.COOLDOWN_MS)).is_false()
	assert_int(_right(gate, 2000 + ParentGateRules.COOLDOWN_MS)).is_equal(ParentGateRules.Result.NEXT)
	assert_int(_right(gate, 2000 + ParentGateRules.COOLDOWN_MS)).is_equal(ParentGateRules.Result.PASSED)


func test_each_lock_lasts_twice_as_long_up_to_five_minutes_and_opening_resets_it() -> void:
	var gate: ParentGateRules = _gate(4)
	var now: int = 0
	var lengths: Array[int] = []
	for lock: int in 6:
		for miss: int in ParentGateRules.MAX_MISSES:
			gate.submit(-1, now)
		lengths.append(gate.locked_until_ms - now)
		now = gate.locked_until_ms
	assert_array(lengths).contains_exactly([30000, 60000, 120000, 240000, 300000, 300000])
	_right(gate, now)
	_right(gate, now)
	assert_int(gate.locks).is_equal(0)
	for miss: int in ParentGateRules.MAX_MISSES:
		gate.submit(-1, now)
	assert_int(gate.locked_until_ms - now).is_equal(ParentGateRules.COOLDOWN_MS)


## Plan section 3.7: 1,000 random tap sequences never open the gate. Each sequence is a child mashing
## the NumberPad of a fresh gate (the worst case: no lock left over from earlier sequences) for 40
## taps, one every 0.4 seconds: random digit keys, the erase key and Go, typed into a three-digit pad
## exactly as NumberPad does it.
func test_a_thousand_random_tap_sequences_never_open_the_gate() -> void:
	var taps: RandomNumberGenerator = RandomNumberGenerator.new()
	taps.seed = 20270419
	var opened: int = 0
	var submits: int = 0
	for sequence: int in 1000:
		var gate: ParentGateRules = _gate(sequence + 1)
		var typed: String = ""
		var now: int = 0
		for tap: int in 40:
			var key: int = taps.randi_range(0, 11) # 0-9 digits, 10 erase, 11 Go
			if key <= 9 and typed.length() < 3:
				typed += str(key)
			elif key == 10:
				typed = typed.left(-1)
			elif key == 11 and typed != "":
				submits += 1
				if gate.submit(int(typed), now) == ParentGateRules.Result.PASSED:
					opened += 1
				typed = ""
			now += 400
	assert_int(submits).is_greater(1000) # the sequences really did press Go
	assert_int(opened).is_equal(0)
