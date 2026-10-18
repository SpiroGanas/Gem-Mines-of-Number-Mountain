## One mine-engineering project from curriculum/builds.json (Sprint 16): an ordered list of steps,
## each a problem of one skill shown by a step scene. The build screen runs the steps; this class is
## the data plus loading and validation. Progress lives in the save (WorkshopRules).
class_name BuildProject
extends RefCounted

const BUILDS_PATH: String = "res://curriculum/builds.json"

var id: StringName
var name_line_id: StringName
var intro_line_id: StringName
var reward_line_id: StringName
var zone_unlocks: int = 0
## The zone stays closed to the dig until this build is done (WorkshopRules.locked_zones).
var locks_zone: bool = false
var unlock_after_skill: StringName
## [{step_id: StringName, scene: String, skill_id: StringName, params: Dictionary}]
var steps: Array[Dictionary] = []


static func from_dict(entry: Dictionary) -> BuildProject:
	var build: BuildProject = BuildProject.new()
	build.id = StringName(str(entry.get("id", "")))
	build.name_line_id = StringName(str(entry.get("name_line_id", "")))
	build.intro_line_id = StringName(str(entry.get("intro_line_id", "")))
	build.reward_line_id = StringName(str(entry.get("reward_line_id", "")))
	build.zone_unlocks = int(entry.get("zone_unlocks", 0))
	build.locks_zone = bool(entry.get("locks_zone", false))
	build.unlock_after_skill = StringName(str(entry.get("unlock_after_skill", "")))
	for step: Variant in entry.get("steps", []):
		if step is Dictionary:
			build.steps.append({
				"step_id": StringName(str(step.get("step_id", ""))),
				"scene": str(step.get("scene", "")),
				"skill_id": StringName(str(step.get("skill_id", ""))),
				"params": step.get("params", {}) if step.get("params") is Dictionary else {},
			})
	return build


static func load_all(path: String = BUILDS_PATH) -> Array[BuildProject]:
	var result: Array[BuildProject] = []
	var data: Variant = JsonUtil.parse_file(path)
	if not data is Dictionary or not data.get("builds") is Array:
		return result
	for entry: Variant in data["builds"]:
		if entry is Dictionary:
			result.append(from_dict(entry))
	return result


func step_count() -> int:
	return steps.size()


## Problems with a list of builds, as readable strings (empty means sound).
static func validate(builds: Array[BuildProject], catalog: SkillCatalog, has_line: Callable = Callable()) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for build: BuildProject in builds:
		var where: String = "build '%s'" % build.id
		if build.id == &"":
			problems.append("a build has no id")
		elif seen.has(build.id):
			problems.append(where + " is listed twice")
		seen[build.id] = true
		if build.steps.is_empty():
			problems.append(where + " has no steps")
		if build.zone_unlocks < 1:
			problems.append(where + " opens no zone")
		if build.unlock_after_skill != &"" and not catalog.has_skill(build.unlock_after_skill):
			problems.append(where + " opens after an unknown skill '%s'" % build.unlock_after_skill)
		var step_ids: Dictionary = {}
		for step: Dictionary in build.steps:
			if step_ids.has(step["step_id"]):
				problems.append(where + " repeats step '%s'" % step["step_id"])
			step_ids[step["step_id"]] = true
			if not ResourceLoader.exists(step["scene"]):
				problems.append(where + " step '%s' has no scene at %s" % [step["step_id"], step["scene"]])
			if not catalog.has_skill(step["skill_id"]):
				problems.append(where + " step '%s' asks an unknown skill '%s'" % [step["step_id"], step["skill_id"]])
		if has_line.is_valid():
			for line_id: StringName in [build.name_line_id, build.intro_line_id, build.reward_line_id]:
				if not has_line.call(line_id):
					problems.append(where + " uses a missing line '%s'" % line_id)
	return problems
