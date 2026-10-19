# Zone 6 (Gear Works) through the answer panel: every skill gets the widget the plan describes (the gear
# bench, the tile board, Yes and No, number pad, or answer buttons reading "1, 2, 4", "3/4" and "2 : 3"),
# can be answered right and wrong through it, and its pictures draw. Sibling of
# test_zone5_answer_panel.gd.
class_name Zone6AnswerPanelTest
extends GdUnitTestSuite

var _catalog: SkillCatalog
var _panel: AnswerPanel


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_panel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	_panel.size = Vector2(1000, 760)
	_panel.slate_override = false
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


func test_each_zone_6_skill_gets_the_input_the_plan_describes() -> void:
	var by_input: Dictionary = {
		AnswerPanel.InputKind.TILES: [&"lcm.list.common_multiples"],
		AnswerPanel.InputKind.NUMBER_PAD: [&"gcf.find.by_listing", &"gcf.find.by_factor_tree", &"lcm.find.by_listing", &"lcm.find.by_factorization", &"lcm.relation.gcf_times_lcm", &"gear.sync.turns_to_align"],
		AnswerPanel.InputKind.CHOICES: [&"gcf.list.common_factors", &"gcf.coprime.identify", &"simplify.fraction.gcf", &"simplify.ratio.gcf"],
	}
	var counted: int = 0
	for kind: AnswerPanel.InputKind in by_input:
		for skill_id: StringName in by_input[kind]:
			counted += 1
			for representation: StringName in _catalog.skill(skill_id).representations:
				for seed_value: int in range(1, 11):
					assert_int(AnswerPanel.choose_input(_problem(skill_id, seed_value, representation))).override_failure_message("%s seed %d" % [skill_id, seed_value]).is_equal(kind)
	# gear.ratio.teeth: the gear bench when concrete, answer buttons when pictorial.
	counted += 1
	for seed_value: int in range(1, 11):
		assert_int(AnswerPanel.choose_input(_problem(&"gear.ratio.teeth", seed_value, &"concrete"))).is_equal(AnswerPanel.InputKind.GEAR)
		assert_int(AnswerPanel.choose_input(_problem(&"gear.ratio.teeth", seed_value, &"pictorial"))).is_equal(AnswerPanel.InputKind.CHOICES)
	# The fraction preview skills (moved here from Zone 7's file at the merge) use Zone 7's inputs, the
	# crystal and the fraction pad; test_zone7_answer_panel.gd checks which one each gets.
	for skill_id: StringName in [&"fraction.unit.identify", &"fraction.part.of_whole"]:
		assert_int(_catalog.skill(skill_id).zone).is_equal(6)
		counted += 1
	assert_int(counted).is_equal(_catalog.skills_in_zone(6).size())


func test_the_gear_bench_is_logged_as_drag_and_its_guess_chance_is_one_gear_of_the_tray() -> void:
	var problem: Problem = _problem(&"gear.ratio.teeth", 1, &"concrete")
	assert_str(String(AnswerPanel.answer_mode_for(problem))).is_equal("drag")
	assert_float(AnswerPanel.chance_for(problem)).is_equal_approx(1.0 / problem.meta["gear_bench"]["tray"].size(), 0.0001)


func test_every_zone_6_problem_can_be_answered_correctly_through_its_widget() -> void:
	for skill: Skill in _catalog.skills_in_zone(6):
		for representation: StringName in skill.representations:
			for seed_value: int in range(1, 9):
				var problem: Problem = _problem(skill.id, seed_value, representation)
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
				assert_bool(PanelDriver.give(_panel, problem.answer)).override_failure_message("%s seed %d: could not give %s" % [skill.id, seed_value, problem.answer]).is_true()
				assert_int(heard.size()).override_failure_message("%s seed %d: %d answers came out" % [skill.id, seed_value, heard.size()]).is_equal(1)
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: gave %s, expected %s" % [skill.id, seed_value, heard[0], problem.answer]).is_true()


func test_every_zone_6_problem_judges_every_named_wrong_answer_as_wrong() -> void:
	for skill: Skill in _catalog.skills_in_zone(6):
		for seed_value: int in range(1, 9):
			var problem: Problem = _problem(skill.id, seed_value)
			for entry: Dictionary in problem.distractors.slice(0, AnswerPanel.MAX_CHOICE_DISTRACTORS):
				var heard: Array = []
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_panel.answered.connect(func(given: Variant) -> void: heard.append(given))
				if not PanelDriver.give(_panel, entry["value"]):
					continue # a wrong number the widget cannot even build is fine
				assert_bool(problem.is_correct(heard[0])).override_failure_message("%s seed %d: %s accepted" % [skill.id, seed_value, entry["value"]]).is_false()


func test_a_simplest_form_question_judges_by_form_not_value() -> void:
	# Zone 7 judges fractions by value (2/4 is right for 1/2); simplify.* sets meta.simplest_form so a
	# fraction or ratio that is equal but not in lowest terms stays the named mistake.
	var checked: int = 0
	for skill_id: StringName in [&"simplify.fraction.gcf", &"simplify.ratio.gcf"]:
		for seed_value: int in range(1, 41):
			var problem: Problem = _problem(skill_id, seed_value)
			assert_bool(problem.meta.get("simplest_form", false)).is_true()
			for entry: Dictionary in problem.distractors:
				if entry["misconception"] != &"partially_simplified":
					continue
				checked += 1
				assert_bool(Problem.same_value(entry["value"], problem.answer)).is_true() # equal in value...
				assert_bool(problem.is_correct(entry["value"])).is_false() # ...and still wrong
				assert_str(String(MineScreen.misconception_of(problem, entry["value"]))).is_equal("partially_simplified")
	assert_int(checked).is_greater(10)


func test_fraction_and_ratio_buttons_read_as_the_child_writes_them() -> void:
	var fraction: Problem = _problem(&"simplify.fraction.gcf", 3)
	_panel.setup(fraction, _rng())
	var labels: PackedStringArray = PackedStringArray()
	for index: int in _panel.choices().button_count():
		labels.append(_panel.choices().button(index).text)
	assert_bool(labels.has("%d/%d" % [fraction.answer["num"], fraction.answer["den"]])).is_true()
	var ratio: Problem = _problem(&"simplify.ratio.gcf", 3)
	_panel.setup(ratio, _rng())
	labels.clear()
	for index: int in _panel.choices().button_count():
		labels.append(_panel.choices().button(index).text)
	assert_bool(labels.has("%d : %d" % [ratio.answer["a"], ratio.answer["b"]])).is_true()


func test_the_lists_and_gears_pictures_draw_and_hints_climb_every_rung() -> void:
	for skill: Skill in _catalog.skills_in_zone(6):
		for representation: StringName in skill.representations:
			var problem: Problem = _problem(skill.id, 5, representation)
			_panel.setup(problem, _rng())
			_panel.set_enabled(true)
			await await_idle_frame()
			for rung: HintLadder.Rung in [HintLadder.Rung.VISUAL_MODEL, HintLadder.Rung.WORKED_EXAMPLE]:
				var shown: VisualModel = _panel.show_hint(rung)
				assert_object(shown).override_failure_message("%s rung %d" % [skill.id, rung]).is_not_null()
				assert_str(String(shown.visual_type())).is_equal(String(problem.hint_steps[1]["visual"]["type"]))
			assert_object(_panel.example_card()).is_not_null()
