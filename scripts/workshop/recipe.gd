## One workshop recipe from curriculum/recipes.json (Sprint 16): the gems it takes, the problem the
## child answers to craft it, and what it makes. Plain data plus loading and validation; the rules
## that spend gems are in WorkshopRules.
class_name Recipe
extends RefCounted

const RECIPES_PATH: String = "res://curriculum/recipes.json"
## What a recipe can make. tool and headlamp are garage-style items; decor is drawn in the hub.
const OUTPUT_TYPES: Array[String] = ["tool", "headlamp", "decor"]

var id: StringName
var name_line_id: StringName
var info_line_id: StringName
## [{gem: StringName, count: int}]
var inputs: Array[Dictionary] = []
var skill_id: StringName
var params: Dictionary = {}
var output_type: String = ""
var output_id: StringName
var unlock_after_skill: StringName


static func from_dict(entry: Dictionary) -> Recipe:
	var recipe: Recipe = Recipe.new()
	recipe.id = StringName(str(entry.get("id", "")))
	recipe.name_line_id = StringName(str(entry.get("name_line_id", "")))
	recipe.info_line_id = StringName(str(entry.get("info_line_id", "")))
	for input: Variant in entry.get("inputs", []):
		if input is Dictionary:
			recipe.inputs.append({"gem": StringName(str(input.get("gem", ""))), "count": int(input.get("count", 0))})
	var math: Dictionary = entry.get("math", {}) if entry.get("math") is Dictionary else {}
	recipe.skill_id = StringName(str(math.get("skill_id", "")))
	recipe.params = math.get("params", {}) if math.get("params") is Dictionary else {}
	var output: Dictionary = entry.get("output", {}) if entry.get("output") is Dictionary else {}
	recipe.output_type = str(output.get("type", ""))
	recipe.output_id = StringName(str(output.get("id", "")))
	recipe.unlock_after_skill = StringName(str(entry.get("unlock_after_skill", "")))
	return recipe


## Every recipe in the file, in file order (empty if the file is missing or not a recipe file).
static func load_all(path: String = RECIPES_PATH) -> Array[Recipe]:
	var result: Array[Recipe] = []
	var data: Variant = JsonUtil.parse_file(path)
	if not data is Dictionary or not data.get("recipes") is Array:
		return result
	for entry: Variant in data["recipes"]:
		if entry is Dictionary:
			result.append(from_dict(entry))
	return result


## Problems with a list of recipes, as readable strings (empty means sound): ids unique, every gem a
## known gem, counts positive, skills and the unlock skill in the catalog with a generator, a known
## output type, and line ids that exist when `has_line` (a Callable StringName -> bool) is given.
static func validate(recipes: Array[Recipe], catalog: SkillCatalog, known_gems: Array[StringName], has_line: Callable = Callable()) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for recipe: Recipe in recipes:
		var where: String = "recipe '%s'" % recipe.id
		if recipe.id == &"":
			problems.append("a recipe has no id")
		elif seen.has(recipe.id):
			problems.append(where + " is listed twice")
		seen[recipe.id] = true
		if recipe.inputs.is_empty():
			problems.append(where + " takes no gems")
		for input: Dictionary in recipe.inputs:
			if not known_gems.has(input["gem"]):
				problems.append(where + " takes an unknown gem '%s'" % input["gem"])
			if int(input["count"]) < 1:
				problems.append(where + " takes a count below 1")
		if not catalog.has_skill(recipe.skill_id):
			problems.append(where + " asks an unknown skill '%s'" % recipe.skill_id)
		elif not GeneratorRegistry.callable_for(catalog.skill(recipe.skill_id)).is_valid():
			problems.append(where + " asks a skill with no generator")
		if recipe.unlock_after_skill != &"" and not catalog.has_skill(recipe.unlock_after_skill):
			problems.append(where + " opens after an unknown skill '%s'" % recipe.unlock_after_skill)
		if not OUTPUT_TYPES.has(recipe.output_type):
			problems.append(where + " makes an unknown kind of thing '%s'" % recipe.output_type)
		if recipe.output_id == &"":
			problems.append(where + " makes nothing")
		if has_line.is_valid():
			for line_id: StringName in [recipe.name_line_id, recipe.info_line_id]:
				if not has_line.call(line_id):
					problems.append(where + " uses a missing line '%s'" % line_id)
	return problems
