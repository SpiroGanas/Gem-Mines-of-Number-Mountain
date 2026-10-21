# Zone 12 (The Infinite Core) through the answer panel (P5-S47, S48): every skill gets the input the plan describes, can be
# answered right and wrong through it with a mouse alone, and the pictures draw. The proof builder itself is covered below.
class_name Zone12AnswerPanelTest
extends GdUnitTestSuite

const I := AnswerPanel.InputKind
const EXPECTED: Dictionary = {
	&"proof.parts.identify": {"pictorial": I.CHOICES},
	&"proof.order.chain": {"pictorial": I.TILES},
	&"proof.justify.step": {"abstract": I.CHOICES},
	&"proof.euclid.infinite_primes": {"concrete": I.BUILDER},
	&"proof.contradiction.recognize": {"pictorial": I.CHOICES},
	&"proof.sqrt2.irrational": {"concrete": I.BUILDER},
	&"sets.integer.classify": {"concrete": I.CHOICES},
	&"sets.rational.classify": {"concrete": I.CHOICES},
	&"sets.real.classify": {"concrete": I.CHOICES},
	&"mystery.goldbach.find_pair": {"pictorial": I.CHOICES},
	&"mystery.twin.next_pair": {"pictorial": I.NUMBER_PAD},
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


func test_each_zone_12_skill_gets_the_input_the_plan_describes() -> void:
	assert_int(EXPECTED.size()).is_equal(_catalog.skills_in_zone(12).size())
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			for seed_value: int in [3, 17]:
				var problem: Problem = _problem(skill_id, seed_value, StringName(representation))
				_panel.setup(problem, _rng(seed_value))
				assert_int(_panel.input_kind).override_failure_message("%s %s" % [skill_id, representation]).is_equal(EXPECTED[skill_id][representation])


func test_every_zone_12_problem_can_be_answered_right_and_wrong() -> void:
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
				if problem.distractors.is_empty():
					continue
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				var wrong: Variant = PanelDriver.wrong_value(problem)
				if PanelDriver.give(_panel, wrong) and not _given.is_empty() and Problem.same(_given[0], wrong):
					assert_bool(problem.is_correct(_given[0])).override_failure_message(where + " wrong").is_false()


func test_answer_buttons_read_words_numbers_and_pairs() -> void:
	var justify: Problem = _problem(&"proof.justify.step", 4, &"abstract")
	_panel.setup(justify, _rng())
	var texts: Array[String] = []
	for index: int in _panel.choices().values_in_order().size():
		texts.append(_panel.choices().button(index).text)
	assert_bool(texts.has(Text.get_line(StringName("z12.why." + str(justify.answer))))).is_true()
	var pair: Problem = _problem(&"mystery.goldbach.find_pair", 4, &"pictorial")
	_panel.setup(pair, _rng())
	var labels: Array[String] = []
	for index: int in _panel.choices().values_in_order().size():
		labels.append(_panel.choices().button(index).text)
	assert_bool(labels.has(str(pair.answer))).is_true()
	var ring: Problem = _problem(&"sets.real.classify", 4, &"concrete")
	_panel.setup(ring, _rng())
	assert_bool(_panel.choices().button(0).text.length() > 0).is_true()


func test_the_pictures_are_shown_with_room_for_their_cards() -> void:
	for skill_id: StringName in EXPECTED:
		var representation: StringName = StringName(EXPECTED[skill_id].keys()[0])
		var problem: Problem = _problem(skill_id, 11, representation)
		_panel.setup(problem, _rng())
		if problem.visual.is_empty():
			continue
		var model: VisualModel = _panel.visual_model()
		assert_object(model).override_failure_message(str(skill_id)).is_not_null()
		assert_str(str(model.visual_type())).is_equal(str(problem.visual["type"]))
		assert_float(model.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()) * 2.0)


# --- The proof builder ---------------------------------------------------------------------------------


func _builder(proof_id: StringName = &"proof.euclid.infinite_primes") -> ProofBuilder:
	var builder: ProofBuilder = load("res://scenes/zones/z12_infinite_core/proof_builder.tscn").instantiate()
	builder.size = Vector2(1000, 760)
	add_child(builder)
	auto_free(builder)
	builder.setup({"proof_id": String(proof_id)})
	return builder


func test_a_decoy_slides_back_with_a_gentle_line_and_costs_nothing() -> void:
	var builder: ProofBuilder = _builder()
	builder.tile_button(&"d1").pressed.emit()
	assert_str(str(builder.placement[0]["tile"])).is_equal("d1")
	builder.check_button().pressed.emit()
	assert_str(str(builder.placement[0]["tile"])).is_empty() # back in the tray
	assert_bool(builder.tile_button(&"d1").visible).is_true()
	assert_str(builder.feedback_text()).is_equal(Text.get_line(&"z12.proof.fb.n_plus_one_is_prime"))
	assert_bool(builder.feedback_text().to_lower().contains("wrong")).is_false()
	assert_bool(builder.is_done()).is_false()


func test_a_step_in_the_wrong_place_is_marked_and_a_wrong_reason_too() -> void:
	var builder: ProofBuilder = _builder()
	builder.tile_button(&"s2").pressed.emit() # needs s1 first
	builder.chip_button(&"build").pressed.emit()
	builder.check_button().pressed.emit()
	assert_array(builder.marked).contains_exactly([0])
	assert_str(builder.slot_button(0).text).starts_with("!")
	builder.take_back(0)
	builder.tile_button(&"s1").pressed.emit()
	builder.chip_button(&"build").pressed.emit() # s1 is an assumption
	builder.check_button().pressed.emit()
	assert_str(builder.feedback_text()).is_equal(Text.get_line(&"z12.builder.fb_justification"))


