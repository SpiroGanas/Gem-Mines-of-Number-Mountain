# Mirrors autoload/rewards.gd: the rules applied to the save, the session tally and the signals.
class_name RewardsAutoloadTest
extends GdUnitTestSuite

var _dir: String
var _clock: FakeClock


func before_test() -> void:
	_dir = create_temp_dir("rewards_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_clock = FakeClock.new()
	Adaptive.use_clock(_clock)
	Adaptive.start_session()


func after_test() -> void:
	Adaptive.use_clock(GameClock.new())
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func test_paying_a_rock_updates_the_save_and_the_session_tally() -> void:
	Rewards.pay_rock(2, true)
	Rewards.pay_rock(2, false)
	assert_int(Rewards.coins()).is_equal(3)
	assert_int(Rewards.gem_count(&"garnet")).is_equal(2)
	assert_int(SaveSystem.data()["rewards"]["coins"]).is_equal(3)
	var summary: Dictionary = Rewards.session_summary()
	assert_int(summary["rocks"]).is_equal(2)
	assert_int(summary["coins"]).is_equal(3)
	assert_int(summary["gem_total"]).is_equal(2)
	assert_bool(Rewards.lit_today()).is_true()


func test_the_first_rock_of_a_day_lights_the_lantern() -> void:
	var lit: Array = []
	var on_lit: Callable = func(day: String, streak: int) -> void: lit.append([day, streak])
	Rewards.lantern_lit.connect(on_lit)
	Rewards.pay_rock(1, true)
	Rewards.pay_rock(1, true)
	_clock.advance_days(3)
	Rewards.pay_rock(1, true)
	Rewards.lantern_lit.disconnect(on_lit)
	assert_array(lit).contains_exactly([["2026-12-07", 1], ["2026-12-10", 2]])


func test_a_first_mastery_pays_an_amethyst_and_a_second_one_does_not() -> void:
	Adaptive.skill_mastered.emit(&"count.to_20.objects", true)
	assert_int(Rewards.gem_count(&"amethyst")).is_equal(1)
	Adaptive.skill_mastered.emit(&"count.to_20.objects", false) # won back after a lapse
	assert_int(Rewards.gem_count(&"amethyst")).is_equal(1)


func test_mastering_five_skills_finds_calcite_for_the_museum() -> void:
	var found: Array[StringName] = []
	var on_found: Callable = func(gem: StringName) -> void: found.append(gem)
	Rewards.mineral_found.connect(on_found)
	var skills: Dictionary = SaveSystem.data()["skills"]
	var ids: Array[StringName] = Adaptive.catalog().ids()
	for index: int in 5:
		var record: Dictionary = SkillRecord.ensure(skills, ids[index], 0.3)
		record["mastered_at"] = "2026-12-07T12:00:00Z"
	Adaptive.skill_mastered.emit(ids[4], true)
	Rewards.mineral_found.disconnect(on_found)
	assert_array(found).contains_exactly([&"calcite"])
	assert_bool(Rewards.museum_open(&"calcite")).is_true()
	assert_array(Rewards.session_summary()["minerals"]).contains_exactly([&"calcite"])


func test_purchases_persist_and_change_the_headlamp() -> void:
	SaveSystem.data()["rewards"]["coins"] = 60
	assert_bool(Rewards.buy(&"headlamp_green")).is_true()
	assert_str(Rewards.headlamp()).is_equal("green")
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_int(on_disk["rewards"]["coins"]).is_equal(40)
	assert_bool(on_disk["rewards"]["inventory"].has("headlamp_green")).is_true()
	assert_str(on_disk["rewards"]["bolt"]["headlamp"]).is_equal("green")
	assert_bool(Rewards.set_headlamp("blue")).is_true()
	assert_bool(Rewards.set_headlamp("gold")).is_false()


func test_a_new_session_clears_the_tally_but_never_the_totals() -> void:
	Rewards.pay_rock(1, true)
	_clock.advance(Adaptive.SESSION_GAP_SECONDS + 1)
	Adaptive.start_session()
	assert_int(Rewards.session_summary()["rocks"]).is_equal(0)
	assert_int(Rewards.coins()).is_equal(2)


func test_word_gems_of_an_older_save_are_collected_when_the_autoload_starts() -> void:
	# At app start SaveSystem loads the save before Rewards exists, so the profile_loaded it emits
	# then reaches nobody: Rewards must catch up in its own _ready (a save from before Sprint 19 has
	# mastered skills but no Word Gems; the v1 to v2 migration relies on this).
	var record: Dictionary = SkillRecord.fresh(0.97)
	record["mastered_at"] = "2026-12-01T00:00:00Z"
	SaveSystem.data()["skills"]["parity.even_odd.pairs"] = record
	SaveSystem.data()["motivation"]["word_gems"] = []
	assert_bool(Rewards.has_word_gem(&"even")).is_false()
	var fresh: Node = auto_free(load("res://autoload/rewards.gd").new())
	add_child(fresh) # its _ready runs with the save already loaded, exactly as at startup
	assert_bool(Rewards.has_word_gem(&"even")).is_true()
