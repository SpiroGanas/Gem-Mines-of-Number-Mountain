# Mirrors scripts/workshop/recipe.gd and build_project.gd (Sprint 16, P2-S16-01): the shipped files
# are sound, and the validator catches every kind of broken entry.
class_name RecipeValidationTest
extends GdUnitTestSuite

const KNOWN_GEMS: Array[StringName] = [GemArt.QUARTZ, GemArt.GARNET, GemArt.PYRITE, GemArt.AMETHYST]


func _has_line(id: StringName) -> bool:
	return Text.has_line(id)


func test_the_shipped_recipes_are_sound() -> void:
	var recipes: Array[Recipe] = Recipe.load_all()
	assert_int(recipes.size()).is_greater_equal(3)
	assert_array(Recipe.validate(recipes, SkillCatalog.load_all(), KNOWN_GEMS, _has_line)).is_empty()


func test_the_pickaxe_recipe_takes_twelve_garnets() -> void:
	var pickaxe: Recipe = null
	for recipe: Recipe in Recipe.load_all():
		if recipe.id == &"tool.pickaxe.tier2":
			pickaxe = recipe
	assert_object(pickaxe).is_not_null()
	assert_that(pickaxe.inputs[0]["gem"]).is_equal(GemArt.GARNET)
	assert_int(pickaxe.inputs[0]["count"]).is_equal(12)
	assert_that(pickaxe.output_id).is_equal(&"pickaxe_t2")


func test_a_bad_recipe_file_fails_validation_for_each_fault() -> void:
	var recipes: Array[Recipe] = Recipe.load_all("res://tests/workshop/fixtures/bad_recipes.json")
	var problems: PackedStringArray = Recipe.validate(recipes, SkillCatalog.load_all(), KNOWN_GEMS, _has_line)
	var text: String = "\n".join(problems)
	for expected: String in ["listed twice", "unknown gem 'unobtainium'", "count below 1", "unknown skill 'no.such.skill'", "unknown skill 'also.not.real'", "unknown kind of thing 'spaceship'", "makes nothing", "takes no gems", "missing line 'ws.missing.line'"]:
		assert_bool(text.contains(expected)).override_failure_message("no problem says '%s' in:\n%s" % [expected, text]).is_true()


func test_a_missing_recipe_file_gives_no_recipes() -> void:
	assert_array(Recipe.load_all("res://tests/workshop/fixtures/none.json")).is_empty()


func test_the_shipped_builds_are_sound() -> void:
	var builds: Array[BuildProject] = BuildProject.load_all()
	assert_int(builds.size()).is_equal(2)
	assert_array(BuildProject.validate(builds, SkillCatalog.load_all(), _has_line)).is_empty()


func test_the_balance_elevator_opens_zone_4_and_the_cart_track_locks_nothing() -> void:
	for build: BuildProject in BuildProject.load_all():
		match build.id:
			&"balance_elevator":
				assert_int(build.zone_unlocks).is_equal(4)
				assert_bool(build.locks_zone).is_true()
			&"cart_track":
				assert_bool(build.locks_zone).is_false()


func test_a_broken_build_fails_validation() -> void:
	var build: BuildProject = BuildProject.from_dict({"id": "x", "steps": [
		{"step_id": "a", "scene": "res://nowhere.tscn", "skill_id": "nope"},
		{"step_id": "a", "scene": "res://scenes/workshop/builds/cart_track.tscn", "skill_id": "add.to_10.sums"},
	]})
	var builds: Array[BuildProject] = [build]
	var text: String = "\n".join(BuildProject.validate(builds, SkillCatalog.load_all()))
	for expected: String in ["opens no zone", "repeats step 'a'", "has no scene", "unknown skill 'nope'"]:
		assert_bool(text.contains(expected)).override_failure_message("missing: " + expected).is_true()
