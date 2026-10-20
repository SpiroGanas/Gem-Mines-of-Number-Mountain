# Zone 11 (Cipher Vault) comes after Zone 10 (P5-S44-01): every Zone 11 skill leads back, through its prerequisites,
# to a Zone 10 skill, so no Zone 11 problem, music or banner can appear before Zone 10 is open; and a child who has
# mastered every skill below Zone 10 still finds Zone 11 closed.
class_name Zone11OrderTest
extends GdUnitTestSuite

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _reaches_zone(skill_id: StringName, zone: int, seen: Dictionary = {}) -> bool:
	if seen.has(skill_id):
		return false
	seen[skill_id] = true
	for prereq: StringName in _catalog.skill(skill_id).prereqs:
		if _catalog.skill(prereq).zone == zone or _reaches_zone(prereq, zone, seen):
			return true
	return false


func test_zone_11_has_its_fifteen_skills_in_detail() -> void:
	assert_int(_catalog.skills_in_zone(11).size()).is_equal(15)
	for skill: Skill in _catalog.skills_in_zone(11):
		assert_bool(GeneratorRegistry.has_generator(skill.generator)).override_failure_message(String(skill.id)).is_true()


func test_every_zone_11_skill_leads_back_to_zone_10() -> void:
	for skill: Skill in _catalog.skills_in_zone(11):
		assert_bool(_reaches_zone(skill.id, 10)).override_failure_message("%s does not wait for Zone 10" % skill.id).is_true()


func test_mastering_everything_below_zone_10_leaves_zone_11_closed() -> void:
	var mastered: Array[StringName] = []
	for id: StringName in _catalog.ids():
		if _catalog.skill(id).zone < 10:
			mastered.append(id)
	for skill: Skill in _catalog.skills_in_zone(11):
		var open: bool = true
		for prereq: StringName in skill.prereqs:
			open = open and mastered.has(prereq)
		assert_bool(open).override_failure_message("%s is open before Zone 10" % skill.id).is_false()


func test_the_word_gems_of_zone_11_exist_with_lines() -> void:
	for skill: Skill in _catalog.skills_in_zone(11):
		for term: StringName in skill.terms:
			assert_bool(Text.has_line(StringName("vocab.%s.term" % term))).override_failure_message(String(term)).is_true()
			assert_bool(Text.has_line(StringName("vocab.%s.definition" % term))).override_failure_message(String(term)).is_true()
