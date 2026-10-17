# Mirrors scripts/core/dig_flow.gd.
class_name DigFlowTest
extends GdUnitTestSuite

var _flow: DigFlow


func before_test() -> void:
	_flow = DigFlow.new()


## Plays one rock through to the gem landing: pick, show, answer correctly, crack, drop.
func _solve(index: int) -> void:
	assert_bool(_flow.pick_rock(index)).is_true()
	_flow.problem_shown()
	_flow.submit_answer(true)
	_flow.crack_finished()
	_flow.gem_dropped()


func test_a_new_flow_is_idle_until_a_wall_starts() -> void:
	assert_int(_flow.state).is_equal(DigFlow.State.IDLE)
	assert_bool(_flow.pick_rock(0)).is_false()


func test_start_wall_goes_to_pick_rock_with_every_rock_uncracked() -> void:
	_flow.start_wall(6)
	assert_int(_flow.state).is_equal(DigFlow.State.PICK_ROCK)
	assert_int(_flow.rock_count()).is_equal(6)
	assert_int(_flow.rocks_left()).is_equal(6)
	assert_int(_flow.current_rock()).is_equal(-1)


func test_the_correct_path_walks_the_planned_states_in_order() -> void:
	var seen: Array[int] = []
	_flow.state_changed.connect(func(state: int, _previous: int) -> void: seen.append(state))
	_flow.start_wall(2)
	_flow.pick_rock(1)
	_flow.problem_shown()
	_flow.submit_answer(true)
	_flow.crack_finished()
	_flow.gem_dropped()
	assert_array(seen).contains_exactly([
		DigFlow.State.PICK_ROCK, DigFlow.State.SHOW_PROBLEM, DigFlow.State.AWAIT_ANSWER,
		DigFlow.State.CRACK, DigFlow.State.GEM_DROP, DigFlow.State.PICK_ROCK,
	])
	assert_bool(_flow.is_cracked(1)).is_true()
	assert_bool(_flow.is_cracked(0)).is_false()


func test_a_not_quite_answer_wobbles_shows_a_hint_then_asks_again() -> void:
	_flow.start_wall(3)
	_flow.pick_rock(0)
	_flow.problem_shown()
	_flow.submit_answer(false)
	assert_int(_flow.state).is_equal(DigFlow.State.WOBBLE)
	_flow.wobble_finished()
	assert_int(_flow.state).is_equal(DigFlow.State.HINT)
	_flow.hint_shown()
	assert_int(_flow.state).is_equal(DigFlow.State.AWAIT_ANSWER)
	assert_bool(_flow.is_cracked(0)).is_false()


func test_wrong_answers_never_cost_anything() -> void:
	_flow.start_wall(3)
	_solve(0) # earn something first
	var coins_before: int = _flow.coins
	var gems_before: int = _flow.gems
	_flow.pick_rock(1)
	_flow.problem_shown()
	for attempt: int in 12: # far more misses than there are hint rungs
		_flow.submit_answer(false)
		_flow.wobble_finished()
		_flow.hint_shown()
	assert_int(_flow.coins).is_equal(coins_before)
	assert_int(_flow.gems).is_equal(gems_before)
	assert_int(_flow.rocks_left()).is_equal(2) # nothing was lost or re-locked
	assert_bool(_flow.state == DigFlow.State.AWAIT_ANSWER).is_true() # no game over
	assert_int(_flow.state).is_not_equal(DigFlow.State.IDLE)


func test_first_try_pays_two_coins_and_a_miss_pays_one() -> void:
	_flow.start_wall(2)
	_solve(0)
	assert_int(_flow.coins).is_equal(DigFlow.COINS_FIRST_TRY)
	_flow.pick_rock(1)
	_flow.problem_shown()
	_flow.submit_answer(false)
	_flow.wobble_finished()
	_flow.hint_shown()
	_flow.submit_answer(true)
	_flow.crack_finished()
	assert_int(_flow.coins).is_equal(DigFlow.COINS_FIRST_TRY + DigFlow.COINS_AFTER_HINT)
	assert_int(_flow.gems).is_equal(2)


