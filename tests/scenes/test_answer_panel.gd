# Mirrors scenes/mine/answer_panel.gd. Every MVP problem (Zones 1-3) must render and be answerable
# through the widget it gets, and the problem must judge the widget's output correctly.
class_name AnswerPanelTest
extends GdUnitTestSuite

const MVP_ZONES: Array[int] = [1, 2, 3]

var _catalog: SkillCatalog
var _panel: AnswerPanel


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_panel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	_panel.size = Vector2(1000, 700)
	add_child(_panel)
	auto_free(_panel)


func after_test() -> void:
	TestWindow.restore(get_window())


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _problem(skill_id: StringName, seed_value: int, representation: StringName = &"") -> Problem:
	var overrides: Dictionary = {}
	if representation != &"":
		overrides["representation"] = representation
	return GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed_value, overrides)


func _mvp_skills() -> Array[Skill]:
	var skills: Array[Skill] = []
	for zone: int in MVP_ZONES:
		skills.append_array(_catalog.skills_in_zone(zone))
	return skills


func _give(problem: Problem, target: Variant) -> void:
	assert_bool(PanelDriver.give(_panel, target)).override_failure_message("%s: could not give %s through the widget" % [problem.skill_id, target]).is_true()


# --- Choosing the input (pure) --------------------------------------------------------------


func test_each_zone_1_skill_gets_the_input_the_plan_describes() -> void:
	var expected: Dictionary = {
		&"count.to_20.objects": AnswerPanel.InputKind.CHOICES,
		&"count.to_120.read": AnswerPanel.InputKind.CHOICES,
		&"count.to_120.next": AnswerPanel.InputKind.CHOICES,
		&"count.to_120.between": AnswerPanel.InputKind.CHOICES,
		&"count.to_120.fill_strip": AnswerPanel.InputKind.TILES,
		&"count.write.numeral": AnswerPanel.InputKind.NUMBER_PAD,
		&"cmp.to_20.more_less": AnswerPanel.InputKind.TAP_PILE,
		&"cmp.to_100.symbols": AnswerPanel.InputKind.CHOICES,
		&"cmp.to_100.order3": AnswerPanel.InputKind.TILES,
		&"pv.tens_ones.build": AnswerPanel.InputKind.BOARD,
		&"pv.tens_ones.read": AnswerPanel.InputKind.CHOICES,
		&"pv.tens_ones.expanded": AnswerPanel.InputKind.CHOICES,
		&"pv.tens_ones.digit_value": AnswerPanel.InputKind.CHOICES,
		&"pv.regroup.trade_ten": AnswerPanel.InputKind.BOARD,
		&"pv.regroup.untrade": AnswerPanel.InputKind.BOARD,
		&"pv.tens.ten_more_less": AnswerPanel.InputKind.CHOICES,
		&"pv.hundred.intro": AnswerPanel.InputKind.BOARD,
	}
	assert_int(expected.size()).is_equal(17)
	for skill_id: StringName in expected:
		assert_int(AnswerPanel.choose_input(_problem(skill_id, 3))).override_failure_message(skill_id).is_equal(expected[skill_id])


func test_each_zone_2_and_3_skill_gets_the_input_the_plan_describes() -> void:
	var by_input: Dictionary = {
		AnswerPanel.InputKind.TILES: [&"eq.fact_family.build", &"skip.by_10.to_120", &"skip.by_5.to_100", &"skip.by_2.to_40"],
		AnswerPanel.InputKind.ARRAY: [&"arr.rows_cols.build"],
		AnswerPanel.InputKind.CHOICES: [&"eq.balance.true_false", &"eq.inverse.check", &"parity.even_odd.pairs", &"parity.even_odd.rule", &"mult.commutative.match"],
	}
	var counted: int = 0
	for skill: Skill in _catalog.skills_in_zone(2) + _catalog.skills_in_zone(3):
		var expected: AnswerPanel.InputKind = AnswerPanel.InputKind.NUMBER_PAD # whole-number answers
		for kind: AnswerPanel.InputKind in by_input:
			if by_input[kind].has(skill.id):
				expected = kind
		for representation: StringName in skill.representations:
			assert_int(AnswerPanel.choose_input(_problem(skill.id, 3, representation))).override_failure_message("%s (%s)" % [skill.id, representation]).is_equal(expected)
		counted += 1
	assert_int(counted).is_equal(28)


