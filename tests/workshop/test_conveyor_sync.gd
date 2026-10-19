# Mirrors scenes/workshop/builds/conveyor_sync/ and its builds.json entry (P4-S30-04): the Zone 6
# engineering project opens once mul.common.first is learned, draws its belts from each problem, keeps
# Zone 6 out of the dig until it is built, resumes mid-build, and runs on the hub's shelf when done.
class_name ConveyorSyncTest
extends GdUnitTestSuite

const ZONE_6_FIRST: StringName = &"lcm.list.common_multiples"

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("conveyor_sync_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _master(skill_id: StringName) -> void:
	var record: Dictionary = SkillRecord.fresh(0.97)
	record["mastered_at"] = "2027-01-01T00:00:00Z"
	SaveSystem.data()["skills"][String(skill_id)] = record


func _master_through_zone(last_zone: int) -> void:
	for id: StringName in Adaptive.catalog().ids():
		if Adaptive.catalog().skill(id).zone <= last_zone:
			_master(id)


func _screen(path: String, args: Dictionary = {}, setup: Callable = Callable()) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	screen.setup(args)
	if setup.is_valid():
		setup.call(screen)
	add_child(screen)
	auto_free(screen)
	return screen


func _build() -> BuildScreen:
	return _screen("res://scenes/workshop/builds/build_screen.tscn", {"build_id": &"conveyor_sync"}, func(screen: BuildScreen) -> void:
		screen.seed_value = 99
		screen.slate_override = false)


func _solve(screen: BuildScreen) -> void:
	var step: BuildStep = screen.current_step()
	assert_bool(PanelDriver.give(step.card.answer_panel(), step.problem.answer)).is_true()


func test_the_build_opens_zone_6_after_the_first_shared_multiple() -> void:
	var build: BuildProject = Rewards.build(&"conveyor_sync")
	assert_object(build).is_not_null()
	assert_int(build.zone_unlocks).is_equal(6)
	assert_bool(build.locks_zone).is_true()
	assert_str(String(build.unlock_after_skill)).is_equal("mul.common.first")
	for step: Dictionary in build.steps:
		assert_str(String(step["skill_id"])).is_equal("mul.common.first")
	assert_bool(Rewards.is_build_open(&"conveyor_sync")).is_false()
	_master(&"mul.common.first")
	assert_bool(Rewards.is_build_open(&"conveyor_sync")).is_true()


func test_zone_6_stays_closed_until_the_belts_are_built_then_opens() -> void:
	_master_through_zone(5)
	assert_array(Adaptive.locked_zones()).contains([6])
	assert_bool(Adaptive.frontier().has(ZONE_6_FIRST)).is_false()
	var screen: BuildScreen = _build()
	assert_object(screen.current_step()).is_instanceof(ConveyorSyncStep)
	for step: int in 3:
		_solve(screen)
		if step < 2:
			screen.next_button().pressed.emit()
	assert_bool(Rewards.is_built(&"conveyor_sync")).is_true()
	assert_bool(screen.celebration.visible).is_true()
	assert_bool(Adaptive.locked_zones().has(6)).is_false()
	assert_bool(Adaptive.frontier().has(ZONE_6_FIRST)).is_true()


func test_a_child_with_zone_6_answers_never_loses_the_zone() -> void:
	_master_through_zone(5)
	var record: Dictionary = SkillRecord.fresh(0.3)
	record["attempts"] = 2
	SaveSystem.data()["skills"][String(ZONE_6_FIRST)] = record
	assert_bool(Adaptive.locked_zones().has(6)).is_false()


func test_the_belts_are_drawn_from_the_problem_and_sync_when_solved() -> void:
	_master(&"mul.common.first")
	var screen: BuildScreen = _build()
	var step: BuildStep = screen.current_step()
	assert_str(String(step.art.kind)).is_equal("conveyor_sync")
	assert_int(int(step.art.params["a"])).is_equal(int(step.problem.prompt_params["a"]))
	assert_int(int(step.art.params["b"])).is_equal(int(step.problem.prompt_params["b"]))
	assert_bool(step.art.params["synced"]).is_false()
	assert_int(step.problem.answer).is_equal(GearTrain.first_shared_drop(step.problem.prompt_params["a"], step.problem.prompt_params["b"]))
	_solve(screen)
	assert_bool(step.art.params["synced"]).is_true()


func test_resuming_mid_build_returns_to_the_same_step() -> void:
	_master(&"mul.common.first")
	var screen: BuildScreen = _build()
	_solve(screen)
	screen.free() # the app closes mid-build
	SaveSystem.load_profile()
	assert_dict(Rewards.build_state(&"conveyor_sync")).is_equal({"step": 1, "done": false})
	var resumed: BuildScreen = _build()
	assert_str((resumed.find_child("Progress", true, false) as Label).text).is_equal(Text.get_line(&"build.screen.progress", {"n": 2, "total": 3}))


func test_bolt_points_at_the_belts_when_they_keep_zone_6_closed() -> void:
	_master_through_zone(5)
	for i: int in 3:
		WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(&"balance_elevator"))
	var site: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(site.button_for(&"conveyor_sync").disabled).is_false()
	assert_str(site.bolt_node.spoken_text()).is_equal(Text.get_line(&"build.site.conveyor_hint", {"n": 6}))


func test_the_finished_machine_runs_on_the_hub_shelf() -> void:
	for i: int in 3:
		WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(&"conveyor_sync"))
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	var kinds: Array[StringName] = []
	for art: WorkshopArt in hub.shelf_items():
		kinds.append(art.kind)
	assert_array(kinds).contains([&"conveyor_sync"])
	assert_bool(hub.machines_running()).is_true()