func test_payout_is_the_same_every_time_with_no_randomness() -> void:
	var results: Array[int] = []
	for run: int in 5:
		var flow: DigFlow = DigFlow.new()
		flow.start_wall(4)
		for index: int in 4:
			flow.pick_rock(index)
			flow.problem_shown()
			flow.submit_answer(true)
			flow.crack_finished()
			flow.gem_dropped()
		results.append(flow.coins * 100 + flow.gems)
	var expected: int = DigFlow.COINS_FIRST_TRY * 4 * 100 + DigFlow.GEMS_PER_ROCK * 4
	assert_array(results).contains_exactly([expected, expected, expected, expected, expected])


func test_hint_rung_climbs_with_misses_and_stops_at_four() -> void:
	_flow.start_wall(1)
	_flow.pick_rock(0)
	_flow.problem_shown()
	assert_int(_flow.hint_rung()).is_equal(0)
	for expected: int in [1, 2, 3, 4, 4, 4]:
		_flow.submit_answer(false)
		_flow.wobble_finished()
		_flow.hint_shown()
		assert_int(_flow.hint_rung()).is_equal(expected)


func test_the_miss_count_resets_for_each_new_rock() -> void:
	_flow.start_wall(2)
	_flow.pick_rock(0)
	_flow.problem_shown()
	_flow.submit_answer(false)
	_flow.wobble_finished()
	_flow.hint_shown()
	assert_int(_flow.wrong_count()).is_equal(1)
	_flow.submit_answer(true)
	_flow.crack_finished()
	_flow.gem_dropped()
	_flow.pick_rock(1)
	assert_int(_flow.wrong_count()).is_equal(0)


func test_cracking_the_last_rock_clears_the_wall() -> void:
	_flow.start_wall(2)
	_solve(0)
	assert_int(_flow.state).is_equal(DigFlow.State.PICK_ROCK)
	_solve(1)
	assert_int(_flow.state).is_equal(DigFlow.State.WALL_CLEAR)
	assert_int(_flow.rocks_left()).is_equal(0)


func test_rocks_can_be_cracked_in_any_order() -> void:
	_flow.start_wall(3)
	for index: int in [2, 0, 1]:
		_solve(index)
	assert_int(_flow.state).is_equal(DigFlow.State.WALL_CLEAR)


func test_a_cracked_or_invalid_rock_cannot_be_picked() -> void:
	_flow.start_wall(3)
	_solve(1)
	assert_bool(_flow.pick_rock(1)).is_false() # already cracked
	assert_bool(_flow.pick_rock(-1)).is_false()
	assert_bool(_flow.pick_rock(3)).is_false()
	assert_int(_flow.state).is_equal(DigFlow.State.PICK_ROCK)


func test_actions_out_of_order_are_ignored_not_fatal() -> void:
	_flow.start_wall(2)
	# Nothing is picked yet: every later step is refused and changes nothing.
	assert_bool(_flow.problem_shown()).is_false()
	assert_bool(_flow.submit_answer(true)).is_false()
	assert_bool(_flow.crack_finished()).is_false()
	assert_bool(_flow.gem_dropped()).is_false()
	assert_bool(_flow.wobble_finished()).is_false()
	assert_bool(_flow.hint_shown()).is_false()
	assert_int(_flow.state).is_equal(DigFlow.State.PICK_ROCK)
	assert_int(_flow.coins).is_equal(0)
	# A second pick while one rock is open is refused.
	_flow.pick_rock(0)
	assert_bool(_flow.pick_rock(1)).is_false()
	assert_int(_flow.current_rock()).is_equal(0)


func test_answers_are_only_accepted_while_awaiting() -> void:
	_flow.start_wall(1)
	_flow.pick_rock(0)
	assert_bool(_flow.submit_answer(true)).is_false() # problem not shown yet
	_flow.problem_shown()
	assert_bool(_flow.submit_answer(true)).is_true()
	assert_bool(_flow.submit_answer(true)).is_false() # a double tap cannot pay twice
	_flow.crack_finished()
	assert_bool(_flow.crack_finished()).is_false()
	assert_int(_flow.coins).is_equal(DigFlow.COINS_FIRST_TRY)
	assert_int(_flow.gems).is_equal(1)


func test_a_new_wall_keeps_the_tally_until_reset() -> void:
	_flow.start_wall(1)
	_solve(0)
	_flow.start_wall(2)
	assert_int(_flow.coins).is_equal(DigFlow.COINS_FIRST_TRY)
	assert_int(_flow.rocks_left()).is_equal(2)
	_flow.reset_tally()
	assert_int(_flow.coins).is_equal(0)
	assert_int(_flow.gems).is_equal(0)
