# Mirrors scripts/core/rank_rules.gd and curriculum/ranks.json (Master Miner ranks, Phase 5).
class_name RankRulesTest
extends GdUnitTestSuite


func _ids(count: int, prefix: String = "s") -> Array[StringName]:
	var ids: Array[StringName] = []
	for index: int in count:
		ids.append(StringName("%s%d" % [prefix, index]))
	return ids


## Zones: 1 with 150 skills (the first `done` mastered ones), plus zone 10 with two skills.
func _rank(mastered_count: int, zone10_done: bool, all_done: bool = false) -> String:
	var zone1: Array[StringName] = _ids(150)
	var zone10: Array[StringName] = [&"a", &"b"]
	var mastered: Array[StringName] = []
	if all_done:
		mastered = zone1.duplicate()
		mastered.append_array(zone10)
	else:
		mastered = zone1.slice(0, mastered_count)
		if zone10_done:
			mastered.append_array(zone10)
	return str(RankRules.rank_for(mastered, {1: zone1, 10: zone10})["id"])


func test_the_boundaries_between_ranks() -> void:
	assert_str(_rank(0, false)).is_equal("apprentice")
	assert_str(_rank(20, false)).is_equal("apprentice")
	assert_str(_rank(21, false)).is_equal("digger")
	assert_str(_rank(60, false)).is_equal("digger")
	assert_str(_rank(61, false)).is_equal("surveyor")
	assert_str(_rank(100, false)).is_equal("surveyor")
	assert_str(_rank(101, false)).is_equal("engineer")
	assert_str(_rank(140, false)).is_equal("engineer")


func test_master_miner_needs_141_and_zone_10() -> void:
	assert_str(_rank(141, false)).is_equal("engineer")
	assert_str(_rank(141, true)).is_equal("master_miner")
	assert_str(_rank(140, true)).is_equal("master_miner") # 140 plus the two zone 10 skills is 142 mastered


func test_core_keeper_needs_every_zone() -> void:
	assert_str(_rank(0, false, true)).is_equal("core_keeper")
	assert_str(_rank(149, true)).is_equal("master_miner")


func test_no_zones_is_not_core_keeper() -> void:
	var none: Array[StringName] = []
	assert_str(str(RankRules.rank_for(none, {})["id"])).is_equal("apprentice")


func test_every_rank_name_is_in_the_text_table() -> void:
	for rank: Dictionary in RankRules.ranks():
		assert_bool(Text.has_line(RankRules.name_line(rank))).override_failure_message(str(rank["id"])).is_true()
