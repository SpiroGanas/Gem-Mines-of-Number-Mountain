# Zone 4 (Factor Workshop) through the answer panel: every skill's problems render, can be answered
# right and wrong through the widget the panel picks (NumberPad, ChoiceButtons, an unordered or ordered
# TileBoard or the ArrayBuilder), and the hint pictures draw. Sibling of test_answer_panel.gd, which
# covers Zones 1-3.
class_name Zone4AnswerPanelTest
extends GdUnitTestSuite

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


func test_each_zone_4_skill_gets_the_input_the_plan_describes() -> void:
	var by_input: Dictionary = {
		AnswerPanel.InputKind.NUMBER_PAD: [&"mult.facts.0_5", &"mult.facts.6_10", &"mult.facts.mixed", &"div.sharing.equal_shares", &"div.facts.by_2_5", &"div.facts.by_6_10", &"mul.common.first"],
		AnswerPanel.InputKind.ARRAY: [&"fac.pairs.rectangles"],
		AnswerPanel.InputKind.CHOICES: [&"fac.check.is_factor", &"mul.check.is_multiple", &"prime.classify.single"],
		AnswerPanel.InputKind.TILES: [&"fac.list.find_all", &"mul.list.first_k", &"prime.classify.set"],
	}
	var counted: int = 0
	for kind: AnswerPanel.InputKind in by_input:
		for skill_id: StringName in by_input[kind]:
			counted += 1
			for representation: StringName in _catalog.skill(skill_id).representations:
				for seed_value: int in range(1, 11):
					assert_int(AnswerPanel.choose_input(_problem(skill_id, seed_value, representation))).override_failure_message("%s (%s) seed %d" % [skill_id, representation, seed_value]).is_equal(kind)
	assert_int(counted).is_equal(14) # prime.explain.factor_pairs is mixed, below


func test_factor_pairs_get_a_number_pad_to_count_and_buttons_to_decide() -> void:
	var kinds: Dictionary = {}
	for seed_value: int in range(1, 60):
		var problem: Problem = _problem(&"prime.explain.factor_pairs", seed_value)
		var kind: AnswerPanel.InputKind = AnswerPanel.choose_input(problem)
		kinds[kind] = true
		assert_int(kind).is_equal(AnswerPanel.InputKind.NUMBER_PAD if problem.answer is int else AnswerPanel.InputKind.CHOICES)
	assert_int(kinds.size()).is_equal(2)


func test_every_zone_4_problem_can_be_answered_correctly_through_its_widget() -> void:
	for skill: Skill in _catalog.skills_in_zone(4):
		for representation: StringName in skill.representations:
			for seed_value: int in range(1, 31):
				var problem: Problem = _problem(skill.id, seed_value, representation)
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given), CONNECT_ONE_SHOT)
				assert_bool(PanelDriver.give(_panel, problem.answer)).override_failure_message("%s seed %d: could not give %s" % [skill.id, seed_value, problem.answer]).is_true()
				assert_int(heard.size()).override_failure_message("%s seed %d: no answer came out" % [skill.id, seed_value]).is_equal(1)
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: gave %s, expected %s" % [skill.id, seed_value, heard[0], problem.answer]).is_true()


func test_every_zone_4_problem_judges_every_named_wrong_answer_as_wrong() -> void:
	for skill: Skill in _catalog.skills_in_zone(4):
		for seed_value: int in range(1, 31):
			var problem: Problem = _problem(skill.id, seed_value)
			for entry: Dictionary in problem.distractors:
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given), CONNECT_ONE_SHOT)
				var could_give: bool = PanelDriver.give(_panel, entry["value"])
				# Answer buttons offer at most the first three wrong answers; the other widgets take any.
				if not could_give:
					assert_int(_panel.input_kind).is_equal(AnswerPanel.InputKind.CHOICES)
					continue
				assert_int(heard.size()).override_failure_message("%s seed %d: no answer came out" % [skill.id, seed_value]).is_equal(1)
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: %s was accepted but is a named mistake" % [skill.id, seed_value, heard[0]]).is_false()


