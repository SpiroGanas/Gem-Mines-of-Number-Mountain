# Mirrors scripts/adaptive/scheduler.gd: frontier, resting skills, interleaving, the 70/30 review
# mix and representations. Days are plain strings, so no clock is needed here.
class_name SchedulerTest
extends GdUnitTestSuite

const DAY: String = "2026-12-07"
const NEXT_DAY: String = "2026-12-08"

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _zone1() -> Array[StringName]:
	var ids: Array[StringName] = []
	for skill: Skill in _catalog.skills_in_zone(1):
		ids.append(skill.id)
	return ids


func _secure(skills: Dictionary, id: StringName, day: String = DAY) -> Dictionary:
	var record: Dictionary = SkillRecord.ensure(skills, id, 0.3)
	record["p_learned"] = 0.97
	record["guess_evidence"] = SkillRecord.EVIDENCE_TO_MASTER + 1.0
	record["correct_days"] = [day]
	return record


func _master(skills: Dictionary, id: StringName, next_review: String = "2026-12-20") -> Dictionary:
	var record: Dictionary = _secure(skills, id)
	record["mastered_at"] = "2026-12-01T10:00:00Z"
	record["next_review_at"] = next_review
	return record


func test_a_new_miner_starts_at_the_one_root_skill() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog)
	assert_array(scheduler.frontier({})).contains_exactly([&"count.to_20.objects"])
	var choice: Dictionary = scheduler.choose({}, DAY, _rng())
	assert_str(choice["skill_id"]).is_equal("count.to_20.objects")
	assert_bool(choice["review"]).is_false()


func test_only_skills_with_a_built_generator_or_inside_the_limit_are_offered() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog)
	for id: StringName in scheduler.playable:
		assert_bool(GeneratorRegistry.callable_for(_catalog.skill(id)).is_valid()).is_true()
	var limited: Scheduler = Scheduler.new(_catalog, [&"count.to_20.objects", &"cmp.to_20.more_less"])
	assert_array(limited.playable).contains_exactly([&"count.to_20.objects", &"cmp.to_20.more_less"])


func test_a_secure_mastered_or_placement_passed_prerequisite_opens_its_successors() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_secure(skills, &"count.to_20.objects")
	var open: Array[StringName] = scheduler.frontier(skills)
	assert_array(open).contains([&"count.to_20.objects", &"count.to_120.read", &"cmp.to_20.more_less"])
	assert_bool(open.has(&"count.to_120.next")).is_false() # needs count.to_120.read first
	SkillRecord.ensure(skills, &"count.to_120.read", 0.3)["placement_passed"] = true
	assert_bool(scheduler.frontier(skills).has(&"count.to_120.next")).is_true()


func test_mastered_skills_leave_the_frontier() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_master(skills, &"count.to_20.objects")
	assert_bool(scheduler.frontier(skills).has(&"count.to_20.objects")).is_false()
	assert_bool(scheduler.frontier(skills).has(&"count.to_120.read")).is_true()


func test_a_secure_skill_rests_for_the_rest_of_the_day_it_was_won() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_secure(skills, &"count.to_20.objects")
	assert_bool(scheduler.is_resting(skills, &"count.to_20.objects", DAY)).is_true()
	assert_bool(scheduler.practice_pool(skills, DAY).has(&"count.to_20.objects")).is_false()
	assert_bool(scheduler.practice_pool(skills, NEXT_DAY).has(&"count.to_20.objects")).is_true() # confirm it tomorrow


func test_when_everything_open_is_resting_the_child_still_gets_rocks() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, [&"count.to_20.objects"])
	var skills: Dictionary = {}
	_secure(skills, &"count.to_20.objects")
	assert_array(scheduler.practice_pool(skills, DAY)).is_empty()
	assert_str(scheduler.choose(skills, DAY, _rng())["skill_id"]).is_equal("count.to_20.objects")


func test_practice_interleaves_up_to_three_skills_and_never_gives_one_three_times_running() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_secure(skills, &"count.to_20.objects", "2026-12-01")
	_secure(skills, &"count.to_120.read", "2026-12-01")
	var rng: RandomNumberGenerator = _rng(3)
	var picks: Array[StringName] = []
	for rock: int in 300:
		picks.append(scheduler.choose(skills, DAY, rng)["skill_id"])
	for index: int in range(2, picks.size()):
		assert_bool(picks[index] == picks[index - 1] and picks[index] == picks[index - 2]).override_failure_message("rock %d repeats %s" % [index, picks[index]]).is_false()
	var distinct: Dictionary = {}
	for id: StringName in picks:
		distinct[id] = true
	assert_int(distinct.size()).is_equal(Scheduler.INTERLEAVE) # the active set, not the whole frontier
	assert_bool(distinct.size() > 1).is_true()


func test_flagged_skills_are_practised_first() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_secure(skills, &"count.to_20.objects", "2026-12-01")
	_secure(skills, &"count.to_120.read", "2026-12-01")
	SkillRecord.ensure(skills, &"pv.tens_ones.build", 0.3)["flagged_for_review"] = true
	assert_str(scheduler.practice_pool(skills, DAY)[0]).is_equal("pv.tens_ones.build")


func test_about_thirty_percent_of_rocks_are_review_while_reviews_are_due() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_master(skills, &"count.to_20.objects", DAY)
	_master(skills, &"count.to_120.read", "2026-12-05")
	var reviews: int = 0
	var rng: RandomNumberGenerator = _rng(5)
	for rock: int in 30:
		if scheduler.choose(skills, DAY, rng)["review"]:
			reviews += 1
	assert_int(reviews).is_between(8, 10)
	assert_int(scheduler.review_count()).is_equal(reviews)
	scheduler.reset_session()
	assert_int(scheduler.review_count()).is_equal(0)


func test_the_most_overdue_review_comes_first_and_only_due_ones_count() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, _zone1())
	var skills: Dictionary = {}
	_master(skills, &"count.to_20.objects", DAY)
	_master(skills, &"count.to_120.read", "2026-12-01")
	_master(skills, &"cmp.to_20.more_less", "2026-12-30")
	assert_array(scheduler.due_reviews(skills, DAY)).contains_exactly([&"count.to_120.read", &"count.to_20.objects"])
	var first: Dictionary = scheduler.choose(skills, DAY, _rng())
	assert_bool(first["review"]).is_true()
	assert_str(first["skill_id"]).is_equal("count.to_120.read")


func test_with_nothing_to_practise_due_reviews_fill_the_wall() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog, [&"count.to_20.objects"])
	var skills: Dictionary = {}
	_master(skills, &"count.to_20.objects", DAY)
	for rock: int in 5:
		var choice: Dictionary = scheduler.choose(skills, DAY, _rng(rock))
		assert_bool(choice["review"]).is_true()


func test_representations_go_concrete_to_abstract_as_the_skill_is_learned() -> void:
	var scheduler: Scheduler = Scheduler.new(_catalog)
	var skill: Skill = _catalog.skill(&"pv.tens_ones.read") # concrete, abstract
	var record: Dictionary = SkillRecord.fresh(0.3)
	assert_str(scheduler.representation_for(skill, record, false)).is_equal("concrete")
	record["p_learned"] = 0.8
	assert_str(scheduler.representation_for(skill, record, false)).is_equal("abstract")
	record["p_learned"] = 0.1
	assert_str(scheduler.representation_for(skill, record, true)).is_equal("abstract") # review uses the last
	var single: Skill = _catalog.skill(&"count.to_20.objects")
	assert_str(scheduler.representation_for(single, record, false)).is_equal("concrete")
