# Mirrors the rare-gem rules of scripts/core/rewards_rules.gd (Sprint 15): rare gems come from rare
# NUMBERS, never from chance (CLAUDE.md rule 9). Every number from 1 to 10,000 is compared with the
# independent Python list tools/crosscheck/rare_numbers.py writes into fixtures/rare_gems.json.
class_name RareGemsTest
extends GdUnitTestSuite

const FIXTURE: String = "res://tests/rewards/fixtures/rare_gems.json"
const COMMON: StringName = &"common"


func test_every_number_to_10000_matches_the_independent_python_list() -> void:
	var doc: Dictionary = JsonUtil.parse_file(FIXTURE)
	assert_int(doc["limit"]).is_equal(10000)
	var gems: Array = doc["gems"]
	assert_int(gems.size()).is_equal(10000)
	var wrong: Array[String] = []
	for n: int in range(1, 10001):
		var expected: String = gems[n - 1] if gems[n - 1] != "" else String(COMMON)
		var got: String = String(RewardsRules.gem_for_value(n, COMMON))
		if got != expected:
			wrong.append("%d: %s (expected %s)" % [n, got, expected])
	assert_array(wrong).override_failure_message("\n".join(wrong.slice(0, 20))).is_empty()


func test_the_mersenne_list_is_the_one_in_the_curriculum_file() -> void:
	assert_array(RewardsRules.mersenne_primes()).is_equal([3, 7, 31, 127, 8191])


func test_known_numbers() -> void:
	assert_str(RewardsRules.gem_for_value(7)).is_equal("mersenne_gem")
	assert_str(RewardsRules.gem_for_value(3)).is_equal("mersenne_gem") # also a twin prime: the rarer gem wins
	assert_str(RewardsRules.gem_for_value(5)).is_equal("twin_gem")
	assert_str(RewardsRules.gem_for_value(11)).is_equal("twin_gem")
	assert_str(RewardsRules.gem_for_value(23)).is_equal("prime_gem")
	assert_str(RewardsRules.gem_for_value(2)).is_equal("prime_gem")
	assert_str(RewardsRules.gem_for_value(36)).is_equal("square_gem")
	assert_str(RewardsRules.gem_for_value(1)).is_equal("square_gem") # one is a perfect square, not a prime
	assert_str(RewardsRules.gem_for_value(12, GemArt.PYRITE)).is_equal("pyrite")


func test_a_number_that_is_not_positive_pays_the_common_gem() -> void:
	for n: int in [0, -1, -7]:
		assert_str(RewardsRules.gem_for_value(n, GemArt.GARNET)).is_equal("garnet")


func test_the_same_number_always_gives_the_same_gem() -> void:
	for n: int in [2, 5, 7, 12, 29, 36, 8191]:
		var first: StringName = RewardsRules.gem_for_value(n)
		for i: int in 50:
			assert_str(RewardsRules.gem_for_value(n)).is_equal(first)


func test_the_rule_code_never_calls_a_random_function() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/core/rewards_rules.gd")
	for banned: String in ["randi", "randf", "RandomNumberGenerator", "shuffle", "pick_random"]:
		assert_bool(source.contains(banned)).override_failure_message("rewards_rules.gd uses " + banned).is_false()


func test_only_zone_4_and_up_pay_rare_gems_for_a_rocks_number() -> void:
	assert_str(RewardsRules.gem_for_rock(1, 7)).is_equal("quartz")
	assert_str(RewardsRules.gem_for_rock(2, 7)).is_equal("garnet")
	assert_str(RewardsRules.gem_for_rock(3, 7)).is_equal("pyrite")
	assert_str(RewardsRules.gem_for_rock(4, 7)).is_equal("mersenne_gem")
	assert_str(RewardsRules.gem_for_rock(5, 12)).is_equal(String(GemArt.gem_for_zone(5)))
	assert_str(RewardsRules.gem_for_rock(4, 0)).is_equal(String(GemArt.gem_for_zone(4))) # no number: the zone's gem


func test_a_twin_gem_drops_as_a_linked_pair_and_pay_rock_counts_it() -> void:
	var rewards: Dictionary = {}
	var paid: Dictionary = RewardsRules.pay_rock(rewards, 4, true, "2027-02-24", 11)
	assert_str(paid["gem"]).is_equal("twin_gem")
	assert_int(paid["count"]).is_equal(2)
	assert_int(RewardsRules.gem_count(rewards, GemArt.TWIN)).is_equal(2)
	paid = RewardsRules.pay_rock(rewards, 4, false, "2027-02-24", 23)
	assert_str(paid["gem"]).is_equal("prime_gem")
	assert_int(RewardsRules.gem_count(rewards, GemArt.PRIME)).is_equal(1)
	assert_int(int(rewards["coins"])).is_equal(3) # 2 for a first try, 1 after a hint: rarity never changes coins


func test_pay_rock_without_a_number_is_exactly_what_it_was() -> void:
	var rewards: Dictionary = {}
	var paid: Dictionary = RewardsRules.pay_rock(rewards, 2, true, "2026-12-01")
	assert_str(paid["gem"]).is_equal("garnet")
	assert_int(paid["count"]).is_equal(1)


func test_the_mine_reads_the_number_a_problem_is_about() -> void:
	var with_n: Problem = Problem.new()
	with_n.prompt_params = {"n": 13}
	assert_int(MineScreen.number_of(with_n)).is_equal(13)
	var without: Problem = Problem.new()
	without.prompt_params = {"a": 3, "b": 4}
	assert_int(MineScreen.number_of(without)).is_equal(0)
	var text_n: Problem = Problem.new()
	text_n.prompt_params = {"n": "seven"}
	assert_int(MineScreen.number_of(text_n)).is_equal(0)


func test_the_rewards_autoload_pays_and_counts_a_session_pair() -> void:
	var dir: String = create_temp_dir("rare_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(dir)
	Rewards.reset_session()
	var paid: Dictionary = Rewards.pay_rock(4, true, 5)
	assert_str(paid["gem"]).is_equal("twin_gem")
	assert_int(Rewards.gem_count(GemArt.TWIN)).is_equal(2)
	assert_int(Rewards.session_summary()["gem_total"]).is_equal(2)
	assert_str(Rewards.gem_for_value(31)).is_equal("mersenne_gem")
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
