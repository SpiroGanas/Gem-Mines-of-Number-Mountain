# Zone 7's engineering project, the Alloy Mixer (Sprint 33): it opens once the child can describe a
# ratio, every step is a concrete ratio.scale.alloy problem answered on the alloy mixer, the build
# finishes and is saved, and the finished machine runs on the hub's shelf.
class_name AlloyMixerBuildTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("alloy_build_" + str(Time.get_ticks_usec()))
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
	return _screen("res://scenes/workshop/builds/build_screen.tscn", {"build_id": &"alloy_mixer"}, func(screen: BuildScreen) -> void:
		screen.seed_value = 77
		screen.slate_override = false)


func test_the_build_is_valid_and_belongs_to_zone_7() -> void:
	var build: BuildProject = Rewards.build(&"alloy_mixer")
	assert_object(build).is_not_null()
	assert_int(build.zone_unlocks).is_equal(7)
	assert_bool(build.locks_zone).is_false() # Zone 7 is opened by its prerequisites, not by a build
	assert_array(Array(BuildProject.validate(Rewards.builds(), Adaptive.catalog(), Text.has_line))).is_empty()
	for step: Dictionary in build.steps:
		assert_str(String(step["skill_id"])).is_equal("ratio.scale.alloy")
		assert_str(str(step["params"].get("representation"))).is_equal("concrete")


func test_it_opens_after_the_child_can_describe_a_ratio() -> void:
	var site: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(site.button_for(&"alloy_mixer").disabled).is_true()
	_master(&"ratio.describe.part_part")
	var again: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(again.button_for(&"alloy_mixer").disabled).is_false()


func test_each_step_is_mixed_on_the_alloy_mixer_and_the_build_finishes() -> void:
	_master(&"ratio.describe.part_part")
	var screen: BuildScreen = _build()
	for step_index: int in 3:
		var step: BuildStep = screen.current_step()
		assert_object(step).is_instanceof(AlloyMixerStep)
		var panel: AnswerPanel = step.card.answer_panel()
		assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.ALLOY)
		assert_bool(step.art.params["mixed"]).is_false()
		var p: Dictionary = step.problem.prompt_params
		assert_bool(Alloy.is_right_mix(p["a"], p["b"], p["c"], step.problem.answer)).is_true()
		panel.alloy_mixer().speed_scale = 0.0
		assert_bool(PanelDriver.give(panel, step.problem.answer)).is_true()
		assert_bool(step.art.params["mixed"]).is_true()
		assert_int(int(step.art.params["tin"])).is_equal(int(step.problem.answer))
		if step_index < 2:
			screen.next_button().pressed.emit()
	assert_bool(Rewards.is_built(&"alloy_mixer")).is_true()
	assert_bool(screen.celebration.visible).is_true()


func test_a_wrong_mix_costs_nothing_and_the_step_stays() -> void:
	_master(&"ratio.describe.part_part")
	var screen: BuildScreen = _build()
	var step: BuildStep = screen.current_step()
	var panel: AnswerPanel = step.card.answer_panel()
	panel.alloy_mixer().speed_scale = 0.0
	PanelDriver.give(panel, int(step.problem.answer) + 1)
	assert_dict(Rewards.build_state(&"alloy_mixer")).is_equal({"step": 0, "done": false})
	assert_bool(screen.next_button().visible).is_false()


func test_the_finished_mixer_runs_on_the_hub_shelf() -> void:
	for i: int in 3:
		WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(&"alloy_mixer"))
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	var kinds: Array[StringName] = []
	for art: WorkshopArt in hub.shelf_items():
		kinds.append(art.kind)
	assert_array(kinds).contains([&"alloy_mixer"])
	assert_bool(hub.machines_running()).is_true()
