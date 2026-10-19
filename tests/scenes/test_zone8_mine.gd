# Zone 8 in the real mine (Sprint 36, P4-S36-04): walls of Power Tower rocks are cleared through the
# widgets their problems route to (vault lock, tower elevator, counterweight, the pads, answer buttons),
# a not-quite answer costs nothing, and every word comes from the text table.
class_name Zone8MineTest
extends GdUnitTestSuite

const MINE_SCENE: String = "res://scenes/mine/mine.tscn"

var _mine: MineScreen
var _dir: String
var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("zone8_mine_" + str(Time.get_ticks_usec()))
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
	for skill: Skill in _catalog.skills_in_zone(8):
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


func _give(target: Variant) -> void:
	var panel: AnswerPanel = _mine.answer_panel()
	for widget: Variant in [panel.vault_lock(), panel.tower_elevator(), panel.counterweight()]:
		if widget != null:
			widget.speed_scale = 0.0
	var problem: Problem = _mine.current_problem()
	assert_bool(PanelDriver.give(panel, target)).override_failure_message("%s: could not give %s" % [problem.skill_id, target]).is_true()


func test_walls_of_zone_8_rocks_can_be_cleared() -> void:
	var seen: Dictionary = {}
	for seed_value: int in [81, 82, 83, 84]:
		var mine: MineScreen = _make_mine(seed_value)
		for index: int in mine.wall().rock_count():
			await _open(index)
			seen[mine.current_problem().skill_id] = true
			_give(mine.current_problem().answer)
			await _until(func() -> bool: return mine.flow.is_cracked(index) and (mine.flow.state == DigFlow.State.PICK_ROCK or mine.flow.state == DigFlow.State.WALL_CLEAR))
		assert_int(mine.flow.state).is_equal(DigFlow.State.WALL_CLEAR)
		mine.queue_free()
	assert_int(seen.size()).is_greater(5)


func test_a_not_quite_answer_costs_nothing_and_keeps_the_rock_open() -> void:
	var mine: MineScreen = _make_mine(81)
	await _open(0)
	var problem: Problem = mine.current_problem()
	var coins: int = Rewards.coins()
	var wrong: Variant = PanelDriver.wrong_value(problem)
	if PanelDriver.give(mine.answer_panel(), wrong):
		await _until(func() -> bool: return mine.flow.state == DigFlow.State.AWAIT_ANSWER and mine.flow.wrong_count() == 1)
		assert_int(Rewards.coins()).is_equal(coins)
		assert_bool(mine.flow.is_cracked(0)).is_false()
		assert_object(mine.current_problem()).is_same(problem)


func test_every_word_in_every_zone_8_prompt_and_hint_comes_from_the_text_table() -> void:
	for skill: Skill in _catalog.skills_in_zone(8):
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


func test_the_mine_plays_the_zone_8_loop_when_zone_8_is_the_deepest() -> void:
	for id: StringName in Adaptive.catalog().ids():
		var skill: Skill = Adaptive.catalog().skill(id)
		if skill.zone < 8:
			var record: Dictionary = SkillRecord.fresh(0.97)
			record["mastered_at"] = "2027-01-01T00:00:00Z"
			SaveSystem.data()["skills"][String(id)] = record
	var mine: MineScreen = _make_mine(91)
	assert_int(mine.deepest_zone()).is_equal(8)
	assert_str(String(mine.music_id())).is_equal("mine_z8")
