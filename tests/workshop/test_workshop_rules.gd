# Mirrors scripts/workshop/workshop_rules.gd (Sprint 16): crafting spends gems only when it succeeds,
# build progress is kept per step, and a build keeps its zone closed unless the child is already there.
class_name WorkshopRulesTest
extends GdUnitTestSuite

var _pickaxe: Recipe
var _elevator: BuildProject
var _track: BuildProject


func before_test() -> void:
	for recipe: Recipe in Recipe.load_all():
		if recipe.id == &"tool.pickaxe.tier2":
			_pickaxe = recipe
	for build: BuildProject in BuildProject.load_all():
		if build.id == &"balance_elevator":
			_elevator = build
		elif build.id == &"cart_track":
			_track = build


func _always(_id: StringName) -> bool:
	return true


func _never(_id: StringName) -> bool:
	return false


func _save_with(garnets: int) -> Dictionary:
	var save: Dictionary = SaveSchema.new_profile("t")
	save["rewards"]["gems"]["garnet"] = garnets
	return save


func test_crafting_spends_the_gems_and_adds_the_tool() -> void:
	var save: Dictionary = _save_with(15)
	assert_bool(WorkshopRules.craft(save, _pickaxe, _always)).is_true()
	assert_int(save["rewards"]["gems"]["garnet"]).is_equal(3)
	assert_bool(RewardsRules.owns(save["rewards"], &"pickaxe_t2")).is_true()
	assert_array(save["workshop"]["crafted"]).contains(["tool.pickaxe.tier2"])
	assert_that(RewardsRules.pickaxe(save["rewards"])).is_equal(&"pickaxe_t2")


func test_without_enough_gems_nothing_changes() -> void:
	var save: Dictionary = _save_with(11)
	var before: Dictionary = save.duplicate(true)
	assert_dict(WorkshopRules.missing_gems(save, _pickaxe)).is_equal({&"garnet": 1})
	assert_bool(WorkshopRules.craft(save, _pickaxe, _always)).is_false()
	assert_dict(save).is_equal(before)


func test_a_recipe_is_crafted_once() -> void:
	var save: Dictionary = _save_with(30)
	assert_bool(WorkshopRules.craft(save, _pickaxe, _always)).is_true()
	assert_bool(WorkshopRules.craft(save, _pickaxe, _always)).is_false()
	assert_int(save["rewards"]["gems"]["garnet"]).is_equal(18)


func test_a_pickaxe_bought_in_the_garage_counts_as_made() -> void:
	var save: Dictionary = _save_with(30)
	save["rewards"]["inventory"].append("pickaxe_t2")
	assert_bool(WorkshopRules.is_crafted(save, _pickaxe)).is_true()
	assert_bool(WorkshopRules.can_craft(save, _pickaxe, _always)).is_false()


func test_a_closed_recipe_cannot_be_crafted() -> void:
	assert_bool(WorkshopRules.craft(_save_with(30), _pickaxe, _never)).is_false()


func test_the_white_headlamp_goes_on_when_crafted() -> void:
	var lamp: Recipe = null
	for recipe: Recipe in Recipe.load_all():
		if recipe.id == &"headlamp.white":
			lamp = recipe
	var save: Dictionary = SaveSchema.new_profile("t")
	save["rewards"]["gems"]["quartz"] = 10
	assert_bool(WorkshopRules.craft(save, lamp, _always)).is_true()
	assert_str(RewardsRules.headlamp(save["rewards"])).is_equal("white")
	assert_int(save["rewards"]["gems"]["quartz"]).is_equal(0)


func test_build_steps_are_counted_and_the_last_one_finishes() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	assert_dict(WorkshopRules.build_state(save, _track)).is_equal({"step": 0, "done": false})
	assert_bool(WorkshopRules.finish_step(save, _track)).is_false()
	assert_int(WorkshopRules.build_state(save, _track)["step"]).is_equal(1)
	assert_bool(WorkshopRules.finish_step(save, _track)).is_false()
	assert_bool(WorkshopRules.finish_step(save, _track)).is_true()
	assert_bool(WorkshopRules.is_built(save, _track)).is_true()
	assert_bool(WorkshopRules.finish_step(save, _track)).is_false() # nothing after done
	assert_int(WorkshopRules.build_state(save, _track)["step"]).is_equal(3)


func test_the_elevator_keeps_zone_4_closed_until_it_is_built() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	var builds: Array[BuildProject] = [_track, _elevator]
	var nowhere: Callable = func(_zone: int) -> bool: return false
	assert_array(WorkshopRules.locked_zones(save, builds, nowhere)).contains_exactly([4])
	for i: int in _elevator.step_count():
		WorkshopRules.finish_step(save, _elevator)
	assert_array(WorkshopRules.locked_zones(save, builds, nowhere)).is_empty()


func test_a_child_already_digging_in_zone_4_keeps_it() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	var builds: Array[BuildProject] = [_elevator]
	var in_zone_4: Callable = func(zone: int) -> bool: return zone == 4
	assert_array(WorkshopRules.locked_zones(save, builds, in_zone_4)).is_empty()


func test_a_record_at_the_last_step_counts_as_built_even_without_done() -> void:
	# A build whose step list shrank, or an edited save: the build screen must never index past the steps.
	var save: Dictionary = SaveSchema.new_profile("t")
	save["workshop"]["builds"]["cart_track"] = {"step": _track.step_count(), "done": false}
	assert_bool(WorkshopRules.is_built(save, _track)).is_true()
	assert_bool(WorkshopRules.finish_step(save, _track)).is_false()
	save["workshop"]["builds"]["cart_track"] = {"step": _track.step_count() + 5, "done": false}
	assert_dict(WorkshopRules.build_state(save, _track)).is_equal({"step": _track.step_count(), "done": true})