func test_word_answers_get_word_labels() -> void:
	for skill_id: StringName in [&"parity.even_odd.pairs", &"eq.balance.true_false"]:
		var problem: Problem = _problem(skill_id, 2)
		_panel.setup(problem, _rng())
		for index: int in _panel.choices().button_count():
			var button_text: String = _panel.choices().button(index).text
			assert_bool(button_text.is_valid_int()).override_failure_message("%s shows %s" % [skill_id, button_text]).is_false()
			assert_bool(button_text.begins_with("[")).is_false() # never a missing line


func test_counting_by_twos_shows_the_strip_around_the_slots() -> void:
	var problem: Problem = _problem(&"skip.by_2.to_40", 7)
	var sequence: Array = AnswerPanel.strip_sequence(problem)
	assert_int(sequence.size()).is_equal(problem.meta["strip"].size())
	assert_int(sequence.count(null)).is_equal(problem.answer.size())
	for index: int in sequence.size():
		if sequence[index] == null:
			assert_bool(problem.answer.has(problem.meta["strip"][index])).is_true()


func test_labels_show_numerals_symbols_sums_and_lists() -> void:
	var plain: Problem = Problem.new()
	assert_str(AnswerPanel.label_for(34, plain)).is_equal("34")
	assert_str(AnswerPanel.label_for(&"<", plain)).is_equal("<")
	assert_str(AnswerPanel.label_for([62, 64], plain)).is_equal("62, 64")
	var sums: Problem = Problem.new()
	sums.meta = {"array_label": "sum"}
	assert_str(AnswerPanel.label_for([30, 4], sums)).is_equal("30 + 4")


# --- Every problem renders and can be answered right and wrong -----------------------------


func test_every_mvp_problem_can_be_answered_correctly_through_its_widget() -> void:
	for skill: Skill in _mvp_skills():
		for representation: StringName in skill.representations:
			for seed_value: int in range(1, 31):
				var problem: Problem = _problem(skill.id, seed_value, representation)
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given), CONNECT_ONE_SHOT)
				_give(problem, problem.answer)
				assert_int(heard.size()).override_failure_message("%s seed %d: no answer came out" % [skill.id, seed_value]).is_equal(1)
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: gave %s, expected %s" % [skill.id, seed_value, heard[0], problem.answer]).is_true()


func test_every_mvp_problem_judges_a_named_wrong_answer_as_wrong() -> void:
	for skill: Skill in _mvp_skills():
		for seed_value: int in range(1, 31):
			var problem: Problem = _problem(skill.id, seed_value)
			if problem.distractors.is_empty():
				continue
			var wrong: Variant = problem.distractors[0]["value"]
			var heard: Array = []
			_panel.setup(problem, _rng(seed_value))
			_panel.set_enabled(true)
			_panel.answered.connect(func(given: Variant) -> void: heard.append(given), CONNECT_ONE_SHOT)
			_give(problem, wrong)
			assert_int(heard.size()).override_failure_message("%s seed %d: no answer came out" % [skill.id, seed_value]).is_equal(1)
			assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: %s was accepted but is a named mistake" % [skill.id, seed_value, heard[0]]).is_false()


# --- The widgets themselves ----------------------------------------------------------------


func test_choices_offer_the_answer_and_up_to_three_wrong_answers() -> void:
	var problem: Problem = _problem(&"pv.tens.ten_more_less", 9)
	_panel.setup(problem, _rng())
	assert_int(_panel.input_kind).is_equal(AnswerPanel.InputKind.CHOICES)
	var offered: Array = _panel.choices().values_in_order()
	assert_bool(offered.has(problem.answer)).is_true()
	assert_int(offered.size()).is_between(2, 4)


