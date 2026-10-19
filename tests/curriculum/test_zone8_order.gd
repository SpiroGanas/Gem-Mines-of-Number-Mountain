# Zone 8 (Power Tower) comes after Zone 7 (P4-S35-01): every Zone 8 skill leads back, through its
# prerequisites, to a Zone 7 skill, so no Zone 8 problem, music or banner can appear before Zone 7 is
# open; and a child who has mastered every skill below Zone 7 still finds Zone 8 closed.
class_name Zone8OrderTest
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


func test_zone_8_has_its_sixteen_skills_in_detail() -> void:
	assert_int(_catalog.skills_in_zone(8).size()).is_equal(16)
	for skill: Skill in _catalog.skills_in_zone(8):
		assert_bool(GeneratorRegistry.has_generator(skill.generator)).override_failure_message(String(skill.id)).is_true()


func test_every_zone_8_skill_leads_back_to_zone_7() -> void:
	for skill: Skill in _catalog.skills_in_zone(8):
		assert_bool(_reaches_zone(skill.id, 7)).override_failure_message("%s does not wait for Zone 7" % skill.id).is_true()


func test_mastering_everything_below_zone_7_leaves_zone_8_closed() -> void:
	var mastered: Array[StringName] = []
	for id: StringName in _catalog.ids():
		if _catalog.skill(id).zone < 7:
			mastered.append(id)
	for skill: Skill in _catalog.skills_in_zone(8):
		var open: bool = true
		for prereq: StringName in skill.prereqs:
			open = open and mastered.has(prereq)
		assert_bool(open).override_failure_message("%s is open before Zone 7" % skill.id).is_false()
