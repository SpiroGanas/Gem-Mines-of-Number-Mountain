# Zone 5 (Prime Caverns) through the answer panel: every skill gets the widget the plan describes (the
# sieve grid, the factor tree, Yes and No, or product buttons), can be answered right and wrong through
# it, and its hint pictures draw. Sibling of test_zone4_answer_panel.gd.
class_name Zone5AnswerPanelTest
extends GdUnitTestSuite

var _catalog: SkillCatalog
var _panel: AnswerPanel


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_panel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	_panel.size = Vector2(1000, 760)
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


func test_each_zone_5_skill_gets_the_input_the_plan_describes() -> void:
	var by_input: Dictionary = {
		AnswerPanel.InputKind.SIEVE: [&"sieve.mark.multiples_of", &"sieve.find.primes_to_50", &"sieve.find.primes_to_100"],
		AnswerPanel.InputKind.TREE: [&"pf.tree.build"],
		AnswerPanel.InputKind.CHOICES: [&"div.rule.2_5_10", &"div.rule.3_9", &"div.rule.4_6", &"div.rule.mixed", &"pf.list.write", &"pf.check.equal_products", &"pf.fta.unique"],
	}
	var counted: int = 0
	for kind: AnswerPanel.InputKind in by_input:
		for skill_id: StringName in by_input[kind]:
			counted += 1
			for representation: StringName in _catalog.skill(skill_id).representations:
				for seed_value: int in range(1, 11):
					assert_int(AnswerPanel.choose_input(_problem(skill_id, seed_value, representation))).override_failure_message("%s seed %d" % [skill_id, seed_value]).is_equal(kind)
	assert_int(counted).is_equal(_catalog.skills_in_zone(5).size())


func test_the_sieve_and_the_tree_are_logged_as_tap_and_drag() -> void:
	assert_str(String(AnswerPanel.answer_mode_for(_problem(&"sieve.find.primes_to_50", 1)))).is_equal("tap")
	assert_str(String(AnswerPanel.answer_mode_for(_problem(&"pf.tree.build", 1)))).is_equal("drag")
	assert_float(AnswerPanel.chance_for(_problem(&"sieve.find.primes_to_50", 1))).is_equal(AnswerPanel.FREE_RESPONSE_CHANCE)
	assert_float(AnswerPanel.chance_for(_problem(&"pf.tree.build", 1))).is_equal(AnswerPanel.FREE_RESPONSE_CHANCE)


func test_every_zone_5_problem_can_be_answered_correctly_through_its_widget() -> void:
	for skill: Skill in _catalog.skills_in_zone(5):
		for representation: StringName in skill.representations:
			for seed_value: int in range(1, 16):
				var problem: Problem = _problem(skill.id, seed_value, representation)
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
				assert_bool(PanelDriver.give(_panel, problem.answer)).override_failure_message("%s seed %d: could not give %s" % [skill.id, seed_value, problem.answer]).is_true()
				assert_int(heard.size()).override_failure_message("%s seed %d: %d answers came out" % [skill.id, seed_value, heard.size()]).is_equal(1)
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: gave %s, expected %s" % [skill.id, seed_value, heard[0], problem.answer]).is_true()


func test_every_zone_5_problem_judges_every_named_wrong_answer_as_wrong() -> void:
	for skill: Skill in _catalog.skills_in_zone(5):
		for seed_value: int in range(1, 16):
			var problem: Problem = _problem(skill.id, seed_value)
			for entry: Dictionary in problem.distractors:
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
				if not PanelDriver.give(_panel, entry["value"]):
					# Answer buttons offer at most three wrong answers; a tree cannot grow every wrong recipe.
					assert_bool(_panel.input_kind in [AnswerPanel.InputKind.CHOICES, AnswerPanel.InputKind.TREE]).is_true()
					continue
				assert_int(heard.size()).override_failure_message("%s seed %d: no answer came out" % [skill.id, seed_value]).is_equal(1)
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: %s was accepted" % [skill.id, seed_value, heard[0]]).is_false()


