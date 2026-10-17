## Chooses the problems for a wall of rocks. Sprint 5 stand-in for the adaptive engine: it picks
## skills at random from the playable Zone 1 list (curriculum order), never the same skill twice
## in a row. Sprint 6 replaces this with `Adaptive.next_problem()` (frontier, review, BKT) and this
## class goes away. Pure: it uses only the rng it is given.
class_name ProblemSource
extends RefCounted

var _skills: Array[Skill] = []


## `skill_ids` limits the pool (tests use this); empty means every playable Zone 1 skill.
func _init(catalog: SkillCatalog, skill_ids: Array[StringName] = []) -> void:
	for id: StringName in catalog.ids():
		var skill: Skill = catalog.skill(id)
		if skill.zone != 1 or not GeneratorRegistry.callable_for(skill).is_valid():
			continue
		if skill_ids.is_empty() or skill_ids.has(id):
			_skills.append(skill)


func playable_skills() -> Array[Skill]:
	return _skills.duplicate()


## `count` problems, one per rock. The representation is picked at random among the skill's own.
func make_wall(count: int, rng: RandomNumberGenerator) -> Array[Problem]:
	assert(not _skills.is_empty(), "no playable skills")
	var problems: Array[Problem] = []
	var last: int = -1
	for i: int in count:
		var index: int = rng.randi_range(0, _skills.size() - 1)
		if _skills.size() > 1 and index == last:
			index = (index + 1 + rng.randi_range(0, _skills.size() - 2)) % _skills.size()
		last = index
		var skill: Skill = _skills[index]
		var representation: StringName = skill.representations[rng.randi_range(0, skill.representations.size() - 1)]
		problems.append(GeneratorRegistry.make_problem(skill, rng.randi(), {"representation": representation}))
	return problems