func test_the_same_seed_shuffles_the_buttons_the_same_way() -> void:
	var problem: Problem = _problem(&"count.to_20.objects", 5)
	_panel.setup(problem, _rng(77))
	var first: Array = _panel.choices().values_in_order()
	_panel.setup(problem, _rng(77))
	assert_array(_panel.choices().values_in_order()).is_equal(first)


func test_a_disabled_panel_ignores_answers() -> void:
	var problem: Problem = _problem(&"count.to_20.objects", 5)
	_panel.setup(problem, _rng())
	_panel.set_enabled(false)
	var heard: Array = []
	_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
	_panel.choices().button(0).pressed.emit()
	assert_array(heard).is_empty()
	assert_bool(_panel.choices().button(0).disabled).is_true()
	_panel.set_enabled(true)
	assert_bool(_panel.choices().button(0).disabled).is_false()


func test_tapping_a_pile_answers_with_its_index_and_a_disabled_panel_locks_the_piles() -> void:
	var problem: Problem = _problem(&"cmp.to_20.more_less", 4)
	_panel.setup(problem, _rng())
	assert_int(_panel.visual_model().pile_buttons().size()).is_equal(2)
	_panel.set_enabled(false)
	assert_bool(_panel.visual_model().pile_buttons()[0].disabled).is_true()


func test_regrouping_starts_with_the_starting_pile_in_the_tray() -> void:
	var problem: Problem = _problem(&"pv.regroup.trade_ten", 6)
	_panel.setup(problem, _rng())
	await get_tree().process_frame
	var start: Dictionary = problem.meta["start"]
	assert_dict(_panel.board().answer()).is_equal({"tens": start["tens"], "ones": start["ones"]})
	assert_bool(problem.is_correct(_panel.board().answer())).is_false() # not traded yet: that is the mistake forgot_regroup


func test_hundred_problems_offer_a_hundred_pile() -> void:
	var problem: Problem = _problem(&"pv.hundred.intro", 2)
	_panel.setup(problem, _rng())
	assert_bool(_panel.board().tools.has(DragItem.HUNDRED)).is_true()
	assert_int(_panel.board().answer()["hundreds"]).is_equal(0)


func test_set_up_again_replaces_the_old_widgets() -> void:
	_panel.setup(_problem(&"count.to_20.objects", 1), _rng())
	_panel.setup(_problem(&"count.write.numeral", 1), _rng())
	await get_tree().process_frame
	assert_object(_panel.choices()).is_null()
	assert_object(_panel.number_pad()).is_not_null()
	assert_int(_panel.input_kind).is_equal(AnswerPanel.InputKind.NUMBER_PAD)


# --- Answer modes, guessing odds and hint pictures (Sprint 6) -------------------------------


func test_the_first_listed_answer_mode_wins() -> void:
	var problem: Problem = _problem(&"count.to_120.next", 2)
	problem.answer_modes = [&"number_pad", &"tap"]
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.NUMBER_PAD)
	problem.answer_modes = [&"tap", &"number_pad"]
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.CHOICES)
	problem.answer_modes = [&"drag", &"number_pad"] # no drag input for this problem: the next mode serves
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.NUMBER_PAD)


func test_the_number_pad_is_only_for_whole_number_answers() -> void:
	var problem: Problem = _problem(&"pv.tens_ones.expanded", 2) # answer [30, 4]
	problem.answer_modes = [&"number_pad", &"tap"]
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.CHOICES)


func test_the_chance_of_a_lucky_guess_follows_the_input() -> void:
	var piles: Problem = _problem(&"cmp.to_20.more_less", 1)
	assert_float(AnswerPanel.chance_for(piles)).is_equal(0.5)
	assert_float(AnswerPanel.chance_for(piles, 1)).is_equal(1.0) # one pile left to try
	var choices: Problem = _problem(&"count.to_20.objects", 1)
	var options: int = mini(choices.distractors.size(), AnswerPanel.MAX_CHOICE_DISTRACTORS) + 1
	assert_float(AnswerPanel.chance_for(choices)).is_equal_approx(1.0 / options, 0.0001)
	assert_float(AnswerPanel.chance_for(choices, 1)).is_equal_approx(1.0 / (options - 1), 0.0001)
	assert_float(AnswerPanel.chance_for(_problem(&"count.write.numeral", 1))).is_equal(AnswerPanel.FREE_RESPONSE_CHANCE)
	assert_float(AnswerPanel.chance_for(_problem(&"pv.tens_ones.build", 1))).is_equal(AnswerPanel.FREE_RESPONSE_CHANCE)


