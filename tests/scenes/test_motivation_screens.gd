# Mirrors the Sprint 19 screens: the badge case and the Word Gems glossary (from the museum), the
# Challenge Door, the Deep Dig in the mine and the parent's family rewards.
class_name MotivationScreensTest
extends GdUnitTestSuite

var _dir: String
var _clock: FakeClock


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("motivation_screens_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_clock = FakeClock.new()
	_clock.unix = Time.get_unix_time_from_datetime_string("2027-03-22T18:00:00")
	Adaptive.use_clock(_clock)


func after_test() -> void:
	get_tree().paused = false
	Adaptive.use_clock(GameClock.new())
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _screen(path: String, args: Dictionary = {}, setup: Callable = Callable()) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	screen.setup(args)
	if setup.is_valid():
		setup.call(screen)
	add_child(screen)
	auto_free(screen)
	return screen


func _master(skill_id: StringName) -> void:
	var record: Dictionary = SkillRecord.fresh(0.97)
	record["mastered_at"] = "2027-01-01T00:00:00Z"
	SaveSystem.data()["skills"][String(skill_id)] = record


func test_the_badge_case_opens_an_earned_badges_story_only() -> void:
	SaveSystem.data()["motivation"]["badges"] = ["gauss"]
	var case_screen: BadgeCaseScreen = _screen("res://scenes/workshop/museum/badge_case.tscn")
	assert_bool(case_screen.badge_button(&"euclid").disabled).is_true()
	case_screen.badge_button(&"gauss").pressed.emit()
	var story: PackedStringArray = case_screen.story_texts()
	assert_str(story[0]).is_equal(Text.get_line(&"badge.gauss.name"))
	assert_str(story[3]).is_equal(Text.get_line(&"badge.gauss.story_3", {"a": 1, "b": 100}))
	assert_int(story.size()).is_equal(7) # the name and six lines


func test_the_glossary_shows_found_word_gems_and_opens_their_card() -> void:
	SaveSystem.data()["motivation"]["word_gems"] = ["even", "odd"]
	var glossary: WordGemsScreen = _screen("res://scenes/workshop/museum/word_gems.tscn")
	assert_str(glossary.found_text()).is_equal(Text.get_line(&"glossary.screen.count", {"n": 2, "total": Text.term_ids().size()}))
	assert_bool(glossary.term_button(&"factor").disabled).is_true()
	glossary.term_button(&"even").pressed.emit()
	assert_bool(glossary.word_gem_card.visible).is_true()
	assert_that(glossary.word_gem_card.term_id).is_equal(&"even")


func test_the_museum_opens_the_badges_and_the_glossary() -> void:
	var museum: MuseumScreen = _screen("res://scenes/workshop/museum.tscn")
	monitor_signals(museum)
	(museum.find_child("BadgesButton", true, false) as Button).pressed.emit()
	await assert_signal(museum).is_emitted("request_screen", [&"badges", {}])


func _door(skill_id: StringName) -> ChallengeDoorScreen:
	return _screen("res://scenes/zones/common/challenge_door.tscn", {"skill_id": skill_id}, func(screen: ChallengeDoorScreen) -> void:
		screen.seed_value = 31
		screen.slate_override = false)


func test_three_right_at_the_door_masters_the_skill() -> void:
	var door: ChallengeDoorScreen = _door(&"add.to_20.sums")
	var guard: int = 0
	while not door.is_finished() and guard < 10:
		assert_bool(PanelDriver.give(door.card().answer_panel(), door.card().problem.answer)).is_true()
		guard += 1
	assert_int(guard).is_greater_equal(3)
	assert_bool(Adaptive.mastered().has(&"add.to_20.sums")).is_true()
	assert_str(SaveSystem.data()["skills"]["add.to_20.sums"]["mastery_evidence"]).is_equal("challenge")
	assert_bool(door.celebration.visible).is_true()


func test_a_miss_at_the_door_closes_it_and_is_not_a_wrong_answer() -> void:
	var door: ChallengeDoorScreen = _door(&"add.to_20.sums")
	var card: ProblemCard = door.card()
	assert_bool(PanelDriver.give(card.answer_panel(), PanelDriver.wrong_value(card.problem))).is_true()
	assert_bool(door.is_finished()).is_true()
	assert_bool(MotivationRules.door_closed(SaveSystem.data(), &"add.to_20.sums", _clock.today())).is_true()
	var record: Dictionary = SaveSystem.data()["skills"]["add.to_20.sums"]
	assert_int(int(record["attempts"])).is_equal(0) # BKT never heard of the answer
	assert_float(float(record["p_learned"])).is_equal(float(Adaptive.engine.params_for(&"add.to_20.sums")["prior"]))
	assert_array(SaveSystem.read_attempts()["entries"]).is_empty()
	assert_str(door.bolt_node.spoken_text()).is_equal(Text.get_line(&"door.screen.closed"))


func test_the_mine_offers_the_door_after_a_wall_for_a_practised_frontier_skill() -> void:
	var record: Dictionary = SkillRecord.fresh(0.6)
	record["attempts"] = 4
	SaveSystem.data()["skills"]["count.to_20.objects"] = record
	SaveSystem.data()["placement"]["done"] = true
	assert_that(Adaptive.challenge_candidate()).is_equal(&"count.to_20.objects")
	MotivationRules.close_door(SaveSystem.data(), &"count.to_20.objects", _clock.today())
	assert_that(Adaptive.challenge_candidate()).is_not_equal(&"count.to_20.objects")


func _play_deep_dig(mine: MineScreen) -> void:
	var guard: int = 0
	while guard < 40 and not (mine.flow.state == DigFlow.State.WALL_CLEAR and mine.deep_dig_left() == 0):
		guard += 1
		if mine.flow.state == DigFlow.State.WALL_CLEAR:
			(mine.find_child("DigMoreButton", true, false) as Button).pressed.emit()
			await get_tree().process_frame
			continue
		if mine.celebration().visible:
			mine.celebration().close()
		var index: int = -1
		for rock: int in mine.wall().rock_count():
			if not mine.flow.is_cracked(rock):
				index = rock
				break
		if mine.flow.state == DigFlow.State.PICK_ROCK and index >= 0:
			mine.wall().rock(index).pressed.emit()
		var frames: int = 0
		while mine.flow.state != DigFlow.State.AWAIT_ANSWER and mine.flow.state != DigFlow.State.WALL_CLEAR and frames < 300:
			await get_tree().process_frame
			frames += 1
		if mine.flow.state == DigFlow.State.AWAIT_ANSWER:
			await get_tree().process_frame
			PanelDriver.give(mine.answer_panel(), mine.current_problem().answer)
			frames = 0
			while mine.flow.state != DigFlow.State.PICK_ROCK and mine.flow.state != DigFlow.State.WALL_CLEAR and frames < 600:
				await get_tree().process_frame
				frames += 1


func test_the_deep_dig_is_ten_rocks_in_two_walls_and_pays_the_geode_once_a_week() -> void:
	for id: StringName in [&"add.to_10.sums", &"sub.to_10.diff", &"count.to_120.next", &"pv.tens_ones.read"]:
		_master(id)
	SaveSystem.data()["placement"]["done"] = true
	assert_bool(Rewards.deep_dig_available()).is_true()
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	assert_bool(hub.deep_dig_button().visible).is_true()
	var mine: MineScreen = _screen("res://scenes/mine/mine.tscn", {"deep_dig": true}, func(screen: MineScreen) -> void:
		screen.animation_speed = 25.0
		screen.seed_value = 4)
	assert_int(mine.deep_dig_left()).is_equal(MotivationRules.DEEP_DIG_PROBLEMS)
	assert_int(mine.wall().rock_count()).is_equal(MineScreen.DEEP_DIG_WALL)
	await _play_deep_dig(mine)
	assert_int(Rewards.gem_count(MotivationRules.DEEP_DIG_GEM)).is_equal(1)
	assert_bool(Rewards.deep_dig_available()).is_false()
	assert_bool((mine.find_child("DigMoreButton", true, false) as Button).visible).is_false()


func test_the_family_rewards_screen_adds_and_claims_goals() -> void:
	SaveSystem.data()["family"]["points"] = 60
	var screen: FamilyRewardsScreen = _screen("res://scenes/shell/parent_area/family_rewards.tscn")
	assert_bool(screen.add_goal("Pick dinner")).is_true()
	assert_int(Rewards.family_goals().size()).is_equal(1)
	assert_bool(screen.claim(0)).is_true()
	assert_int(Rewards.family_points()).is_equal(10)
	var claim: Button = screen.find_child("Goal0", true, false).find_child("ClaimButton", true, false)
	assert_bool(claim.disabled).is_true()
	assert_array(screen.find_children("*", "LineEdit", true, false)).has_size(1) # parent area only


func test_the_hub_shows_family_points_but_no_way_to_claim() -> void:
	SaveSystem.data()["family"]["points"] = 12
	var hub: HubScreen = _screen("res://scenes/shell/hub.tscn")
	var label: Label = hub.find_child("FamilyLabel", true, false)
	assert_str(label.text).is_equal(Text.get_line(&"family.hub.points", {"n": 12}))
	for node: Node in hub.find_children("*", "Button", true, false):
		assert_str((node as Button).text).is_not_equal(Text.get_line(&"family.screen.claim"))
