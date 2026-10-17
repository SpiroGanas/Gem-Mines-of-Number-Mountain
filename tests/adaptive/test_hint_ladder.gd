# Mirrors scripts/adaptive/hint_ladder.gd.
class_name HintLadderTest
extends GdUnitTestSuite


func test_each_miss_climbs_one_rung_and_the_ladder_stops_at_the_top() -> void:
	assert_int(HintLadder.next_rung(1)).is_equal(HintLadder.Rung.REPEAT_HIGHLIGHT)
	assert_int(HintLadder.next_rung(2)).is_equal(HintLadder.Rung.VISUAL_MODEL)
	assert_int(HintLadder.next_rung(3)).is_equal(HintLadder.Rung.WORKED_EXAMPLE)
	assert_int(HintLadder.next_rung(4)).is_equal(HintLadder.Rung.EASIER_PROBLEM)
	assert_int(HintLadder.next_rung(12)).is_equal(HintLadder.Rung.EASIER_PROBLEM)


func test_every_rung_has_bolts_line_from_the_text_table() -> void:
	for rung: int in HintLadder.Rung.values():
		assert_bool(Text.has_line(HintLadder.line_for(rung))).is_true()
	assert_str(Text.get_line(HintLadder.line_for(HintLadder.Rung.VISUAL_MODEL))).is_equal("A picture can help. Let's use it.")


func test_later_rungs_keep_the_help_of_earlier_ones() -> void:
	assert_bool(HintLadder.shows_model(HintLadder.Rung.REPEAT_HIGHLIGHT)).is_false()
	assert_bool(HintLadder.shows_model(HintLadder.Rung.VISUAL_MODEL)).is_true()
	assert_bool(HintLadder.shows_model(HintLadder.Rung.EASIER_PROBLEM)).is_true()
	assert_bool(HintLadder.shows_example(HintLadder.Rung.VISUAL_MODEL)).is_false()
	assert_bool(HintLadder.shows_example(HintLadder.Rung.WORKED_EXAMPLE)).is_true()


func test_the_easier_problem_is_given_once_per_rock() -> void:
	assert_bool(HintLadder.swaps_problem(HintLadder.Rung.EASIER_PROBLEM, false)).is_true()
	assert_bool(HintLadder.swaps_problem(HintLadder.Rung.EASIER_PROBLEM, true)).is_false()
	assert_bool(HintLadder.swaps_problem(HintLadder.Rung.WORKED_EXAMPLE, false)).is_false()
