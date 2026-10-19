# Zone 6 through the real dig loop (P4-S30-03): once Zones 1-5 are learned and Conveyor Sync is built,
# the mine is in Gear Works (its banner, tint and music), a gear rock opens on the gear bench, and a
# right gear cracks the rock and is saved like every other rock.
class_name Zone6MineTest
extends GdUnitTestSuite

const MINE_SCENE: String = "res://scenes/mine/mine.tscn"

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("zone6_mine_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	get_tree().paused = false
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _learn_zones_1_to_5_and_build_the_belts() -> void:
	for id: StringName in Adaptive.catalog().ids():
		if Adaptive.catalog().skill(id).zone <= 5:
			var record: Dictionary = SkillRecord.fresh(0.97)
			record["mastered_at"] = "2027-01-01T00:00:00Z"
			SaveSystem.data()["skills"][String(id)] = record
	for build_id: StringName in [&"balance_elevator", &"conveyor_sync"]:
		for step: int in 3:
			WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(build_id))


func _make_mine(skill_ids: Array[StringName]) -> MineScreen:
	var mine: MineScreen = load(MINE_SCENE).instantiate()
	mine.animation_speed = 25.0
	mine.seed_value = 606
	mine.skill_ids = skill_ids
	add_child(mine)
	auto_free(mine)
	return mine


func _until(mine: MineScreen, condition: Callable, max_frames: int = 600) -> void:
	var frames: int = 0
	while not condition.call() and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	assert_bool(condition.call()).override_failure_message("timed out (state %s)" % DigFlow.State.keys()[mine.flow.state]).is_true()


func test_the_mine_is_in_gear_works_once_zone_6_opens() -> void:
	_learn_zones_1_to_5_and_build_the_belts()
	var mine: MineScreen = _make_mine([&"gcf.find.by_listing"])
	await await_idle_frame()
	assert_int(mine.deepest_zone()).is_equal(6)
	assert_str(String(mine.music_id())).is_equal("mine_z6")
	assert_str(mine.zone_banner().text()).is_equal(Text.get_line(&"z6.zone.name"))


func test_a_gear_rock_opens_on_the_gear_bench_and_a_right_gear_cracks_it() -> void:
	_learn_zones_1_to_5_and_build_the_belts()
	var mine: MineScreen = _make_mine([&"gear.ratio.teeth"])
	await await_idle_frame()
	mine.wall().rock(0).pressed.emit()
	await _until(mine, func() -> bool: return mine.flow.state == DigFlow.State.AWAIT_ANSWER)
	var problem: Problem = mine.current_problem()
	assert_str(String(problem.skill_id)).is_equal("gear.ratio.teeth")
	assert_str(String(problem.representation)).is_equal("concrete") # a new learner starts concrete
	assert_int(mine.answer_panel().input_kind).is_equal(AnswerPanel.InputKind.GEAR)
	assert_bool(PanelDriver.give(mine.answer_panel(), problem.answer)).is_true()
	await _until(mine, func() -> bool: return mine.flow.state == DigFlow.State.PICK_ROCK or mine.flow.state == DigFlow.State.WALL_CLEAR)
	var record: Dictionary = SaveSystem.data()["skills"].get("gear.ratio.teeth", {})
	assert_int(int(record.get("attempts", 0))).is_equal(1)
	var on_disk: Dictionary = JsonUtil.parse_file(_dir.path_join("profile.json"))
	assert_bool(on_disk["skills"].has("gear.ratio.teeth")).is_true() # saved after the rock
