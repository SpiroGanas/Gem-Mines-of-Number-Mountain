# Mirrors scripts/core/rewards_rules.gd: Rewards v1 and its guardrails.
class_name RewardsRulesTest
extends GdUnitTestSuite


func _rewards() -> Dictionary:
	return SaveSchema.new_profile("2026-12-07T12:00:00Z")["rewards"]


func test_a_rock_pays_two_coins_on_the_first_try_one_after_hints_and_one_zone_gem() -> void:
	var rewards: Dictionary = _rewards()
	assert_dict(RewardsRules.pay_rock(rewards, 1, true, "2026-12-07")).is_equal({"coins": 2, "gem": &"quartz", "lantern_lit": true})
	assert_dict(RewardsRules.pay_rock(rewards, 2, false, "2026-12-07")).is_equal({"coins": 1, "gem": &"garnet", "lantern_lit": false})
	RewardsRules.pay_rock(rewards, 3, true, "2026-12-07")
	assert_int(rewards["coins"]).is_equal(5)
	assert_dict(rewards["gems"]).is_equal({"quartz": 1, "garnet": 1, "pyrite": 1})


func test_the_same_rock_always_pays_the_same() -> void:
	var first: Dictionary = _rewards()
	var second: Dictionary = _rewards()
	for i: int in 20:
		RewardsRules.pay_rock(first, 1, i % 3 == 0, "2026-12-07")
		RewardsRules.pay_rock(second, 1, i % 3 == 0, "2026-12-07")
	assert_dict(first).is_equal(second) # nothing random-for-value


func test_the_lantern_lights_once_a_day_and_a_missed_day_only_pauses_the_streak() -> void:
	var rewards: Dictionary = _rewards()
	assert_bool(RewardsRules.light_lantern(rewards, "2026-12-07")).is_true()
	assert_bool(RewardsRules.light_lantern(rewards, "2026-12-07")).is_false()
	assert_bool(RewardsRules.light_lantern(rewards, "2026-12-08")).is_true()
	assert_int(RewardsRules.streak(rewards)).is_equal(2)
	# A week away: the streak waits, then goes on from 2.
	assert_int(RewardsRules.streak(rewards)).is_equal(2)
	assert_bool(RewardsRules.light_lantern(rewards, "2026-12-15")).is_true()
	assert_int(RewardsRules.streak(rewards)).is_equal(3)
	assert_bool(RewardsRules.is_lit(rewards, "2026-12-08")).is_true()
	assert_bool(RewardsRules.is_lit(rewards, "2026-12-09")).is_false()


func test_museum_minerals_come_from_mastery_milestones_and_are_found_once() -> void:
	var rewards: Dictionary = _rewards()
	var zones: Dictionary = {1: [&"a", &"b"], 2: [&"c"], 3: [&"d"]}
	var mastered: Array[StringName] = [&"a"]
	assert_array(RewardsRules.milestones_reached(rewards, mastered, zones)).is_empty()
	mastered.append(&"b")
	assert_array(RewardsRules.milestones_reached(rewards, mastered, zones)).contains_exactly([&"malachite"]) # all of zone 1
	RewardsRules.add_gem(rewards, &"malachite")
	assert_array(RewardsRules.milestones_reached(rewards, mastered, zones)).is_empty() # not twice
	var many: Array[StringName] = []
	for i: int in 15:
		many.append(StringName("s%d" % i))
	assert_array(RewardsRules.milestones_reached(_rewards(), many, {})).contains_exactly([&"calcite", &"topaz"])


func test_every_museum_mineral_can_be_earned() -> void:
	var earned: Array[StringName] = [&"quartz", &"garnet", &"pyrite", RewardsRules.MASTERY_GEM]
	for milestone: Dictionary in RewardsRules.MILESTONES:
		earned.append(milestone["gem"])
	assert_array(earned).contains_exactly_in_any_order(GemArt.ALL_TYPES)


func test_a_case_opens_when_the_child_holds_the_mineral() -> void:
	var rewards: Dictionary = _rewards()
	assert_bool(RewardsRules.museum_open(rewards, &"topaz")).is_false()
	RewardsRules.add_gem(rewards, &"topaz")
	assert_bool(RewardsRules.museum_open(rewards, &"topaz")).is_true()


func test_buying_costs_coins_once_and_a_headlamp_goes_on() -> void:
	var rewards: Dictionary = _rewards()
	rewards["coins"] = 45
	assert_bool(RewardsRules.can_buy(rewards, &"pickaxe_t2")).is_false() # 50 coins
	assert_bool(RewardsRules.buy(rewards, &"pickaxe_t2")).is_false()
	assert_int(rewards["coins"]).is_equal(45) # a refused purchase changes nothing
	assert_bool(RewardsRules.buy(rewards, &"headlamp_gold")).is_true()
	assert_int(rewards["coins"]).is_equal(5)
	assert_str(RewardsRules.headlamp(rewards)).is_equal("gold")
	assert_bool(RewardsRules.buy(rewards, &"headlamp_gold")).is_false() # owned already
	assert_bool(RewardsRules.buy(rewards, &"no_such_item")).is_false()


func test_only_owned_headlamps_can_be_worn() -> void:
	var rewards: Dictionary = _rewards()
	assert_str(RewardsRules.headlamp(rewards)).is_equal("blue")
	assert_bool(RewardsRules.set_headlamp(rewards, "green")).is_false()
	rewards["inventory"].append("headlamp_green")
	assert_bool(RewardsRules.set_headlamp(rewards, "green")).is_true()
	assert_bool(RewardsRules.set_headlamp(rewards, "blue")).is_true() # the starting lamp is always owned
	assert_bool(RewardsRules.set_headlamp(rewards, "purple")).is_false()


func test_the_big_pickaxe_is_used_once_owned() -> void:
	var rewards: Dictionary = _rewards()
	assert_str(RewardsRules.pickaxe(rewards)).is_equal("pickaxe_t1")
	rewards["coins"] = 50
	RewardsRules.buy(rewards, &"pickaxe_t2")
	assert_str(RewardsRules.pickaxe(rewards)).is_equal("pickaxe_t2")


func test_the_shop_prices_are_the_plans() -> void:
	assert_int(RewardsRules.price_of(&"pickaxe_t2")).is_equal(50)
	assert_int(RewardsRules.price_of(&"headlamp_green")).is_equal(20)
	assert_int(RewardsRules.price_of(&"headlamp_gold")).is_equal(40)
