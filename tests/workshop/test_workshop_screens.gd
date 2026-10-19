# Mirrors scenes/workshop/crafting/ and scenes/workshop/builds/ (Sprint 16, P2-S16-02 to 05): crafting
# works end to end and a wrong answer keeps the gems; a build resumes at its step after the app closes;
# the elevator opens Zone 4; the hub has the two new doors and runs finished machines.
class_name WorkshopScreensTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("workshop_screens_" + str(Time.get_ticks_usec()))
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


func _crafting() -> CraftingScreen:
	return _screen("res://scenes/workshop/crafting/crafting.tscn", {}, func(screen: CraftingScreen) -> void: screen.seed_value = 4242)


func test_crafting_the_big_pickaxe_from_twelve_garnets_works_end_to_end() -> void:
	_master(&"mult.equal_groups.total")
	SaveSystem.data()["rewards"]["gems"]["garnet"] = 12
	var bench: CraftingScreen = _crafting()
	var button: Button = bench.craft_button(&"tool.pickaxe.tier2")
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_false()
	button.pressed.emit()
	assert_that(bench.crafting()).is_equal(&"tool.pickaxe.tier2")
	var card: ProblemCard = bench.card()
	assert_that(card.problem.skill_id).is_equal(&"mult.equal_groups.total")
	assert_bool(PanelDriver.give(card.answer_panel(), card.problem.answer)).is_true()
	assert_int(Rewards.gem_count(GemArt.GARNET)).is_equal(0)
	assert_bool(Rewards.owns(&"pickaxe_t2")).is_true()
	assert_that(Rewards.pickaxe()).is_equal(&"pickaxe_t2")
	assert_bool(bench.celebration.visible).is_true()
	var on_disk: Dictionary = JsonUtil.parse_file(SaveSystem.profile_dir().path_join("profile.json"))
	assert_array(on_disk["workshop"]["crafted"]).contains(["tool.pickaxe.tier2"]) # saved at once


func test_a_wrong_answer_keeps_the_gems_and_gives_a_hint() -> void:
	_master(&"mult.equal_groups.total")
	SaveSystem.data()["rewards"]["gems"]["garnet"] = 12
	var bench: CraftingScreen = _crafting()
	bench.craft_button(&"tool.pickaxe.tier2").pressed.emit()
	var card: ProblemCard = bench.card()
	for miss: int in 3:
		assert_bool(PanelDriver.give(card.answer_panel(), PanelDriver.wrong_value(card.problem))).is_true()
	assert_int(card.misses()).is_equal(3)
	assert_int(Rewards.gem_count(GemArt.GARNET)).is_equal(12)
	assert_bool(Rewards.owns(&"pickaxe_t2")).is_false()
	assert_str(bench.bolt_node.note_text()).contains(Text.get_line(&"bolt.feedback.not_quite"))
	assert_object(card.answer_panel().example_card()).is_not_null() # rung 3, the worked example
	var record: Dictionary = SaveSystem.data()["skills"]["mult.equal_groups.total"]
	assert_int(int(record["attempts"])).is_greater_equal(1) # the answer counted as evidence


func test_a_recipe_needs_its_skill_and_its_gems() -> void:
	SaveSystem.data()["rewards"]["gems"]["garnet"] = 12
	var bench: CraftingScreen = _crafting()
	assert_object(bench.craft_button(&"tool.pickaxe.tier2")).is_null() # its skill is not open yet
	bench.queue_free()
	_master(&"mult.equal_groups.total")
	SaveSystem.data()["rewards"]["gems"]["garnet"] = 11
	var again: CraftingScreen = _crafting()
	assert_bool(again.craft_button(&"tool.pickaxe.tier2").disabled).is_true()
	assert_str(again.craft_button(&"tool.pickaxe.tier2").text).is_equal(Text.get_line(&"ws.recipe.need_gems"))