func test_tapping_a_picked_slot_again_takes_its_step_back() -> void:
	var builder: ProofBuilder = _builder()
	builder.tile_button(&"s1").pressed.emit()
	assert_bool(builder.tile_button(&"s1").visible).is_false()
	builder.slot_button(0).pressed.emit()
	assert_bool(builder.tile_button(&"s1").visible).is_true()


func test_the_whole_proof_in_any_valid_order_hands_in_the_proof_id() -> void:
	var builder: ProofBuilder = _builder()
	var handed: Array[String] = []
	builder.submitted.connect(func(id: String) -> void: handed.append(id))
	for id: StringName in [&"s1", &"s2", &"s3", &"s5", &"s4", &"s6", &"s7"]: # s5 before s4 is fine
		builder.tile_button(id).pressed.emit()
		builder.chip_button(builder.proof.step(id)["justification"]).pressed.emit()
	builder.check_button().pressed.emit()
	assert_array(handed).contains_exactly(["proof.euclid.infinite_primes"])
	assert_bool(builder.is_done()).is_true()


func test_hints_light_then_place_then_give_the_reason() -> void:
	var builder: ProofBuilder = _builder(&"proof.practice.even_plus_even")
	builder.hint_button().pressed.emit()
	assert_str(str(builder.lit_tile())).is_equal("s1")
	assert_str(str(builder.placement[0]["tile"])).is_empty()
	builder.hint_button().pressed.emit()
	assert_str(str(builder.placement[0]["tile"])).is_equal("s1")
	builder.hint_button().pressed.emit()
	assert_str(str(builder.placement[0]["why"])).is_equal("assume")
	assert_int(builder.hints_used).is_equal(3)
	for press: int in 6:
		builder.hint_button().pressed.emit()
	builder.check_button().pressed.emit()
	assert_bool(builder.is_done()).is_true() # hints alone can finish it, and are counted
	assert_bool(builder.hints_used >= 9).is_true()


## Peer review 05: Why used to be wired like a second tap on the slot, which took the just-placed step back.
func test_why_keeps_the_step_and_opens_the_reason_chips() -> void:
	var builder: ProofBuilder = _builder()
	builder.tile_button(&"s1").pressed.emit()
	builder.why_button(0).pressed.emit()
	assert_str(str(builder.placement[0]["tile"])).is_equal("s1")
	assert_bool(builder.tile_button(&"s1").visible).is_false()
	assert_int(builder.selected).is_equal(0)
	builder.chip_button(&"assume").pressed.emit()
	assert_str(str(builder.placement[0]["why"])).is_equal("assume")
	builder.why_button(0).pressed.emit() # again: still there
	assert_str(str(builder.placement[0]["tile"])).is_equal("s1")
	builder.why_button(3).pressed.emit() # an empty slot's Why does nothing
	assert_int(builder.selected).is_equal(0)


## Peer review 05: a step sitting past an empty slot made every Hint press repeat itself and count. Now a hint clears
## the way (a wrong step goes back with its own words) and the ladder always reaches a complete proof.
func test_hints_recover_from_a_gap_and_a_wrong_step_without_looping() -> void:
	var builder: ProofBuilder = _builder()
	for id: StringName in [&"s1", &"s3", &"s2"]: # s3 before s2, which it needs
		builder.tile_button(id).pressed.emit()
	builder.hint_button().pressed.emit()
	assert_str(str(builder.placement[1]["tile"])).is_empty() # s3 went back
	assert_str(builder.feedback_text()).is_equal(Text.get_line(&"z12.builder.hint_back"))
	assert_str(str(builder.placement[2]["tile"])).is_equal("s2") # past the gap
	var presses: int = 1
	var seen: Array[String] = []
	while not builder.is_done() and presses < 40:
		builder.hint_button().pressed.emit()
		presses += 1
		var state: String = str(builder.placement) + str(builder.lit_tile())
		assert_bool(seen.has(state)).override_failure_message("press %d repeated board %s" % [presses, state]).is_false()
		seen.append(state)
		if builder._first_empty() < 0:
			builder.check_button().pressed.emit()
	assert_bool(builder.is_done()).is_true()
	assert_int(builder.hints_used).is_less_equal(presses)
	assert_int(builder.hints_used).is_greater_equal(3 * 7 - 3) # most steps needed light, place and reason


func test_a_hint_takes_a_decoy_back_with_its_own_words() -> void:
	var builder: ProofBuilder = _builder()
	builder.tile_button(&"d1").pressed.emit()
	builder.hint_button().pressed.emit()
	assert_str(str(builder.placement[0]["tile"])).is_empty()
	assert_bool(builder.tile_button(&"d1").visible).is_true()
	assert_str(builder.feedback_text()).is_equal(Text.get_line(&"z12.builder.hint_back"))
	assert_bool(builder.feedback_text().contains("next step")).is_false()
	assert_int(builder.hints_used).is_equal(1)


func test_every_builder_button_is_a_touch_target() -> void:
	var builder: ProofBuilder = _builder()
	var side: float = float(UI.min_target_px())
	for tile: StringName in [&"s1", &"s4", &"d2"]:
		assert_float(builder.tile_button(tile).custom_minimum_size.y).is_greater_equal(side)
	assert_float(builder.check_button().custom_minimum_size.y).is_greater_equal(side)
	assert_float(builder.hint_button().custom_minimum_size.y).is_greater_equal(side)
	assert_float(builder.chip_button(&"assume").custom_minimum_size.y).is_greater_equal(side)