func test_answer_modes_are_named_for_the_attempt_log() -> void:
	assert_str(AnswerPanel.answer_mode_for(_problem(&"cmp.to_20.more_less", 1))).is_equal("tap")
	assert_str(AnswerPanel.answer_mode_for(_problem(&"count.to_120.read", 1))).is_equal("tap")
	assert_str(AnswerPanel.answer_mode_for(_problem(&"count.write.numeral", 1))).is_equal("number_pad")
	assert_str(AnswerPanel.answer_mode_for(_problem(&"pv.tens_ones.build", 1))).is_equal("drag")


func test_rung_1_needs_no_picture_and_rung_2_shows_the_model_for_every_mvp_skill() -> void:
	for skill: Skill in _mvp_skills():
		for representation: StringName in skill.representations:
			var problem: Problem = _problem(skill.id, 5, representation)
			_panel.setup(problem, _rng())
			await get_tree().process_frame
			assert_object(_panel.show_hint(HintLadder.Rung.REPEAT_HIGHLIGHT)).is_null()
			var shown: VisualModel = _panel.show_hint(HintLadder.Rung.VISUAL_MODEL)
			assert_object(shown).override_failure_message("%s (%s): no model" % [skill.id, representation]).is_not_null()
			assert_dict(shown.visual).is_equal(problem.hint_steps[1]["visual"])
			assert_bool(shown.is_inside_tree()).is_true()
			# Still answerable through the same widget after the hint.
			assert_int(_panel.input_kind).is_equal(AnswerPanel.choose_input(problem))


func test_tappable_piles_stay_tappable_when_the_model_appears() -> void:
	var problem: Problem = _problem(&"cmp.to_20.more_less", 4)
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var model: VisualModel = _panel.show_hint(HintLadder.Rung.VISUAL_MODEL)
	assert_bool(model != _panel.visual_model()).is_true()
	assert_int(_panel.visual_model().pile_buttons().size()).is_equal(2)
	assert_bool(model.compact).is_true()


func test_a_number_strip_is_answered_on_a_tile_board_with_the_strip_around_the_slots() -> void:
	var problem: Problem = _problem(&"count.to_120.fill_strip", 8)
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var board: TileBoard = _panel.tile_board()
	assert_object(board).is_not_null()
	assert_int(AnswerPanel.strip_sequence(problem).count(null)).is_equal(problem.answer.size())
	var given: Array = []
	_panel.answered.connect(func(value: Variant) -> void: given.append(value))
	_give(problem, problem.answer)
	assert_bool(problem.is_correct(given[0])).is_true()


func test_ordering_three_numbers_uses_the_tiles_in_the_order_the_piles_show() -> void:
	var problem: Problem = _problem(&"cmp.to_100.order3", 2)
	assert_array(problem.meta["tile_board"]["tiles"]).is_equal(problem.meta["numbers"])
	assert_array(AnswerPanel.strip_sequence(problem)).is_empty() # bare slots, no strip
	assert_float(AnswerPanel.chance_for(problem)).is_equal_approx(1.0 / 6.0, 0.0001) # 3! orders


func test_tile_chance_counts_orders_or_sets() -> void:
	assert_float(AnswerPanel.tile_chance({"tiles": [1, 2, 3, 4, 5], "slots": 2, "ordered": true})).is_equal_approx(1.0 / 20.0, 0.0001)
	assert_float(AnswerPanel.tile_chance({"tiles": [1, 2, 3, 4, 5, 6], "slots": 4, "ordered": false})).is_equal_approx(1.0 / 15.0, 0.0001)