func test_a_tree_with_a_rock_left_standing_is_the_stopped_at_composite_mistake() -> void:
	var problem: Problem = _problem(&"pf.tree.build", 7)
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var heard: Array = []
	_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
	_panel.factor_tree().done_button().pressed.emit() # Done before any split: the boulder itself
	assert_bool(problem.is_correct(heard[0])).is_false()


func test_product_buttons_read_as_products() -> void:
	var problem: Problem = _problem(&"pf.fta.unique", 2)
	_panel.setup(problem, _rng())
	for index: int in _panel.choices().button_count():
		assert_bool(_panel.choices().button(index).text.contains(" × ")).is_true()


func test_rungs_2_and_3_show_a_model_and_a_worked_example_for_every_zone_5_skill() -> void:
	for skill: Skill in _catalog.skills_in_zone(5):
		for representation: StringName in skill.representations:
			for seed_value: int in [3, 11]:
				var problem: Problem = _problem(skill.id, seed_value, representation)
				_panel.setup(problem, _rng())
				await get_tree().process_frame
				var shown: VisualModel = _panel.show_hint(HintLadder.Rung.VISUAL_MODEL)
				assert_object(shown).override_failure_message("%s (%s): no model" % [skill.id, representation]).is_not_null()
				assert_dict(shown.visual).is_equal(problem.hint_steps[1]["visual"])
				_panel.show_hint(HintLadder.Rung.WORKED_EXAMPLE)
				await get_tree().process_frame
				assert_object(_panel.example_card()).override_failure_message("%s: no worked example" % skill.id).is_not_null()


func test_the_digits_picture_lights_the_rule_and_writes_the_digit_sum() -> void:
	assert_array(VisualModel.lit_digits(3, "last")).is_equal([2])
	assert_array(VisualModel.lit_digits(3, "last_two")).is_equal([1, 2])
	assert_array(VisualModel.lit_digits(3, "sum")).is_equal([0, 1, 2])
	assert_str(VisualModel.digits_caption({"type": "digits", "digits": [1, 2, 6], "focus": "sum"})).is_equal("1 + 2 + 6 = 9")
	assert_str(VisualModel.digits_caption({"type": "digits", "digits": [8, 5], "focus": "last"})).is_equal("")
	assert_str(VisualModel.digits_caption({"type": "digits", "digits": [1, 2], "focus": "recipe", "recipe": [2, 2, 3]})).is_equal("= 2 × 2 × 3")


func test_every_word_in_every_zone_5_prompt_and_hint_comes_from_the_text_table() -> void:
	for skill: Skill in _catalog.skills_in_zone(5):
		for seed_value: int in range(1, 21):
			var problem: Problem = _problem(skill.id, seed_value)
			var asked: String = Text.get_line(problem.prompt_line_id, problem.prompt_params)
			assert_bool(asked.is_empty() or asked.begins_with("[") or asked.contains("{")).override_failure_message("%s: '%s'" % [skill.id, asked]).is_false()
			var example: Dictionary = problem.hint_steps[2]["example"]
			for text: String in [Text.get_line(example["prompt_line_id"], example["prompt_params"]), Text.get_line(example["answer_line_id"], example["answer_params"])]:
				assert_bool(text.is_empty() or text.begins_with("[") or text.contains("{")).override_failure_message("%s: '%s'" % [skill.id, text]).is_false()
			for entry: Dictionary in problem.distractors:
				assert_bool(Text.has_line(StringName("bolt.misconception." + String(entry["misconception"])))).is_true()


func test_a_zone_5_rock_pays_the_rare_gem_of_its_number() -> void:
	var problem: Problem = _problem(&"div.rule.mixed", 1)
	problem.prompt_params["n"] = 127
	assert_str(String(RewardsRules.gem_for_rock(5, MineScreen.number_of(problem)))).is_equal(String(GemArt.MERSENNE))
	problem.prompt_params["n"] = 43 # 41 and 43 are twin primes
	assert_str(String(RewardsRules.gem_for_rock(5, MineScreen.number_of(problem)))).is_equal(String(GemArt.TWIN))
