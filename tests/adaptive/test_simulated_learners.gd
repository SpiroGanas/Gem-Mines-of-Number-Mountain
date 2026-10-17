# Simulated learners (Phase 1 plan, Sprint 6): computer players run through the real engine, the
# real generators and the real answer inputs' guessing odds, with a fake clock for the days.
# These outcomes must keep passing; changing BKT values or mastery thresholds needs Spiro.
#
#   random guesser   right only by luck (the input's chance)   never masters anything in 2,000 rocks
#   fast learner     right 95% of the time                     masters all of Zone 1 in 2 days
#   average learner  70% right, rising with practice           masters Zone 1 in a few weeks of play
#   slow learner     50% right, rising slowly                  keeps making progress, never stuck
#   forgetter        fast, then 40% right once mastered        a failed review pulls the skill back
class_name SimulatedLearnersTest
extends GdUnitTestSuite

const GUESSER_ROCKS: int = 2000
const ROCKS_PER_DAY: int = 40
const FAST_FIRST_DAY_CAP: int = 160
const FAST_ROCK_BUDGET: int = 190

var _catalog: SkillCatalog
var _zone1: Array[StringName] = []


func before() -> void:
	_catalog = SkillCatalog.load_all()
	for skill: Skill in _catalog.skills_in_zone(1):
		_zone1.append(skill.id)


## A fresh engine on a fresh profile with a fake clock. `limit_to` keeps it to some skills.
func _engine(limit_to: Array[StringName] = []) -> AdaptiveEngine:
	return AdaptiveEngine.new(_catalog, BKT.load_defaults(), FakeClock.new(), limit_to)


## Plays up to `rocks` rocks. `learner(skill_id, chance, times_seen) -> float` is the chance of a
## right first answer; retries are right with that chance or by luck among the options left.
## `new_day(rocks_today, engine) -> bool` ends a day; `done(engine) -> bool` stops early.
## Returns {rocks, days, mastered: [[skill, day]], lapses: [skill], after_lapse: {skill: count}}.
func _play(engine: AdaptiveEngine, learner: Callable, rocks: int, seed_value: int, new_day: Callable, done: Callable = func(_e: AdaptiveEngine) -> bool: return false, latency_ms: int = 3000) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var clock: FakeClock = engine.clock
	var stats: Dictionary = {"rocks": 0, "days": 1, "mastered": [], "lapses": [], "after_lapse": {}}
	engine.skill_mastered.connect(func(id: StringName, _first: bool) -> void: stats["mastered"].append([id, stats["days"]]))
	engine.skill_flagged.connect(func(id: StringName) -> void: stats["lapses"].append(id))
	var seen: Dictionary = {}
	var today_rocks: int = 0
	for rock: int in rocks:
		if today_rocks > 0 and new_day.call(today_rocks, engine):
			clock.advance_days(1)
			engine.scheduler.reset_session()
			stats["days"] += 1
			today_rocks = 0
		var problem: Problem = engine.next_problem(rng)
		var id: StringName = problem.skill_id
		if stats["lapses"].has(id):
			stats["after_lapse"][id] = int(stats["after_lapse"].get(id, 0)) + 1
		var times: int = int(seen.get(id, 0))
		seen[id] = times + 1
		var chance: float = AnswerPanel.chance_for(problem)
		var p: float = learner.call(id, chance, times)
		var correct: bool = rng.randf() < p
		engine.record_answer(id, correct, 0, chance, latency_ms)
		var misses: int = 0
		while not correct:
			misses += 1
			var retry: float = AnswerPanel.chance_for(problem, misses)
			correct = misses >= 6 or rng.randf() < maxf(p, retry)
			engine.record_answer(id, correct, misses, retry, latency_ms)
		today_rocks += 1
		stats["rocks"] = rock + 1
		if done.call(engine):
			break
	return stats


func _all_mastered(engine: AdaptiveEngine, ids: Array[StringName]) -> bool:
	var mastered: Array[StringName] = engine.mastered()
	for id: StringName in ids:
		if not mastered.has(id):
			return false
	return true


func _every_day(count: int) -> Callable:
	return func(today: int, _engine: AdaptiveEngine) -> bool: return today >= count


# --- Random guesser --------------------------------------------------------------------------


