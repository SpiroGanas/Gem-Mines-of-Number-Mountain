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


# --- Generic placement from a starting grade (Phase 3, Sprint 23; plan section 3.6) ------------------


## Priors per zone for a grade, as seed_from_grade gives them (every skill of a zone has the same).
func _zone_priors(grade: int) -> Dictionary:
	var priors: Dictionary[String, float] = Placement.seed_from_grade(grade, _catalog)
	var zones: Dictionary = {}
	for id: String in priors:
		var zone: int = _catalog.skill(StringName(id)).zone
		assert_bool(not zones.has(zone) or is_equal_approx(zones[zone], priors[id])).override_failure_message(id).is_true()
		zones[zone] = priors[id]
	return zones


func test_seed_from_grade_follows_the_plan_table() -> void:
	assert_dict(_zone_priors(0)).is_equal({1: 0.2})
	assert_dict(_zone_priors(1)).is_equal({1: 0.5, 2: 0.2})
	assert_dict(_zone_priors(2)).is_equal({1: 0.7, 2: 0.7, 3: 0.4})
	assert_dict(_zone_priors(3)).is_equal({1: 0.85, 2: 0.85, 3: 0.85, 4: 0.5, 5: 0.3})
	for grade: int in [4, 5, 6]: # "grade 3+"
		assert_dict(_zone_priors(grade)).is_equal(_zone_priors(3))
	assert_int(Placement.seed_from_grade(1, _catalog).size()).is_equal(_catalog.skills_in_zone(1).size() + _catalog.skills_in_zone(2).size())


func test_every_grade_probe_is_a_real_skill_and_grade_seeds_start_the_quest_there() -> void:
	for grade: int in range(Profile.MIN_GRADE, Profile.MAX_GRADE + 1):
		var seed_name: String = Placement.grade_seed_name(grade)
		assert_str(seed_name).is_equal("grade_%d" % grade)
		var probes: Array[StringName] = Placement.probes_for(seed_name)
		assert_array(probes).is_not_empty()
		for id: StringName in probes:
			assert_bool(_catalog.has_skill(id)).override_failure_message(String(id)).is_true()
		var placement: Placement = Placement.new(_catalog, _all(), seed_name, 0)
		assert_str(placement.current_skill()).is_equal(String(probes[0]))
	assert_str(Placement.new(_catalog, _all(), "grade_3", 0).current_skill()).is_equal("add.to_100.regroup")
	assert_str(Placement.new(_catalog, _all(), SEED, 0).current_skill()).is_equal("count.to_120.read") # Charlie's Star seed stays


## Plan section 3.6: a grade-K child who only guesses, placed at grade 3, is back among zone 1 skills
## within 12 problems: the quest probes a zone-1 skill by then, and the frontier the quest leaves has
## zone-1 skills on it. Fifty seeded guessers, right one time in four.
func test_a_random_guesser_placed_at_grade_3_falls_back_to_zone_1_within_12_problems() -> void:
	for seed_value: int in range(1, 51):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var placement: Placement = Placement.new(_catalog, _all(), Placement.grade_seed_name(3), 0)
		var reached_zone_1_at: int = -1
		var now: int = 0
		while not placement.is_done(now):
			if reached_zone_1_at < 0 and _catalog.skill(placement.current_skill()).zone == 1:
				reached_zone_1_at = placement.problems_given()
			placement.record(rng.randf() < 0.25)
			now += 15
		assert_int(reached_zone_1_at).override_failure_message("seed %d never probed zone 1" % seed_value).is_between(0, 12)
		var engine: AdaptiveEngine = AdaptiveEngine.new(_catalog, BKT.load_defaults(), FakeClock.new())
		for id: String in Placement.seed_from_grade(3, _catalog):
			SkillRecord.ensure(engine.skills(), StringName(id), Placement.seed_from_grade(3, _catalog)[id])
		engine.apply_placement(placement.passed)
		var zone_1_frontier: Array[StringName] = []
		for id: StringName in engine.frontier():
			if _catalog.skill(id).zone == 1:
				zone_1_frontier.append(id)
		assert_array(zone_1_frontier).override_failure_message("seed %d left no zone 1 frontier" % seed_value).is_not_empty()


## Plan section 3.6: a fast learner placed at grade K reaches zone 2 within the quest.
func test_a_fast_learner_placed_at_grade_k_reaches_zone_2_within_the_quest() -> void:
	var now: int = 0
	var placement: Placement = Placement.new(_catalog, _all(), Placement.grade_seed_name(0), now)
	while not placement.is_done(now):
		placement.record(true)
		now += 15
	assert_int(now).is_less_equal(Placement.TIME_LIMIT_SECONDS)
	var zone_2_passed: Array[StringName] = []
	for id: StringName in placement.passed:
		if _catalog.skill(id).zone == 2:
			zone_2_passed.append(id)
	assert_array(zone_2_passed).is_not_empty()
