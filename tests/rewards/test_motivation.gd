# Mirrors the Sprint 19 half of scripts/core/motivation_rules.gd and autoload/rewards.gd: badges come
# from mastery only, Word Gems from mastered skills, family points from mastery and finished
# sessions (never speed), and a parent claims goals.
class_name MotivationTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("motivation_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func test_the_four_badges_are_sound() -> void:
	var badges: Array[Dictionary] = MotivationRules.load_badges()
	var ids: Array[String] = []
	for badge: Dictionary in badges:
		ids.append(str(badge["id"]))
		assert_bool(Text.has_line(StringName(str(badge["name_line_id"])))).is_true()
		var story: Array = badge["story"]
		assert_int(story.size()).override_failure_message(str(badge["id"])).is_between(4, 6)
		for entry: Dictionary in story:
			assert_bool(Text.has_line(StringName(str(entry["line_id"])))).is_true()
			assert_bool(Text.get_line(StringName(str(entry["line_id"])), entry["params"]).contains("{")).is_false()
		var needs: Array = badge["unlock"]["skills_mastered"]
		assert_array(needs).is_not_empty()
		for skill: Variant in needs:
			assert_bool(Adaptive.catalog().has_skill(StringName(str(skill)))).override_failure_message("%s needs unknown %s" % [badge["id"], skill]).is_true()
	assert_array(ids).contains_exactly(["gauss", "euclid", "eratosthenes", "sophie_germain", "gauss_staircase"]) # Gauss's staircases joined in Zone 9 (Phase 4, Sprint 40)


func test_euclid_tells_his_gcf_story_once_the_gcf_is_mastered() -> void:
	var euclid: Dictionary = {}
	for badge: Dictionary in MotivationRules.load_badges():
		if badge["id"] == "euclid":
			euclid = badge
	var plain: Array[Dictionary] = MotivationRules.story_for(euclid, [&"fac.list.find_all", &"prime.classify.single"])
	assert_int(plain.size()).is_equal(euclid["story"].size())
	var longer: Array[Dictionary] = MotivationRules.story_for(euclid, [&"fac.list.find_all", &"prime.classify.single", &"gcf.find.by_listing"])
	assert_int(longer.size()).is_equal(euclid["story"].size() + 3)
	for entry: Dictionary in longer:
		assert_bool(Text.has_line(StringName(str(entry["line_id"])))).is_true()
	assert_str(String(longer.back()["line_id"])).is_equal("badge.euclid.story_gcf_3")
	for skill: Variant in euclid["story_more"]["skills_mastered"]:
		assert_bool(Adaptive.catalog().has_skill(StringName(str(skill)))).is_true()


func test_a_badge_comes_only_when_every_listed_skill_is_mastered() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	var badges: Array[Dictionary] = [{"id": "test", "unlock": {"skills_mastered": ["a.b.c", "d.e.f"]}}, {"id": "free", "unlock": {}}]
	assert_array(MotivationRules.earn_badges(save, badges, [&"a.b.c"])).is_empty()
	assert_array(MotivationRules.earn_badges(save, badges, [&"a.b.c", &"d.e.f"])).contains_exactly([&"test"])
	assert_array(MotivationRules.earn_badges(save, badges, [&"a.b.c", &"d.e.f"])).is_empty() # once
	assert_bool(MotivationRules.has_badge(save, &"free")).is_false() # never given without mastery


func _master(skill_id: StringName) -> void:
	var engine: AdaptiveEngine = Adaptive.engine
	engine.master_by_challenge(skill_id) # emits skill_mastered through the autoload


func test_mastery_collects_word_gems_and_family_points_and_the_gauss_badge() -> void:
	_master(&"add.to_100.regroup")
	assert_bool(Rewards.has_badge(&"gauss")).is_false()
	for term: StringName in Adaptive.catalog().skill(&"add.to_100.regroup").terms:
		assert_bool(Rewards.has_word_gem(term)).is_true()
	assert_int(Rewards.family_points()).is_equal(MotivationRules.POINTS_FOR_MASTERY)
	_master(&"add.three_addends.to_20")
	assert_bool(Rewards.has_badge(&"gauss")).is_true()
	assert_int(Rewards.family_points()).is_equal(2 * MotivationRules.POINTS_FOR_MASTERY)


func test_word_gems_of_an_older_save_are_collected_on_load() -> void:
	var record: Dictionary = SkillRecord.fresh(0.97)
	record["mastered_at"] = "2026-12-01T00:00:00Z"
	SaveSystem.data()["skills"]["parity.even_odd.pairs"] = record
	SaveSystem.save_now()
	SaveSystem.load_profile()
	assert_bool(Rewards.has_word_gem(&"even")).is_true()


func test_session_points_are_paid_once_and_never_depend_on_speed() -> void:
	Rewards.session_completed("s100")
	Rewards.session_completed("s100")
	assert_int(Rewards.family_points()).is_equal(MotivationRules.POINTS_FOR_SESSION)
	Rewards.session_completed("")
	assert_int(Rewards.family_points()).is_equal(MotivationRules.POINTS_FOR_SESSION)
	var source: String = FileAccess.get_file_as_string("res://scripts/core/motivation_rules.gd")
	assert_bool(source.contains("latency")).override_failure_message("points must never read answer speed").is_false()


func test_a_parent_claims_a_goal_with_enough_points() -> void:
	SaveSystem.data()["family"]["points"] = 30
	assert_bool(Rewards.add_family_goal("  Park on Saturday ", 25)).is_true()
	assert_bool(Rewards.add_family_goal("", 10)).is_false()
	assert_bool(Rewards.add_family_goal("Nothing", 0)).is_false()
	assert_str(Rewards.family_goals()[0]["text"]).is_equal("Park on Saturday")
	assert_bool(Rewards.claim_family_goal(0)).is_true()
	assert_int(Rewards.family_points()).is_equal(5)
	assert_bool(Rewards.claim_family_goal(0)).is_false() # claimed already
	Rewards.add_family_goal("Big trip", 50)
	assert_bool(Rewards.claim_family_goal(1)).is_false() # not enough
	assert_int(Rewards.family_points()).is_equal(5)