func test_yes_and_no_buttons_read_yes_and_no() -> void:
	for skill_id: StringName in [&"fac.check.is_factor", &"mul.check.is_multiple", &"prime.classify.single"]:
		var problem: Problem = _problem(skill_id, 3)
		_panel.setup(problem, _rng())
		var texts: Array[String] = []
		for index: int in _panel.choices().button_count():
			texts.append(_panel.choices().button(index).text)
		texts.sort()
		assert_array(texts).override_failure_message(String(skill_id)).is_equal(["No", "Yes"])


func test_an_unordered_board_takes_the_answer_in_any_order() -> void:
	for skill_id: StringName in [&"fac.list.find_all", &"prime.classify.set"]:
		var problem: Problem = _problem(skill_id, 4)
		_panel.setup(problem, _rng())
		_panel.set_enabled(true)
		var heard: Array = []
		_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
		var reversed: Array = problem.answer.duplicate()
		reversed.reverse()
		var board: TileBoard = _panel.tile_board()
		board.clear()
		for index: int in reversed.size():
			board.put(reversed[index], index)
		board.submit()
		assert_int(heard.size()).is_equal(1)
		assert_bool(problem.is_correct(heard[0])).override_failure_message(String(skill_id)).is_true()


func test_an_ordered_board_for_multiples_needs_the_order() -> void:
	var problem: Problem = _problem(&"mul.list.first_k", 4)
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var heard: Array = []
	_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
	var reversed: Array = problem.answer.duplicate()
	reversed.reverse()
	var board: TileBoard = _panel.tile_board()
	board.clear()
	for index: int in reversed.size():
		board.put(reversed[index], index)
	board.submit()
	assert_bool(problem.is_correct(heard[0])).is_false()


func test_rungs_2_and_3_show_a_model_and_a_worked_example_for_every_zone_4_skill() -> void:
	for skill: Skill in _catalog.skills_in_zone(4):
		for representation: StringName in skill.representations:
			for seed_value: int in [3, 11, 24]:
				var problem: Problem = _problem(skill.id, seed_value, representation)
				_panel.setup(problem, _rng())
				await get_tree().process_frame
				assert_object(_panel.show_hint(HintLadder.Rung.REPEAT_HIGHLIGHT)).is_null()
				var shown: VisualModel = _panel.show_hint(HintLadder.Rung.VISUAL_MODEL)
				assert_object(shown).override_failure_message("%s (%s): no model" % [skill.id, representation]).is_not_null()
				assert_dict(shown.visual).is_equal(problem.hint_steps[1]["visual"])
				_panel.show_hint(HintLadder.Rung.WORKED_EXAMPLE)
				await get_tree().process_frame
				assert_object(_panel.example_card()).override_failure_message("%s: no worked example" % skill.id).is_not_null()
				assert_int(_panel.input_kind).is_equal(AnswerPanel.choose_input(problem))


func test_every_word_in_every_zone_4_prompt_and_hint_comes_from_the_text_table() -> void:
	for skill: Skill in _catalog.skills_in_zone(4):
		for seed_value: int in range(1, 21):
			var problem: Problem = _problem(skill.id, seed_value)
			var asked: String = Text.get_line(problem.prompt_line_id, problem.prompt_params)
			assert_bool(asked.is_empty() or asked.begins_with("[") or asked.contains("{")).override_failure_message("%s: '%s'" % [skill.id, asked]).is_false()
			var example: Dictionary = problem.hint_steps[2]["example"]
			for text: String in [Text.get_line(example["prompt_line_id"], example["prompt_params"]), Text.get_line(example["answer_line_id"], example["answer_params"])]:
				assert_bool(text.is_empty() or text.begins_with("[") or text.contains("{")).override_failure_message("%s: '%s'" % [skill.id, text]).is_false()
			for entry: Dictionary in problem.distractors:
				assert_bool(Text.has_line(StringName("bolt.misconception." + String(entry["misconception"])))).is_true()
