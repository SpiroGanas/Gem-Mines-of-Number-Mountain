# Phase 5's two engineering projects: the Clockwork Vault (Zone 10: three dials, each a mod.add.wrap problem on the
# clock lock) and the Vault Door (Zone 11: three codes cracked on the cipher wheel). Each opens once its skill is
# learned, every step is a concrete problem answered on the widget the plan describes, the build finishes and is saved,
# the finished machine runs on the hub shelf, and the museum shows the doors to the secret message and the lock door.
class_name Phase5BuildsTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("phase5_builds_" + str(Time.get_ticks_usec()))
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


func _build(build_id: StringName) -> BuildScreen:
	return _screen("res://scenes/workshop/builds/build_screen.tscn", {"build_id": build_id}, func(screen: BuildScreen) -> void:
		screen.seed_value = 77
		screen.slate_override = false)


func test_both_builds_are_valid_and_every_step_is_a_concrete_problem() -> void:
	assert_array(Array(BuildProject.validate(Rewards.builds(), Adaptive.catalog(), Text.has_line))).is_empty()
	for pair: Array in [[&"clockwork_vault", 11, &"mod.add.wrap"], [&"vault_door", 12, &"cipher.caesar.crack"]]:
		var build: BuildProject = Rewards.build(pair[0])
		assert_object(build).is_not_null()
		assert_int(build.zone_unlocks).is_equal(pair[1])
		assert_bool(build.locks_zone).is_false()
		assert_int(build.steps.size()).is_equal(3)
		for step: Dictionary in build.steps:
			assert_str(String(step["skill_id"])).is_equal(String(pair[2]))
			assert_str(str(step["params"].get("representation"))).is_equal("concrete")


func test_the_builds_open_when_their_skills_are_learned() -> void:
	var site: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(site.button_for(&"clockwork_vault").disabled).is_true()
	assert_bool(site.button_for(&"vault_door").disabled).is_true()
	_master(&"mod.add.wrap")
	_master(&"cipher.caesar.decode")
	var again: BuildSiteScreen = _screen("res://scenes/workshop/builds/build_site.tscn")
	assert_bool(again.button_for(&"clockwork_vault").disabled).is_false()
	assert_bool(again.button_for(&"vault_door").disabled).is_false()


func test_the_clockwork_vault_sets_three_dials_on_the_clock_lock() -> void:
	_master(&"mod.add.wrap")
	var screen: BuildScreen = _build(&"clockwork_vault")
	for step_index: int in 3:
		var step: BuildStep = screen.current_step()
		assert_object(step).is_instanceof(ClockworkVaultStep)
		var panel: AnswerPanel = step.card.answer_panel()
		assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.DIAL)
		assert_bool(step.art.params["open"]).is_false()
		assert_bool(PanelDriver.give(panel, step.problem.answer)).is_true()
		assert_bool(step.art.params["open"]).is_true()
		assert_int(int(step.art.params["x"])).is_equal(int(step.problem.answer))
		if step_index < 2:
			screen.next_button().pressed.emit()
	assert_bool(Rewards.is_built(&"clockwork_vault")).is_true()
	assert_bool(screen.celebration.visible).is_true()


func test_the_vault_door_opens_with_three_cracked_codes() -> void:
	_master(&"cipher.caesar.decode")
	var screen: BuildScreen = _build(&"vault_door")
	for step_index: int in 3:
		var step: BuildStep = screen.current_step()
		assert_object(step).is_instanceof(VaultDoorStep)
		var panel: AnswerPanel = step.card.answer_panel()
		assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.WHEEL)
		assert_bool(step.art.params["open"]).is_false()
		assert_str(step.art.params["word"]).is_equal("") # the word stays hidden until the code is cracked
		assert_bool(PanelDriver.give(panel, step.problem.answer)).is_true()
		assert_bool(step.art.params["open"]).is_true()
		assert_str(step.art.params["word"]).is_equal(step.problem.meta["word"])
		if step_index < 2:
			screen.next_button().pressed.emit()
	assert_bool(Rewards.is_built(&"vault_door")).is_true()


func test_a_wrong_dial_costs_nothing_and_the_step_stays() -> void:
	_master(&"mod.add.wrap")
	var screen: BuildScreen = _build(&"clockwork_vault")
	var step: BuildStep = screen.current_step()
	var panel: AnswerPanel = step.card.answer_panel()
	PanelDriver.give(panel, (int(step.problem.answer) + 1) % int(step.problem.prompt_params["n"]))
	assert_dict(Rewards.build_state(&"clockwork_vault")).is_equal({"step": 0, "done": false})
	assert_bool(screen.next_button().visible).is_false()


func test_the_finished_machines_run_on_the_hub_shelf() -> void:
	for build_id: StringName in [&"clockwork_vault", &"vault_door"]:
		for i: int in 3:
			WorkshopRules.finish_step(SaveSystem.data(), Rewards.build(build_id))
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	var kinds: Array[StringName] = []
	for art: WorkshopArt in hub.shelf_items():
		kinds.append(art.kind)
	assert_array(kinds).contains([&"clockwork_vault", &"vault_door"])
	assert_bool(hub.machines_running()).is_true()


func test_the_museum_shows_the_secret_codes_and_lock_door_once_learned() -> void:
	var museum: ShellScreen = _screen("res://scenes/workshop/museum.tscn")
	assert_bool(museum.find_child("CodesButton", true, false) == null).is_true()
	assert_bool(museum.find_child("LockButton", true, false) == null).is_true()
	_master(&"cipher.caesar.encode")
	_master(&"rsa.toy.keygen")
	var open: ShellScreen = _screen("res://scenes/workshop/museum.tscn")
	assert_bool(open.find_child("CodesButton", true, false) != null).is_true()
	assert_bool(open.find_child("LockButton", true, false) != null).is_true()
	var asked: Array[StringName] = []
	open.request_screen.connect(func(screen_id: StringName, _args: Dictionary) -> void: asked.append(screen_id))
	(open.find_child("CodesButton", true, false) as Button).pressed.emit()
	(open.find_child("LockButton", true, false) as Button).pressed.emit()
	assert_array(asked).contains_exactly([&"secret_message", &"rsa_door"])


func test_the_new_badges_come_with_their_skills() -> void:
	var wanted: Dictionary = {
		"noether": [["group.closure.verify", "group.inverse.find"], "table"],
		"ramanujan": [["fig.triangular.build", "group.cyclic.generate"], "cubes"],
		"fermat": [["rsa.toy.keygen", "modinv.find.small"], "lock"],
	}
	var found: Array[String] = []
	for entry: Dictionary in MotivationRules.load_badges():
		if not wanted.has(entry["id"]):
			continue
		found.append(entry["id"])
		assert_array(entry["unlock"]["skills_mastered"]).contains_exactly(wanted[entry["id"]][0])
		assert_str(entry["emblem"]).is_equal(wanted[entry["id"]][1])
		assert_int(entry["story"].size()).is_equal(5)
		for line: Dictionary in entry["story"]:
			var text: String = Text.get_line(StringName(str(line["line_id"])), line["params"])
			assert_bool(text.contains("{") or text.begins_with("[")).is_false()
		var art: BadgeArt = BadgeArt.new()
		art.emblem = StringName(entry["emblem"])
		art.size = Vector2(160, 160)
		add_child(art)
		auto_free(art)
		await await_idle_frame()
	assert_array(found).contains_exactly_in_any_order(["noether", "ramanujan", "fermat"])
