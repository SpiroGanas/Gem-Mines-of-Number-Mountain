# Mirrors the Python curriculum checks (tools/ci/curriculum_check.py) on the Godot side, so a
# cycle, a missing prerequisite or an unresolvable generator fails both test suites.
class_name SkillGraphTest
extends GdUnitTestSuite

## Generators the plan schedules for later sprints. Every MVP generator (Zones 1-3) is built, so the
## list is empty; a later zone's skill added before its generator goes here until it is built.
const NOT_BUILT_YET: Array[StringName] = []

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func test_every_prerequisite_exists_in_an_earlier_or_the_same_zone() -> void:
	for id: StringName in _catalog.ids():
		var skill: Skill = _catalog.skill(id)
		for prereq: StringName in skill.prereqs:
			assert_bool(_catalog.has_skill(prereq)).override_failure_message("%s needs missing %s" % [id, prereq]).is_true()
			assert_int(_catalog.skill(prereq).zone).override_failure_message("%s needs a later-zone %s" % [id, prereq]).is_less_equal(skill.zone)


func test_the_prerequisite_graph_has_no_cycle() -> void:
	# Depth-first search with three colours: a grey node reached again is a cycle.
	var color: Dictionary[StringName, int] = {}
	for id: StringName in _catalog.ids():
		color[id] = 0
	var cycle: Array[StringName] = []
	for id: StringName in _catalog.ids():
		if color[id] == 0 and _visit(id, color, [], cycle):
			break
	assert_array(cycle).override_failure_message("prerequisite cycle: " + " -> ".join(cycle)).is_empty()


func _visit(id: StringName, color: Dictionary[StringName, int], path: Array[StringName], cycle: Array[StringName]) -> bool:
	color[id] = 1
	path.append(id)
	for prereq: StringName in _catalog.skill(id).prereqs:
		if color[prereq] == 1:
			cycle.append_array(path)
			cycle.append(prereq)
			return true
		if color[prereq] == 0 and _visit(prereq, color, path, cycle):
			return true
	path.pop_back()
	color[id] = 2
	return false


func test_there_is_exactly_one_root_skill() -> void:
	var roots: Array[StringName] = []
	for id: StringName in _catalog.ids():
		if _catalog.skill(id).prereqs.is_empty():
			roots.append(id)
	assert_array(roots).contains_exactly([&"count.to_20.objects"])


func test_every_generator_resolves_or_is_scheduled_for_a_later_sprint() -> void:
	for id: StringName in _catalog.ids():
		var skill: Skill = _catalog.skill(id)
		if GeneratorRegistry.has_generator(skill.generator):
			assert_bool(NOT_BUILT_YET.has(skill.generator)).override_failure_message("%s is built; remove it from NOT_BUILT_YET" % skill.generator).is_false()
		else:
			assert_bool(NOT_BUILT_YET.has(skill.generator)).override_failure_message("%s uses unknown generator %s" % [id, skill.generator]).is_true()


func test_all_of_zones_1_to_3_is_playable() -> void:
	for zone: int in [1, 2, 3]:
		for skill: Skill in _catalog.skills_in_zone(zone):
			assert_bool(GeneratorRegistry.callable_for(skill).is_valid()).override_failure_message(skill.id + " has no generator").is_true()


func test_every_misconception_a_skill_lists_is_an_allowed_name() -> void:
	var allowed: Array[StringName] = SkillCatalog.misconception_names()
	for id: StringName in _catalog.ids():
		for name: StringName in _catalog.skill(id).misconceptions:
			assert_bool(allowed.has(name)).override_failure_message("%s uses unknown misconception %s" % [id, name]).is_true()


func test_every_term_is_a_word_gem_with_text() -> void:
	var vocabulary: Dictionary = JsonUtil.parse_file("res://curriculum/vocabulary.json")
	var known: Dictionary[StringName, bool] = {}
	for entry: Dictionary in vocabulary["terms"]:
		known[StringName(entry["id"])] = true
	for id: StringName in _catalog.ids():
		for term: StringName in _catalog.skill(id).terms:
			assert_bool(known.has(term)).override_failure_message("%s uses unknown term %s" % [id, term]).is_true()
			assert_bool(Text.term_definition(term).has("text")).is_true()


func test_answer_modes_and_representations_are_valid() -> void:
	var modes: Array[StringName] = [&"tap", &"drag", &"number_pad", &"keyboard", &"handwriting"]
	var representations: Array[StringName] = [&"concrete", &"pictorial", &"abstract"]
	for id: StringName in _catalog.ids():
		var skill: Skill = _catalog.skill(id)
		assert_bool(not skill.answer_modes.is_empty() and not skill.representations.is_empty()).is_true()
		for mode: StringName in skill.answer_modes:
			assert_bool(modes.has(mode)).is_true()
		for representation: StringName in skill.representations:
			assert_bool(representations.has(representation)).is_true()
