# Zone 7 (Crystal Shards) through the answer panel: every skill gets the widget the plan describes (the
# crystal to light, the fraction or decimal pad or slate, the alloy mixer, the depth gauge, answer
# buttons), can be answered right and wrong through it with a mouse alone (no handwriting: the
# mouse-only Chromebook pass), and its hint pictures draw. Sibling of test_zone5_answer_panel.gd.
class_name Zone7AnswerPanelTest
extends GdUnitTestSuite

const K: Dictionary = {
	"pad": AnswerPanel.InputKind.NUMBER_PAD, "fraction_pad": AnswerPanel.InputKind.FRACTION_PAD,
	"decimal_pad": AnswerPanel.InputKind.DECIMAL_PAD, "choices": AnswerPanel.InputKind.CHOICES,
	"crystal": AnswerPanel.InputKind.CRYSTAL, "alloy": AnswerPanel.InputKind.ALLOY, "gauge": AnswerPanel.InputKind.GAUGE,
}
## The fraction preview skills: listed below with Zone 7's inputs, but their records live in Zone 6's
## file (moved at the merge, approved by Spiro), so they come before Zone 6's simplest form.
const PREVIEWS: Array[StringName] = [&"fraction.unit.identify", &"fraction.part.of_whole"]
## The inputs each skill uses without handwriting, by representation.
const EXPECTED: Dictionary = {
	&"fraction.unit.identify": {"concrete": ["fraction_pad"], "pictorial": ["fraction_pad"]},
	&"fraction.part.of_whole": {"concrete": ["crystal"], "pictorial": ["fraction_pad"], "abstract": ["fraction_pad"]},
	&"fraction.number_line.place": {"pictorial": ["choices"]},
	&"fraction.equivalent.build": {"concrete": ["crystal"], "abstract": ["pad"]},
	&"fraction.compare.like_den": {"pictorial": ["choices"], "abstract": ["choices"]},
	&"fraction.compare.unlike_den": {"pictorial": ["choices"], "abstract": ["choices"]},
	&"fraction.add.like_den": {"concrete": ["fraction_pad"], "pictorial": ["fraction_pad"], "abstract": ["fraction_pad"]},
	&"fraction.add.unlike_den": {"pictorial": ["fraction_pad"], "abstract": ["fraction_pad"]},
	&"fraction.mixed.convert": {"pictorial": ["fraction_pad", "choices"], "abstract": ["fraction_pad", "choices"]},
	&"decimal.tenths.read": {"concrete": ["decimal_pad"], "pictorial": ["decimal_pad"], "abstract": ["decimal_pad"]},
	&"decimal.hundredths.read": {"pictorial": ["decimal_pad"], "abstract": ["decimal_pad"]},
	&"decimal.fraction.convert": {"abstract": ["decimal_pad"]},
	&"decimal.compare.order": {"pictorial": ["choices"], "abstract": ["choices"]},
	&"percent.of_hundred.read": {"pictorial": ["pad"]},
	&"percent.fraction.convert": {"abstract": ["pad"]},
	&"ratio.describe.part_part": {"concrete": ["choices"], "pictorial": ["choices"]},
	&"ratio.scale.alloy": {"concrete": ["alloy"], "abstract": ["pad"]},
	&"negative.depth.read": {"pictorial": ["pad"]},
	&"negative.depth.compare": {"pictorial": ["choices"], "abstract": ["choices"]},
	&"negative.depth.move": {"pictorial": ["gauge"], "abstract": ["pad"]},
}

var _catalog: SkillCatalog
var _panel: AnswerPanel
var _given: Array = []


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_given.clear()
	_panel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	_panel.size = Vector2(1000, 760)
	_panel.slate_override = false # a mouse-only device: no handwriting
	add_child(_panel)
	auto_free(_panel)
	_panel.answered.connect(func(value: Variant) -> void: _given.append(value))


func after_test() -> void:
	TestWindow.restore(get_window())


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _problem(skill_id: StringName, seed_value: int, representation: StringName) -> Problem:
	return GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed_value, {"representation": representation})


func test_each_zone_7_skill_gets_the_input_the_plan_describes() -> void:
	assert_int(EXPECTED.size()).is_equal(_catalog.skills_in_zone(7).size() + PREVIEWS.size())
	for skill_id: StringName in PREVIEWS:
		assert_int(_catalog.skill(skill_id).zone).is_equal(6)
	for skill_id: StringName in EXPECTED:
		var skill: Skill = _catalog.skill(skill_id)
		for representation: StringName in skill.representations:
			var wanted: Array = EXPECTED[skill_id][String(representation)]
			var seen: Dictionary = {}
			for seed_value: int in range(1, 21):
				var kind: AnswerPanel.InputKind = AnswerPanel.choose_input(_problem(skill_id, seed_value, representation))
				seen[kind] = true
				var allowed: Array = wanted.map(func(name: String) -> AnswerPanel.InputKind: return K[name])
				assert_bool(allowed.has(kind)).override_failure_message("%s %s seed %d got %d" % [skill_id, representation, seed_value, kind]).is_true()
			assert_int(seen.size()).override_failure_message("%s %s should use %s" % [skill_id, representation, wanted]).is_equal(wanted.size())


