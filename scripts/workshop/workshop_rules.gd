## The workshop's rules (Sprint 16), pure functions over the save Dictionary (schema v2):
##   crafting   a recipe spends its gems and adds its output only after the child answered its
##              problem right (the caller checks the answer); nothing is spent on a wrong answer,
##              and a recipe is crafted once.
##   builds     save.workshop.builds[id] = {step: steps done, done: bool}; a step is saved the moment
##              it is finished, so closing the app mid-build resumes at the same step.
##   zones      a build with locks_zone keeps its zone out of the dig until it is done, unless the
##              child already has answers in that zone (an existing save never loses a zone).
class_name WorkshopRules
extends RefCounted


static func workshop(save: Dictionary) -> Dictionary:
	if not save.get("workshop") is Dictionary:
		save["workshop"] = {"crafted": [], "builds": {}}
	var shop: Dictionary = save["workshop"]
	if not shop.get("crafted") is Array:
		shop["crafted"] = []
	if not shop.get("builds") is Dictionary:
		shop["builds"] = {}
	return shop


# --- Crafting -------------------------------------------------------------------------------------


static func is_crafted(save: Dictionary, recipe: Recipe) -> bool:
	return workshop(save)["crafted"].has(String(recipe.id)) or _owns_output(save, recipe)


## The recipe is offered: its unlock skill opens successors (`opens` is a Callable skill_id -> bool).
static func is_open(recipe: Recipe, opens: Callable) -> bool:
	return recipe.unlock_after_skill == &"" or bool(opens.call(recipe.unlock_after_skill))


## Gems still missing for the recipe: {gem: count} (empty when the child has enough).
static func missing_gems(save: Dictionary, recipe: Recipe) -> Dictionary:
	var missing: Dictionary = {}
	for input: Dictionary in recipe.inputs:
		var have: int = RewardsRules.gem_count(save.get("rewards", {}), input["gem"])
		if have < int(input["count"]):
			missing[input["gem"]] = int(input["count"]) - have
	return missing


static func can_craft(save: Dictionary, recipe: Recipe, opens: Callable) -> bool:
	return is_open(recipe, opens) and not is_crafted(save, recipe) and missing_gems(save, recipe).is_empty()


## Spends the gems and adds the output. Call only after a right answer. Returns false and changes
## nothing when the recipe cannot be crafted.
static func craft(save: Dictionary, recipe: Recipe, opens: Callable) -> bool:
	if not can_craft(save, recipe, opens):
		return false
	var rewards: Dictionary = save["rewards"]
	for input: Dictionary in recipe.inputs:
		rewards["gems"][String(input["gem"])] = RewardsRules.gem_count(rewards, input["gem"]) - int(input["count"])
	if not rewards.get("inventory") is Array:
		rewards["inventory"] = []
	if not rewards["inventory"].has(String(recipe.output_id)):
		rewards["inventory"].append(String(recipe.output_id))
	workshop(save)["crafted"].append(String(recipe.id))
	if recipe.output_type == "headlamp":
		RewardsRules.set_headlamp(rewards, RewardsRules.headlamp_for_item(recipe.output_id))
	return true


static func _owns_output(save: Dictionary, recipe: Recipe) -> bool:
	return RewardsRules.owns(save.get("rewards", {}), recipe.output_id)


# --- Builds ---------------------------------------------------------------------------------------


## {step: int, done: bool} for a build (a fresh record is not stored).
static func build_state(save: Dictionary, build: BuildProject) -> Dictionary:
	var record: Variant = workshop(save)["builds"].get(String(build.id))
	if not record is Dictionary:
		return {"step": 0, "done": false}
	return {"step": clampi(int(record.get("step", 0)), 0, build.step_count()), "done": bool(record.get("done", false))}


static func is_built(save: Dictionary, build: BuildProject) -> bool:
	return build_state(save, build)["done"]


## The build site offers the build: its unlock skill opens successors.
static func is_open_build(build: BuildProject, opens: Callable) -> bool:
	return build.unlock_after_skill == &"" or bool(opens.call(build.unlock_after_skill))


## Records one finished step. Returns true when that step finished the build.
static func finish_step(save: Dictionary, build: BuildProject) -> bool:
	var state: Dictionary = build_state(save, build)
	if state["done"]:
		return false
	var step: int = mini(int(state["step"]) + 1, build.step_count())
	var done: bool = step >= build.step_count()
	workshop(save)["builds"][String(build.id)] = {"step": step, "done": done}
	return done


## Zones the dig must not offer yet. `zone_has_answers` is a Callable zone(int) -> bool.
static func locked_zones(save: Dictionary, builds: Array[BuildProject], zone_has_answers: Callable) -> Array[int]:
	var locked: Array[int] = []
	for build: BuildProject in builds:
		if build.locks_zone and not is_built(save, build) and not bool(zone_has_answers.call(build.zone_unlocks)):
			locked.append(build.zone_unlocks)
	return locked
