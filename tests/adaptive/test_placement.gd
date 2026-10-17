# Mirrors scripts/adaptive/placement.gd: the "survey the mountain" quest.
class_name PlacementTest
extends GdUnitTestSuite

const SEED: String = "star_2026_09"

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


## Every skill in the curriculum, so the quest can be tested apart from which generators exist.
func _all() -> Array[StringName]:
	return _catalog.ids()


## Answers every probe with `answer.call(skill_id)` until the quest ends. Returns the placement.
func _run(answer: Callable, playable: Array[StringName] = [], seconds_per_problem: int = 15) -> Placement:
	var now: int = 0
	var placement: Placement = Placement.new(_catalog, playable if not playable.is_empty() else _all(), SEED, now)
	while not placement.is_done(now):
		placement.record(answer.call(placement.current_skill()))
		now += seconds_per_problem
	return placement


func test_charlies_quest_starts_with_his_star_report_skills() -> void:
	var placement: Placement = Placement.new(_catalog, _all(), SEED, 0)
	assert_str(placement.current_skill()).is_equal("count.to_120.read")


func test_two_right_answers_pass_a_skill_and_everything_below_it() -> void:
	var placement: Placement = Placement.new(_catalog, _all(), SEED, 0)
	placement.record(true)
	assert_str(placement.current_skill()).is_equal("count.to_120.read") # two problems per probe
	placement.record(true)
	assert_array(placement.passed).contains([&"count.to_120.read", &"count.to_20.objects"])
	assert_str(placement.current_skill()).is_equal("pv.tens_ones.build") # the next seed


func test_a_miss_probes_the_prerequisites_instead() -> void:
	var placement: Placement = Placement.new(_catalog, _all(), SEED, 0)
	placement.record(false)
	assert_array(placement.failed).contains_exactly([&"count.to_120.read"])
	assert_array(placement.passed).is_empty()
	# The other seeds come first; count.to_20.objects (the missed skill's prerequisite) waits its turn.
	var probed: Array[StringName] = []
	while placement.current_skill() != &"" and not probed.has(&"count.to_20.objects"):
		probed.append(placement.current_skill())
		placement.record(false)
	assert_bool(probed.has(&"count.to_20.objects")).is_true()


func test_a_fast_learner_places_into_zone_2() -> void:
	var placement: Placement = _run(func(_id: StringName) -> bool: return true)
	assert_bool(placement.passed.has(&"add.to_10.sums")).is_true()
	assert_bool(placement.passed.has(&"pv.tens_ones.build")).is_true()
	var zone2_open: Array[StringName] = []
	for skill: Skill in _catalog.skills_in_zone(2):
		var open: bool = not placement.passed.has(skill.id)
		for prereq: StringName in skill.prereqs:
			open = open and placement.passed.has(prereq)
		if open:
			zone2_open.append(skill.id)
	assert_array(zone2_open).is_not_empty()


func test_a_learner_who_knows_nothing_yet_ends_quickly_with_nothing_passed() -> void:
	var placement: Placement = _run(func(_id: StringName) -> bool: return false)
	assert_array(placement.passed).is_empty()
	assert_bool(placement.failed.has(&"count.to_20.objects")).is_true()
	assert_int(placement.problems_given()).is_less(10)


func test_the_quest_stops_at_ten_minutes() -> void:
	var placement: Placement = _run(func(_id: StringName) -> bool: return true, [], 60)
	assert_int(placement.problems_given()).is_equal(Placement.TIME_LIMIT_SECONDS / 60)


func test_the_quest_never_gives_more_than_the_problem_limit() -> void:
	var placement: Placement = _run(func(_id: StringName) -> bool: return true, [], 0)
	assert_int(placement.problems_given()).is_less_equal(Placement.MAX_PROBLEMS)


func test_only_playable_skills_are_probed() -> void:
	var zone1: Array[StringName] = []
	for skill: Skill in _catalog.skills_in_zone(1):
		zone1.append(skill.id)
	var probed: Dictionary = {}
	var always_right: Callable = func(id: StringName) -> bool:
		probed[id] = true
		return true
	var placement: Placement = _run(always_right, zone1)
	for id: StringName in probed:
		assert_int(_catalog.skill(id).zone).is_equal(1)
	assert_bool(placement.passed.has(&"add.to_10.sums")).is_false()


func test_skills_already_passed_are_not_probed_again() -> void:
	var already: Array[StringName] = [&"count.to_120.read", &"count.to_20.objects"]
	var placement: Placement = Placement.new(_catalog, _all(), SEED, 0, already)
	assert_str(placement.current_skill()).is_equal("pv.tens_ones.build")


func test_an_unknown_seed_starts_at_the_root() -> void:
	var placement: Placement = Placement.new(_catalog, _all(), "no_such_seed", 0)
	assert_str(placement.current_skill()).is_equal("count.to_20.objects")


func test_ancestors_follow_every_prerequisite_path() -> void:
	var placement: Placement = Placement.new(_catalog, _all(), SEED, 0)
	var below: Array[StringName] = placement.ancestors(&"pv.regroup.untrade")
	assert_array(below).contains_exactly_in_any_order([&"pv.regroup.trade_ten", &"pv.tens_ones.build", &"count.to_120.read", &"count.to_20.objects"])
