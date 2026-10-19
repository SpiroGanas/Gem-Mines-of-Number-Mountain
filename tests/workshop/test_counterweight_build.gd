# Zone 8's engineering project, the Counterweight Elevator (Sprint 36, P4-S36-03): it opens once the child
# knows the powers of 2, every step is a concrete lever.counterweight.balance problem answered on the
# counterweight lever, the build finishes and is saved, and the finished elevator runs on the hub shelf.
class_name CounterweightBuildTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("counterweight_build_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _master(skill_id: StringName) -> void:
	var record: Dictionary = SkillRecord.fresh(0.97)
	record["mastered_at"] = "2027-01-01T00:00:00Z"
	SaveSystem.data()["skills"][String(skill_id)] = record


func _screen(path: String, args: Dictionary = {}, setup: Callable = Callable()) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	screen.setup(args)
	if setup.is_valid():
		setup.call(screen)
	add_child(screen)
	auto_free(screen)
	return screen


func _build() -> BuildScreen:
	return _screen("res://scenes/workshop/builds/build_screen.tscn", {"build_id": &"counterweight_elevator"}, func(screen: BuildScreen) -> void:
		screen.seed_value = 77
		screen.slate_override = false)


func test_the_build_is_valid_and_belongs_to_zone_8() -> void:
	var build: BuildProject = Rewards.build(&"counterweight_elevator")
	assert_object(build).is_not_null()
	assert_int(build.zone_unlocks).is_equal(8)
	assert_bool(build.locks_zone).is_false() # Zone 8 is opened by its prerequisites, not by a build
	assert_array(Array(BuildProject.validate(Rewards.builds(), Adaptive.catalog(), Text.has_line))).is_empty()
	for step: Dictionary in build.steps:
		assert_str(String(step["skill_id"])).is_equal("lever.counterweight.balance")
		assert_str(str(step["params"].get("representation"))).is_equal("concrete")


func test_it_opens_after_the_powers_of_two() -> void:
	var site: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(site.button_for(&"counterweight_elevator").disabled).is_true()
	_master(&"exp.powers_of_two.list")
	var again: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(again.button_for(&"counterweight_elevator").disabled).is_false()


func test_each_step_is_balanced_on_the_lever_and_the_build_finishes() -> void:
	_master(&"exp.powers_of_two.list")
	var screen: BuildScreen = _build()
	for step_index: int in 3:
		var step: BuildStep = screen.current_step()
		assert_object(step).is_instanceof(CounterweightElevatorStep)
		var panel: AnswerPanel = step.card.answer_panel()
		assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.LEVER)
		assert_bool(step.art.params["balanced"]).is_false()
		var p: Dictionary = step.problem.prompt_params
		assert_str(Lever.side_heavier(p["w"], p["d"], step.problem.answer, p["r"])).is_equal("level")
		panel.counterweight().speed_scale = 0.0
		assert_bool(PanelDriver.give(panel, step.problem.answer)).is_true()
		assert_bool(step.art.params["balanced"]).is_true()
		assert_int(int(step.art.params["x"])).is_equal(int(step.problem.answer))
		if step_index < 2:
			screen.next_button().pressed.emit()
	assert_bool(Rewards.is_built(&"counterweight_elevator")).is_true()
	assert_bool(screen.celebration.visible).is_true()


func test_a_wrong_weight_costs_nothing_and_the_step_stays() -> void:
	_master(&"exp.powers_of_two.list")
	var screen: BuildScreen = _build()
	var step: BuildStep = screen.current_step()
	var panel: AnswerPanel = step.card.answer_panel()
	panel.counterweight().speed_scale = 0.0
	PanelDriver.give(panel, int(step.problem.answer) + 1)
	assert_dict(Rewards.build_state(&"counterweight_elevator")).is_equal({"step": 0, "done": false})
	assert_bool(screen.next_button().visible).is_false()


func test_the_finished_elevator_runs_on_the_hub_shelf() -> void:
	for i: int in 3:
		WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(&"counterweight_elevator"))
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	var kinds: Array[StringName] = []
	for art: WorkshopArt in hub.shelf_items():
		kinds.append(art.kind)
	assert_array(kinds).contains([&"counterweight_elevator"])
	assert_bool(hub.machines_running()).is_true()
