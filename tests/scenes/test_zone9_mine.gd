# Zone 9 in the real mine (Sprint 40, P4-S40-04): walls of Pattern Grotto rocks are cleared through the
# widgets their problems route to (pattern wall, proof board, number pad, decimal pad, answer buttons),
# a not-quite answer costs nothing, every word comes from the text table, and the mine plays the Zone 9
# loop once Zone 9 is the deepest zone on the frontier.
class_name Zone9MineTest
extends GdUnitTestSuite

const MINE_SCENE: String = "res://scenes/mine/mine.tscn"

var _mine: MineScreen
var _dir: String
var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("zone9_mine_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	get_tree().paused = false
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _make_mine(seed_value: int) -> MineScreen:
	var mine: MineScreen = load(MINE_SCENE).instantiate()
	mine.animation_speed = 25.0
	mine.seed_value = seed_value
	var only: Array[StringName] = []
	for skill: Skill in _catalog.skills_in_zone(9):
		only.append(skill.id)
	mine.skill_ids = only
	add_child(mine)
	auto_free(mine)
	_mine = mine
	return mine


func _until(condition: Callable, max_frames: int = 600) -> void:
	var frames: int = 0
	while not condition.call() and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	assert_bool(condition.call()).override_failure_message("timed out after %d frames (state %s)" % [frames, DigFlow.State.keys()[_mine.flow.state]]).is_true()


func _open(index: int) -> void:
	_mine.wall().rock(index).pressed.emit()
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.AWAIT_ANSWER)


func test_walls_of_zone_9_rocks_can_be_cleared() -> void:
	var seen: Dictionary = {}
	var kinds: Dictionary = {}
	for seed_value: int in [91, 92, 93, 94]:
		var mine: MineScreen = _make_mine(seed_value)
		for index: int in mine.wall().rock_count():
			await _open(index)
			var problem: Problem = mine.current_problem()
			seen[problem.skill_id] = true
			kinds[mine.answer_panel().input_kind] = true
			assert_bool(PanelDriver.give(mine.answer_panel(), problem.answer)).override_failure_message("%s: could not give %s" % [problem.skill_id, problem.answer]).is_true()
			await _until(func() -> bool: return mine.flow.is_cracked(index) and (mine.flow.state == DigFlow.State.PICK_ROCK or mine.flow.state == DigFlow.State.WALL_CLEAR))
		assert_int(mine.flow.state).is_equal(DigFlow.State.WALL_CLEAR)
		mine.queue_free()
	assert_int(seen.size()).is_greater(5)
	assert_int(kinds.size()).is_greater(1)


func test_a_not_quite_answer_costs_nothing_and_keeps_the_rock_open() -> void:
	var mine: MineScreen = _make_mine(95)
	await _open(0)
	var problem: Problem = mine.current_problem()
	var coins: int = Rewards.coins()
	var wrong: Variant = PanelDriver.wrong_value(problem)
	if PanelDriver.give(mine.answer_panel(), wrong):
		await _until(func() -> bool: return mine.flow.state == DigFlow.State.AWAIT_ANSWER and mine.flow.wrong_count() == 1)
		assert_int(Rewards.coins()).is_equal(coins)
		assert_bool(mine.flow.is_cracked(0)).is_false()
		assert_object(mine.current_problem()).is_same(problem)


func test_every_word_in_every_zone_9_prompt_hint_and_button_comes_from_the_text_table() -> void:
	for skill: Skill in _catalog.skills_in_zone(9):
		for representation: StringName in skill.representations:
			for seed_value: int in range(1, 16):
				var problem: Problem = GeneratorRegistry.make_problem(skill, seed_value, {"representation": representation})
				var asked: String = Text.get_line(problem.prompt_line_id, problem.prompt_params)
				assert_bool(asked.is_empty() or asked.begins_with("[") or asked.contains("{")).override_failure_message("%s: '%s'" % [skill.id, asked]).is_false()
				var example: Dictionary = problem.hint_steps[2]["example"]
				for text: String in [Text.get_line(example["prompt_line_id"], example["prompt_params"]), Text.get_line(example["answer_line_id"], example["answer_params"])]:
					assert_bool(text.is_empty() or text.begins_with("[") or text.contains("{") or text.contains("mantissa")).override_failure_message("%s: '%s'" % [skill.id, text]).is_false()
				for entry: Dictionary in problem.distractors:
					assert_bool(Text.has_line(StringName("bolt.misconception." + String(entry["misconception"])))).is_true()
					var label: String = AnswerPanel.label_for(entry["value"], problem)
					assert_bool(label.is_empty() or label.begins_with("[") or label.contains("_")).override_failure_message("%s: button '%s'" % [skill.id, label]).is_false()


func test_buttons_read_add_n_and_poem_lines_read_their_words() -> void:
	var rule: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"seq.arith.rule_describe"), 4)
	assert_str(AnswerPanel.label_for(rule.answer, rule)).is_equal(Text.get_line(&"z9.seq.rule_add", {"n": rule.answer}))
	var poem: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"fib.poem.syllables"), 4)
	var words: PackedStringArray = PackedStringArray()
	for word: Variant in poem.answer:
		words.append(Text.get_line(PoemWords.line_id(str(word))))
	assert_str(AnswerPanel.label_for(poem.answer, poem)).is_equal(" ".join(words))
	assert_int(AnswerPanel.choose_input(poem)).is_equal(AnswerPanel.InputKind.CHOICES)


func test_the_number_pad_takes_four_digits_for_gauss_sums() -> void:
	var panel: AnswerPanel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	panel.slate_override = false
	add_child(panel)
	auto_free(panel)
	var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"gauss.sum.formula"), 3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	panel.setup(problem, rng)
	assert_int(panel.number_pad().max_digits).is_equal(4)
	var pairing: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"gauss.sum.pairing"), 3)
	panel.setup(pairing, rng)
	assert_int(panel.number_pad().max_digits).is_equal(3)


func test_the_mine_plays_the_zone_9_loop_when_zone_9_is_the_deepest() -> void:
	for id: StringName in Adaptive.catalog().ids():
		var skill: Skill = Adaptive.catalog().skill(id)
		if skill.zone < 9:
			var record: Dictionary = SkillRecord.fresh(0.97)
			record["mastered_at"] = "2027-01-01T00:00:00Z"
			SaveSystem.data()["skills"][String(id)] = record
	var mine: MineScreen = _make_mine(96)
	assert_int(mine.deepest_zone()).is_equal(9)
	assert_str(String(mine.music_id())).is_equal("mine_z9")
	assert_str(mine.zone_banner().text()).is_equal(Text.get_line(&"z9.zone.name"))