func _build(build_id: StringName) -> BuildScreen:
	return _screen("res://scenes/workshop/builds/build_screen.tscn", {"build_id": build_id}, func(screen: BuildScreen) -> void:
		screen.seed_value = 99
		screen.slate_override = false)


func _solve(screen: BuildScreen) -> void:
	var step: BuildStep = screen.current_step()
	assert_bool(PanelDriver.give(step.card.answer_panel(), step.problem.answer)).is_true()


func test_resuming_mid_build_after_the_app_closes_returns_to_the_same_step() -> void:
	_master(&"mult.equal_groups.total")
	var screen: BuildScreen = _build(&"balance_elevator")
	assert_object(screen.current_step()).is_instanceof(BalanceElevatorStep)
	_solve(screen)
	assert_bool(screen.next_button().visible).is_true()
	screen.next_button().pressed.emit()
	_solve(screen)
	screen.free() # the app closes mid-build
	SaveSystem.load_profile() # and opens again
	assert_dict(Rewards.build_state(&"balance_elevator")).is_equal({"step": 2, "done": false})
	var resumed: BuildScreen = _build(&"balance_elevator")
	assert_str((resumed.find_child("Progress", true, false) as Label).text).is_equal(Text.get_line(&"build.screen.progress", {"n": 3, "total": 3}))


func test_finishing_the_elevator_opens_zone_4() -> void:
	for id: StringName in Adaptive.catalog().ids():
		if Adaptive.catalog().skill(id).zone <= 3:
			_master(id)
	var zone_4_first: StringName = &"mult.facts.0_5"
	assert_array(Adaptive.locked_zones()).contains([4])
	assert_bool(Adaptive.frontier().has(zone_4_first)).is_false()
	var screen: BuildScreen = _build(&"balance_elevator")
	for step: int in 3:
		_solve(screen)
		if step < 2:
			screen.next_button().pressed.emit()
	assert_bool(Rewards.is_built(&"balance_elevator")).is_true()
	assert_bool(screen.celebration.visible).is_true()
	assert_array(Adaptive.locked_zones()).is_empty()
	assert_bool(Adaptive.frontier().has(zone_4_first)).is_true()


func test_the_cart_track_draws_its_gap_from_the_problem() -> void:
	_master(&"add.to_10.sums")
	var screen: BuildScreen = _build(&"cart_track")
	var step: BuildStep = screen.current_step()
	assert_object(step).is_instanceof(CartTrackStep)
	assert_int(int(step.art.params["c"])).is_equal(int(step.problem.prompt_params["c"]))
	assert_bool(step.art.params["filled"]).is_false()
	_solve(screen)
	assert_bool(step.art.params["filled"]).is_true()


func test_the_build_site_offers_open_builds_only() -> void:
	_master(&"add.to_10.sums")
	var site: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(site.button_for(&"cart_track").disabled).is_false()
	assert_bool(site.button_for(&"balance_elevator").disabled).is_true()


func test_the_hub_has_the_two_doors_and_runs_finished_machines() -> void:
	for i: int in 3:
		WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(&"cart_track"))
	SaveSystem.data()["rewards"]["inventory"].append("hub_lanterns")
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	assert_str(hub.workshop_button().text).is_equal(Text.get_line(&"ui.hub.workshop"))
	assert_str(hub.build_button().text).is_equal(Text.get_line(&"ui.hub.build_site"))
	var kinds: Array[StringName] = []
	for art: WorkshopArt in hub.shelf_items():
		kinds.append(art.kind)
	assert_array(kinds).contains_exactly_in_any_order([&"cart_track", &"hub_lanterns"])
	assert_bool(hub.machines_running()).is_true()
	hub.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_bool(hub.machines_running()).is_false()


func test_an_empty_shelf_runs_nothing() -> void:
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	assert_array(hub.shelf_items()).is_empty()
	assert_bool(hub.machines_running()).is_false()
