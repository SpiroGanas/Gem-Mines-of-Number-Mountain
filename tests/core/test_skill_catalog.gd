# Mirrors scripts/core/skill.gd and skill_catalog.gd.
class_name SkillCatalogTest
extends GdUnitTestSuite

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func test_the_catalog_holds_the_detailed_zones_and_skips_outline_zones() -> void:
	var detailed: int = 0
	for zone: int in range(1, 13):
		detailed += _catalog.skills_in_zone(zone).size()
	assert_int(_catalog.count()).is_equal(detailed)
	assert_int(_catalog.count()).is_equal(176) # 72 in Zones 1-5, 14 in Zone 6, 18 in Zone 7, 16 in Zone 8, 15 in Zone 9 (Phase 4), 15 each in Zones 10 and 11 and 11 in Zone 12 (Phase 5)
	assert_int(_catalog.skills_in_zone(1).size()).is_equal(17)
	assert_int(_catalog.skills_in_zone(2).size()).is_equal(17)
	assert_int(_catalog.skills_in_zone(3).size()).is_equal(11)
	assert_int(_catalog.skills_in_zone(4).size()).is_equal(16)
	assert_int(_catalog.skills_in_zone(5).size()).is_equal(11)
	assert_int(_catalog.skills_in_zone(6).size()).is_equal(14) # Zone 6, Gear Works, with the two fraction previews (Phase 4)
	assert_int(_catalog.skills_in_zone(7).size()).is_equal(18) # Zone 7, Crystal Shards
	assert_int(_catalog.skills_in_zone(8).size()).is_equal(16) # Zone 8, Power Tower
	assert_int(_catalog.skills_in_zone(9).size()).is_equal(15) # Zone 9, Pattern Grotto
	assert_int(_catalog.skills_in_zone(10).size()).is_equal(15) # Zone 10, Clockwork Depths (Phase 5)
	assert_int(_catalog.skills_in_zone(11).size()).is_equal(15) # Zone 11, Cipher Vault (Phase 5)
	assert_int(_catalog.skills_in_zone(12).size()).is_equal(11) # Zone 12, The Infinite Core (Phase 5)
	assert_int(_catalog.skills_in_zone(12).size()).is_equal(0) # Zone 12 is still an outline
	assert_bool(_catalog.has_skill(&"fac.list.find_all")).is_true()
	assert_bool(_catalog.has_skill(&"sieve.mark.multiples_of")).is_true()
	assert_bool(_catalog.has_skill(&"gcf.find.by_listing")).is_true()
	assert_bool(_catalog.has_skill(&"proof.parts.identify")).is_false() # an outline skill (Zone 12) is skipped


func test_ids_come_back_in_curriculum_order() -> void:
	var ids: Array[StringName] = _catalog.ids()
	assert_str(ids[0]).is_equal("count.to_20.objects")
	assert_str(ids[17]).is_equal("add.to_10.sums") # the first Zone 2 skill
	assert_str(ids[45 - 1]).is_equal("mult.facts.2_5_10")


func test_a_skill_carries_every_field_from_the_json() -> void:
	var skill: Skill = _catalog.skill(&"pv.tens_ones.build")
	assert_str(skill.id).is_equal("pv.tens_ones.build")
	assert_str(skill.name).is_equal("Build a number with tens and ones")
	assert_int(skill.zone).is_equal(1)
	assert_array(skill.prereqs).contains_exactly([&"count.to_120.read"])
	assert_str(skill.generator).is_equal("PlaceValueGenerator")
	assert_dict(skill.params).is_equal({"mode": "build", "min": 11, "max": 99})
	assert_array(skill.representations).contains_exactly([&"concrete"])
	assert_array(skill.answer_modes).contains_exactly([&"drag"])
	assert_array(skill.terms).contains_exactly([&"tens", &"ones"])
	assert_str(skill.bkt_type).is_equal("concept")
	assert_bool(skill.is_fact_skill).is_false()
	assert_array(skill.misconceptions).contains_exactly([&"digit_swap", &"counted_tens_as_ones"])


func test_params_are_ints_not_floats() -> void:
	var skill: Skill = _catalog.skill(&"count.to_120.fill_strip")
	assert_bool(skill.params["len"] is int).is_true()
	assert_bool(skill.params["max"] is int).is_true()


func test_fact_skills_are_marked() -> void:
	assert_bool(_catalog.skill(&"add.to_10.sums").is_fact_skill).is_true()
	assert_str(_catalog.skill(&"add.to_10.sums").bkt_type).is_equal("fact")
	assert_bool(_catalog.skill(&"mult.facts.2_5_10").is_fact_skill).is_true()


func test_first_representation_is_the_one_introduced_first() -> void:
	assert_str(_catalog.skill(&"count.write.numeral").first_representation()).is_equal("concrete")
	assert_str(_catalog.skill(&"cmp.to_100.symbols").first_representation()).is_equal("abstract")


func test_an_unknown_skill_is_null() -> void:
	assert_object(_catalog.skill(&"no.such.skill")).is_null()
	assert_bool(_catalog.has_skill(&"no.such.skill")).is_false()


func test_misconception_names_load_from_the_curriculum_file() -> void:
	var names: Array[StringName] = SkillCatalog.misconception_names()
	var on_file: Dictionary = JsonUtil.parse_file(SkillCatalog.MISCONCEPTIONS_PATH)["misconceptions"]
	assert_int(names.size()).is_equal(on_file.size())
	assert_int(names.size()).is_greater_equal(70) # the Phase 1-2 names stay (never renamed or removed)
	# 70 through Zone 5, 32 from Zone 6, 30 more from Zone 7 (inverted_ratio is shared), 27 from Zone 8,
	# 21 more from Zone 9 (off_by_one_exponent is shared with Zone 8), 27 more from Zone 10, 29 more from Zone 11, 27 more from Zone 12.
	assert_int(names.size()).is_equal(263)
	assert_bool(names.has(&"zero_power_is_zero") and names.has(&"mantissa_not_normalized")).is_true()
	assert_bool(names.has(&"digit_swap")).is_true()
	assert_bool(names.has(&"thought_equal")).is_true()
