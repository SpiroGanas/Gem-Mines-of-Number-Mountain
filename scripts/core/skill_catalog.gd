## Loads the curriculum: every detailed skill, the allowed misconception names and the BKT
## defaults. Pure file reading; the autoload-free design lets tests and the cross-checker use it.
##
## Outline zones (status "outline", Zones 4-12 for now) hold only ids and names and are skipped:
## they have no generators yet.
class_name SkillCatalog
extends RefCounted

const SKILLS_DIR: String = "res://curriculum/skills"
const MISCONCEPTIONS_PATH: String = "res://curriculum/misconceptions.json"
const BKT_DEFAULTS_PATH: String = "res://curriculum/bkt_defaults.json"

var _skills: Dictionary[StringName, Skill] = {}
var _order: Array[StringName] = []


## Reads every zone file in `dir` and keeps the detailed skills, in zone then file order.
static func load_all(dir: String = SKILLS_DIR) -> SkillCatalog:
	var catalog: SkillCatalog = SkillCatalog.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	var names: Array[String] = []
	for file_name: String in files:
		if file_name.ends_with(".json"):
			names.append(file_name)
	names.sort()
	for file_name: String in names:
		var zone_data: Variant = JsonUtil.parse_file(dir.path_join(file_name))
		if not zone_data is Dictionary or zone_data.get("status") != "detailed":
			continue
		for entry: Dictionary in zone_data["skills"]:
			var skill: Skill = Skill.from_json(entry, int(zone_data["zone"]))
			catalog._skills[skill.id] = skill
			catalog._order.append(skill.id)
	return catalog


func has_skill(id: StringName) -> bool:
	return _skills.has(id)


func skill(id: StringName) -> Skill:
	return _skills.get(id)


func count() -> int:
	return _order.size()


## Skill ids in curriculum order.
func ids() -> Array[StringName]:
	return _order.duplicate()


func skills_in_zone(zone: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for id: StringName in _order:
		if _skills[id].zone == zone:
			result.append(_skills[id])
	return result


## The allowed distractor misconception names (curriculum/misconceptions.json).
static func misconception_names() -> Array[StringName]:
	var data: Variant = JsonUtil.parse_file(MISCONCEPTIONS_PATH)
	var names: Array[StringName] = []
	if data is Dictionary:
		for name: String in data["misconceptions"]:
			names.append(StringName(name))
	return names