func test_with_handwriting_on_fractions_and_decimals_go_to_the_slate() -> void:
	var fraction: Problem = _problem(&"fraction.unit.identify", 3, &"concrete")
	assert_int(AnswerPanel.choose_input(fraction, true)).is_equal(AnswerPanel.InputKind.FRACTION_SLATE)
	assert_str(String(AnswerPanel.answer_mode_for_kind(AnswerPanel.InputKind.FRACTION_SLATE))).is_equal("handwriting_fraction")
	var decimal: Problem = _problem(&"decimal.tenths.read", 3, &"abstract")
	assert_int(AnswerPanel.choose_input(decimal, true)).is_equal(AnswerPanel.InputKind.DECIMAL_SLATE)
	var depth: Problem = _problem(&"negative.depth.read", 3, &"pictorial")
	assert_int(AnswerPanel.choose_input(depth, true)).is_equal(AnswerPanel.InputKind.NUMBER_PAD) # no slate for a minus sign
	var crystal: Problem = _problem(&"fraction.part.of_whole", 3, &"concrete")
	assert_int(AnswerPanel.choose_input(crystal, true)).is_equal(AnswerPanel.InputKind.CRYSTAL) # the mechanic wins


func test_every_zone_7_problem_can_be_answered_right_and_wrong_with_a_mouse() -> void:
	for skill_id: StringName in EXPECTED:
		var skill: Skill = _catalog.skill(skill_id)
		for representation: StringName in skill.representations:
			for seed_value: int in range(1, 9):
				var problem: Problem = _problem(skill_id, seed_value, representation)
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				var where: String = "%s %s seed %d" % [skill_id, representation, seed_value]
				assert_bool(PanelDriver.give(_panel, problem.answer)).override_failure_message(where + ": cannot give the answer").is_true()
				assert_int(_given.size()).override_failure_message(where).is_equal(1)
				assert_bool(problem.is_correct(_given[0])).override_failure_message("%s: gave %s" % [where, _given[0]]).is_true()
				var wrong: Variant = PanelDriver.wrong_value(problem)
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				if PanelDriver.give(_panel, wrong):
					assert_bool(problem.is_correct(_given[0])).override_failure_message(where + ": a wrong answer counted").is_false()


func test_an_equal_fraction_typed_on_the_pad_is_right() -> void:
	var problem: Problem = _problem(&"fraction.unit.identify", 5, &"pictorial")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var den: int = problem.answer["den"]
	assert_bool(PanelDriver.give_fraction_pad(_panel.fraction_pad(), {"num": 2, "den": den * 2})).is_true()
	assert_bool(problem.is_correct(_given[0])).is_true()


func test_the_zone_mechanics_are_logged_as_taps() -> void:
	for kind: AnswerPanel.InputKind in [AnswerPanel.InputKind.CRYSTAL, AnswerPanel.InputKind.ALLOY, AnswerPanel.InputKind.GAUGE]:
		assert_str(String(AnswerPanel.answer_mode_for_kind(kind))).is_equal("tap")
	assert_str(String(AnswerPanel.answer_mode_for_kind(AnswerPanel.InputKind.FRACTION_PAD))).is_equal("number_pad")
	var crystal: Problem = _problem(&"fraction.part.of_whole", 2, &"concrete")
	assert_float(AnswerPanel.chance_for(crystal)).is_equal_approx(1.0 / float(int(crystal.meta["crystal"]["den"]) + 1), 0.0001)


func test_answer_buttons_read_fractions_decimals_ratios_and_depths() -> void:
	var symbols: Problem = _problem(&"fraction.compare.like_den", 1, &"abstract")
	assert_str(AnswerPanel.label_for(&"<", symbols)).is_equal("<")
	var ratio: Problem = _problem(&"ratio.describe.part_part", 1, &"concrete")
	assert_str(AnswerPanel.label_for({"a": 2, "b": 3}, ratio)).is_equal("2 : 3")
	var depth: Problem = _problem(&"negative.depth.compare", 1, &"abstract")
	assert_str(AnswerPanel.label_for(-12, depth)).is_equal("−12")
	var mixed: Problem = _problem(&"fraction.mixed.convert", 2, &"abstract")
	assert_str(AnswerPanel.label_for({"whole": 2, "num": 1, "den": 3}, mixed)).is_equal("2 1/3")
	var percent: Problem = _problem(&"percent.of_hundred.read", 1, &"pictorial")
	assert_str(AnswerPanel.label_for(37, percent)).is_equal("37%")


func test_the_hint_pictures_draw_for_three_representative_skills() -> void:
	for skill_id: StringName in [&"fraction.add.unlike_den", &"decimal.hundredths.read", &"negative.depth.move"]:
		var skill: Skill = _catalog.skill(skill_id)
		var problem: Problem = _problem(skill_id, 4, skill.representations[0])
		_panel.setup(problem, _rng())
		var model: VisualModel = _panel.show_hint(HintLadder.Rung.VISUAL_MODEL)
		assert_object(model).override_failure_message(String(skill_id)).is_not_null()
		assert_str(String(model.visual_type())).is_equal(String(problem.hint_steps[1]["visual"]["type"]))
		_panel.show_hint(HintLadder.Rung.WORKED_EXAMPLE)
		assert_object(_panel.example_card()).is_not_null()
		await await_idle_frame()
