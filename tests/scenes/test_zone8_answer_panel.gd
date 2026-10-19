# Zone 8 (Power Tower) through the answer panel (Sprints 36-37): every skill gets the widget the plan
# describes (the vault lock, the tower elevator, the counterweight lever, the scientific-notation and
# base pads, answer buttons, the number pad), can be answered right and wrong through it with a mouse
# alone (no handwriting: the mouse-only Chromebook pass), and its hint pictures draw. In Scholar mode
# with a keyboard, the typed answers move to keyboard entry; "Use the pad" brings the pad back.
class_name Zone8AnswerPanelTest
extends GdUnitTestSuite

const I := AnswerPanel.InputKind
## The inputs each skill uses without handwriting and without a keyboard, by representation.
const EXPECTED: Dictionary = {
	&"exp.repeated_mult.read": {"concrete": I.CHOICES, "pictorial": I.CHOICES, "abstract": I.CHOICES},
	&"exp.evaluate.small": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"exp.square.numbers": {"concrete": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"exp.cube.numbers": {"concrete": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"root.square.perfect": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"exp.powers_of_two.list": {"concrete": I.TOWER, "abstract": I.CHOICES},
	&"exp.powers_of_ten.list": {"abstract": I.NUMBER_PAD},
	&"exp.zero_one.rules": {"abstract": I.CHOICES},
	&"base.binary.to_decimal": {"concrete": I.NUMBER_PAD, "pictorial": I.NUMBER_PAD},
	&"base.binary.from_decimal": {"concrete": I.VAULT, "pictorial": I.CHOICES},
	&"base.binary.add": {"pictorial": I.BASE_PAD},
	&"base.other.to_decimal": {"pictorial": I.NUMBER_PAD},
	&"base.other.from_decimal": {"concrete": I.VAULT, "pictorial": I.CHOICES},
	&"sci.notation.read": {"abstract": I.NUMBER_PAD},
	&"sci.notation.write": {"abstract": I.SCI_PAD},
	&"lever.counterweight.balance": {"concrete": I.LEVER, "pictorial": I.NUMBER_PAD},
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
	_panel.keyboard_override = false
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


func test_each_zone_8_skill_gets_the_input_the_plan_describes() -> void:
	assert_int(EXPECTED.size()).is_equal(_catalog.skills_in_zone(8).size())
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			for seed_value: int in [3, 17]:
				var problem: Problem = _problem(skill_id, seed_value, StringName(representation))
				_panel.setup(problem, _rng(seed_value))
				assert_int(_panel.input_kind).override_failure_message("%s %s" % [skill_id, representation]).is_equal(EXPECTED[skill_id][representation])


func test_every_zone_8_problem_can_be_answered_right_and_wrong() -> void:
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			for seed_value: int in [5, 29, 61]:
				var problem: Problem = _problem(skill_id, seed_value, StringName(representation))
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				var where: String = "%s %s seed %d" % [skill_id, representation, seed_value]
				assert_bool(PanelDriver.give(_panel, problem.answer)).override_failure_message(where).is_true()
				assert_int(_given.size()).override_failure_message(where).is_equal(1)
				assert_bool(problem.is_correct(_given[0])).override_failure_message("%s gave %s" % [where, _given[0]]).is_true()
				# A wrong answer that the widget can give is judged wrong (the panel never decides).
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				var wrong: Variant = PanelDriver.wrong_value(problem)
				# (A wrong answer longer than the pad holds cannot be typed; the pad keeps its first digits.)
				if PanelDriver.give(_panel, wrong) and not _given.is_empty() and Problem.same(_given[0], wrong):
					assert_bool(problem.is_correct(_given[0])).override_failure_message(where + " wrong").is_false()


func test_the_answer_buttons_write_out_the_calculation() -> void:
	var problem: Problem = _problem(&"exp.repeated_mult.read", 4, &"abstract")
	_panel.setup(problem, _rng())
	var labels: Array[String] = []
	for index: int in _panel.choices().button_count():
		labels.append(_panel.choices().button(index).text)
	var b: int = problem.prompt_params["b"]
	var e: int = problem.prompt_params["e"]
	var expected: String = " × ".join(PackedStringArray(_repeat(str(b), e)))
	assert_array(labels).contains([expected])
	assert_str(AnswerPanel.label_for({"base": 2, "digits": [1, 1, 0, 1]}, problem)).is_equal("1101")


func _repeat(text: String, count: int) -> Array:
	var items: Array = []
	for index: int in count:
		items.append(text)
	return items


func test_scholar_mode_with_a_keyboard_types_the_answer() -> void:
	_panel.keyboard_override = true
	for skill_id: StringName in [&"exp.evaluate.small", &"sci.notation.write", &"base.binary.add", &"exp.powers_of_ten.list"]:
		var problem: Problem = _problem(skill_id, 8, _catalog.skill(skill_id).representations[-1])
		_panel.setup(problem, _rng())
		_panel.set_enabled(true)
		assert_int(_panel.input_kind).override_failure_message(String(skill_id)).is_equal(I.KEYBOARD)
		_given.clear()
		assert_bool(PanelDriver.give(_panel, problem.answer)).is_true()
		assert_bool(problem.is_correct(_given[0])).override_failure_message("%s typed %s" % [skill_id, _given[0]]).is_true()
		assert_str(String(AnswerPanel.answer_mode_for_kind(_panel.input_kind))).is_equal("keyboard")
	# The mechanics stay mechanics: a keyboard does not replace the vault lock.
	_panel.setup(_problem(&"base.binary.from_decimal", 8, &"concrete"), _rng())
	assert_int(_panel.input_kind).is_equal(I.VAULT)
	# Zone 7's typed answers take the keyboard too.
	_panel.setup(_problem(&"fraction.add.like_den", 8, &"abstract"), _rng())
	assert_int(_panel.input_kind).is_equal(I.KEYBOARD)


func test_use_the_pad_brings_the_pad_back() -> void:
	_panel.keyboard_override = true
	var problem: Problem = _problem(&"sci.notation.write", 9, &"abstract")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	_panel.keyboard_entry().use_pad_button().pressed.emit()
	assert_int(_panel.input_kind).is_equal(I.SCI_PAD)
	assert_object(_panel.keyboard_entry()).is_null()
	_given.clear()
	assert_bool(PanelDriver.give(_panel, problem.answer)).is_true()
	assert_bool(problem.is_correct(_given[0])).is_true()


func test_explorer_mode_never_offers_the_keyboard() -> void:
	_panel.keyboard_override = null
	ScholarMode.forced_setting = "explorer"
	ScholarMode.forced_keyboard = true
	_panel.setup(_problem(&"exp.evaluate.small", 2, &"abstract"), _rng())
	assert_int(_panel.input_kind).is_equal(I.NUMBER_PAD)
	ScholarMode.forced_setting = "scholar"
	_panel.setup(_problem(&"exp.evaluate.small", 2, &"abstract"), _rng())
	assert_int(_panel.input_kind).is_equal(I.KEYBOARD)
	ScholarMode.forced_keyboard = false # Scholar mode, but no key was ever pressed: the pad
	_panel.setup(_problem(&"exp.evaluate.small", 2, &"abstract"), _rng())
	assert_int(_panel.input_kind).is_equal(I.NUMBER_PAD)
	ScholarMode.reset_overrides()


func test_the_pad_has_room_for_a_million() -> void:
	var problem: Problem = _problem(&"exp.powers_of_ten.list", 1, &"abstract")
	_panel.setup(problem, _rng())
	assert_int(_panel.number_pad().max_digits).is_equal(7)


func test_every_zone_8_hint_picture_draws() -> void:
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			var problem: Problem = _problem(skill_id, 13, StringName(representation))
			_panel.setup(problem, _rng())
			var shown: VisualModel = _panel.show_hint(HintLadder.Rung.WORKED_EXAMPLE)
			assert_object(shown).override_failure_message(String(skill_id)).is_not_null()
			await await_idle_frame()