func test_a_random_guesser_never_masters_anything_in_2000_rocks() -> void:
	var guesser: Callable = func(_id: StringName, chance: float, _times: int) -> float: return chance
	for seed_value: int in [1, 2, 3]:
		var engine: AdaptiveEngine = _engine()
		var stats: Dictionary = _play(engine, guesser, GUESSER_ROCKS, seed_value, _every_day(ROCKS_PER_DAY))
		print("guesser seed %d: %d rocks over %d days, mastered %s, frontier %s" % [seed_value, stats["rocks"], stats["days"], stats["mastered"], engine.frontier()])
		assert_int(stats["rocks"]).is_equal(GUESSER_ROCKS)
		assert_array(stats["mastered"]).override_failure_message("seed %d: the guesser mastered %s" % [seed_value, stats["mastered"]]).is_empty()
		assert_array(engine.mastered()).is_empty()


# --- Fast learner ----------------------------------------------------------------------------


func test_a_fast_learner_masters_all_of_zone_1_in_two_days() -> void:
	var fast: Callable = func(_id: StringName, _chance: float, _times: int) -> float: return 0.95
	# Day one lasts until nothing new can be learned today (every open skill is resting), as a
	# long first session would; day two confirms.
	var day_ends: Callable = func(today: int, engine: AdaptiveEngine) -> bool:
		return today >= FAST_FIRST_DAY_CAP or engine.scheduler.practice_pool(engine.skills(), engine.clock.today()).is_empty()
	for seed_value: int in [1, 2, 3, 4, 5]:
		var engine: AdaptiveEngine = _engine(_zone1)
		var stats: Dictionary = _play(engine, fast, 400, seed_value, day_ends, func(e: AdaptiveEngine) -> bool: return _all_mastered(e, _zone1))
		print("fast seed %d: %d rocks over %d days" % [seed_value, stats["rocks"], stats["days"]])
		assert_bool(_all_mastered(engine, _zone1)).override_failure_message("seed %d mastered %d of 17" % [seed_value, engine.mastered().size()]).is_true()
		assert_int(stats["days"]).is_less_equal(2)
		assert_int(stats["rocks"]).is_less_equal(FAST_ROCK_BUDGET)
		for entry: Array in stats["mastered"]:
			assert_int(entry[1]).override_failure_message("%s mastered on day one" % entry[0]).is_greater_equal(2)


# --- Average and slow learners ------------------------------------------------------------------


func test_an_average_learner_masters_zone_1_within_a_few_weeks_of_play() -> void:
	var average: Callable = func(_id: StringName, _chance: float, times: int) -> float: return minf(0.95, 0.7 + 0.02 * times)
	for seed_value: int in [1, 2]:
		var engine: AdaptiveEngine = _engine(_zone1)
		var stats: Dictionary = _play(engine, average, 1200, seed_value, _every_day(ROCKS_PER_DAY), func(e: AdaptiveEngine) -> bool: return _all_mastered(e, _zone1), 5000)
		print("average seed %d: %d rocks over %d days, mastered %d" % [seed_value, stats["rocks"], stats["days"], engine.mastered().size()])
		assert_bool(_all_mastered(engine, _zone1)).is_true()


func test_a_slow_learner_keeps_making_progress() -> void:
	var slow: Callable = func(_id: StringName, _chance: float, times: int) -> float: return minf(0.9, 0.5 + 0.01 * times)
	var engine: AdaptiveEngine = _engine(_zone1)
	var stats: Dictionary = _play(engine, slow, 1600, 7, _every_day(ROCKS_PER_DAY), func(_e: AdaptiveEngine) -> bool: return false, 7000)
	print("slow: %d rocks over %d days, mastered %d, frontier %d" % [stats["rocks"], stats["days"], engine.mastered().size(), engine.frontier().size()])
	assert_int(engine.mastered().size()).is_greater_equal(5)


# --- Forgetter ----------------------------------------------------------------------------------


func test_a_forgetter_is_pulled_back_into_practice_by_a_failed_review() -> void:
	var engine: AdaptiveEngine = _engine(_zone1)
	var forgetter: Callable = func(id: StringName, _chance: float, _times: int) -> float:
		var record: Dictionary = engine.record_for(id)
		return 0.4 if record["mastered_at"] != null else 0.95
	var stats: Dictionary = _play(engine, forgetter, 800, 11, _every_day(ROCKS_PER_DAY))
	print("forgetter: lapses %s, practice after lapse %s" % [stats["lapses"], stats["after_lapse"]])
	assert_array(stats["lapses"]).is_not_empty()
	var pulled_back: bool = false
	for id: StringName in stats["lapses"]:
		pulled_back = pulled_back or int(stats["after_lapse"].get(id, 0)) >= 2
		assert_bool(engine.record_for(id)["mastered_at"] != null).is_true()
	assert_bool(pulled_back).override_failure_message("no lapsed skill came back for practice").is_true()
