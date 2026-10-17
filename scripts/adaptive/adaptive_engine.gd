## The adaptive engine's rules, with no autoload and no files: it reads and writes the save's
## `skills` dictionary through `skills_source`, so the simulated learners in tests/adaptive/ run
## exactly the code the game runs. The Adaptive autoload wraps it with the save and the attempt log.
##
## Evidence policy (docs/decisions.md, Sprint 6). Each rock is one learning opportunity:
##   - the FIRST answer on a rock is full evidence: BKT updates (with the guess raised to the item's
##     chance), the guessing guard adds its evidence, a correct one adds today to correct_days;
##   - a later correct answer (after hints) is partial evidence (BKT.update_with_hints);
##   - a later wrong answer adds nothing more: the first miss already said "not yet".
## Mastery needs P(L) >= 0.95, correct answers on 2 different days, better-than-guessing evidence,
## and for fact skills the hidden fluency check. A mastered skill comes back for review after 1, 3,
## 7, 21 and 60 days; a missed review flags it and sends it back to practice.
class_name AdaptiveEngine
extends RefCounted

## A skill met every mastery condition. `first_time` is false when it was mastered before, lapsed
## and was won back (Rewards gives the mastery gem only the first time).
signal skill_mastered(skill_id: StringName, first_time: bool)
## A skill needs attention: a missed review, or the fourth hint rung on one rock.
signal skill_flagged(skill_id: StringName)

var catalog: SkillCatalog
var clock: GameClock
var scheduler: Scheduler
var defaults: Dictionary
## Returns the live skills dictionary (the save's "skills"). Tests pass their own.
var skills_source: Callable

var _own_skills: Dictionary = {}


func _init(skill_catalog: SkillCatalog, bkt_defaults: Dictionary, game_clock: GameClock, limit_to: Array[StringName] = []) -> void:
	catalog = skill_catalog
	defaults = bkt_defaults
	clock = game_clock
	scheduler = Scheduler.new(catalog, limit_to)
	skills_source = func() -> Dictionary: return _own_skills


func skills() -> Dictionary:
	return skills_source.call()


func params_for(skill_id: StringName) -> Dictionary:
	return BKT.params_for(defaults, catalog.skill(skill_id).bkt_type)


## The skill's record, created with its prior if new.
func record_for(skill_id: StringName) -> Dictionary:
	return SkillRecord.ensure(skills(), skill_id, params_for(skill_id)["prior"])


# --- Choosing problems ------------------------------------------------------------------------


## The next rock's problem. `only` (tests, debugging) restricts the choice to those skills.
func next_problem(rng: RandomNumberGenerator, only: Array[StringName] = []) -> Problem:
	var choice: Dictionary
	if only.is_empty():
		choice = scheduler.choose(skills(), clock.today(), rng)
	else:
		choice = {"skill_id": only[rng.randi_range(0, only.size() - 1)], "review": false}
	return problem_for(choice["skill_id"], rng, choice["review"])


## A problem of one skill at the representation its record calls for.
func problem_for(skill_id: StringName, rng: RandomNumberGenerator, review: bool = false, extra: Dictionary = {}) -> Problem:
	var skill: Skill = catalog.skill(skill_id)
	var overrides: Dictionary = {"representation": scheduler.representation_for(skill, record_for(skill_id), review)}
	overrides.merge(extra, true)
	return GeneratorRegistry.make_problem(skill, rng.randi(), overrides)


## The easier problem of hint rung 4: same skill and representation, difficulty one step down.
func easier_problem(problem: Problem, rng: RandomNumberGenerator) -> Problem:
	var easier: Dictionary = problem.hint_steps[3].get("easier_params", {"difficulty": -1}) if problem.hint_steps.size() > 3 else {"difficulty": -1}
	var overrides: Dictionary = {"representation": problem.representation}
	overrides.merge(easier, true)
	return GeneratorRegistry.make_problem(catalog.skill(problem.skill_id), rng.randi(), overrides)


# --- Recording answers -------------------------------------------------------------------------


## Applies one answer. `hints_used` is how many not-quite answers this rock had before it (0 = the
## first try). `chance` is how likely a blind guess was to be right (AnswerPanel.chance_for).
## Returns {mastered: bool, first_time: bool, lapsed: bool}.
func record_answer(skill_id: StringName, correct: bool, hints_used: int, chance: float, latency_ms: int) -> Dictionary:
	var result: Dictionary = {"mastered": false, "first_time": false, "lapsed": false}
	var record: Dictionary = record_for(skill_id)
	var params: Dictionary = BKT.with_chance(params_for(skill_id), chance)
	var today: String = clock.today()
	record["attempts"] = int(record["attempts"]) + 1
	if correct:
		record["correct"] = int(record["correct"]) + 1
	if hints_used > 0:
		if correct:
			record["p_learned"] = BKT.update_with_hints(float(record["p_learned"]), true, hints_used, params)
		return result
	var was_mastered: bool = SkillRecord.is_mastered(record)
	var review_due: bool = SkillRecord.is_due(record, today)
	record["p_learned"] = BKT.update(float(record["p_learned"]), correct, params)
	record["guess_evidence"] = maxf(SkillRecord.EVIDENCE_FLOOR, float(record["guess_evidence"]) + SkillRecord.evidence_of(correct, chance, params["slip"]))
	if correct:
		if not record["correct_days"].has(today):
			record["correct_days"].append(today)
		record["recent_latency_ms"].append(latency_ms)
		while record["recent_latency_ms"].size() > SkillRecord.LATENCIES_KEPT:
			record["recent_latency_ms"].pop_front()
	if was_mastered:
		if review_due and correct:
			var stage: int = mini(int(record["review_stage"]) + 1, SkillRecord.REVIEW_INTERVALS.size() - 1)
			record["review_stage"] = stage
			record["next_review_at"] = GameClock.add_days(today, SkillRecord.REVIEW_INTERVALS[stage])
		elif review_due:
			_lapse(record)
			result["lapsed"] = true
			skill_flagged.emit(skill_id)
		return result
	if correct and SkillRecord.is_ready_to_master(record, params, catalog.skill(skill_id).is_fact_skill):
		result["mastered"] = true
		result["first_time"] = record["mastered_at"] == null
		_master(record)
		skill_mastered.emit(skill_id, result["first_time"])
	return result


## Hint rung 4 (or a parent) flags a skill: it shows on the dashboard as needing help and goes to the
## front of practice. A mastered skill flagged this way goes back to practice like a missed review.
func flag_for_review(skill_id: StringName) -> void:
	var record: Dictionary = record_for(skill_id)
	if SkillRecord.is_mastered(record):
		_lapse(record)
	record["flagged_for_review"] = true
	skill_flagged.emit(skill_id)


## Marks skills placement-passed (P(L) raised to 0.85, never lowered, never mastered).
func apply_placement(passed: Array[StringName]) -> void:
	for id: StringName in passed:
		var record: Dictionary = record_for(id)
		record["placement_passed"] = true
		record["p_learned"] = maxf(float(record["p_learned"]), SkillRecord.PLACEMENT_P)


func _master(record: Dictionary) -> void:
	if record["mastered_at"] == null:
		record["mastered_at"] = clock.now_iso()
	record["flagged_for_review"] = false
	record["review_stage"] = 0
	record["next_review_at"] = GameClock.add_days(clock.today(), SkillRecord.REVIEW_INTERVALS[0])


## Back to practice: the skill must be won again on two new days.
func _lapse(record: Dictionary) -> void:
	record["flagged_for_review"] = true
	record["review_stage"] = 0
	record["next_review_at"] = null
	record["correct_days"] = []


# --- Reports -----------------------------------------------------------------------------------


func frontier() -> Array[StringName]:
	return scheduler.frontier(skills())


func mastered() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in scheduler.playable:
		if SkillRecord.is_mastered(scheduler.record_of(skills(), id)):
			result.append(id)
	return result


## Skills that need a grown-up's eye: flagged, or 3 or more misses in their last 5 first tries
## (`recent` is the attempt log, oldest first, as Attempt.to_json() dictionaries).
func struggling(recent: Array) -> Array[StringName]:
	var firsts: Dictionary = {}
	for entry: Dictionary in recent:
		if int(entry.get("hints_used", 0)) == 0:
			var id: String = str(entry.get("skill_id", ""))
			if not firsts.has(id):
				firsts[id] = []
			firsts[id].append(bool(entry.get("correct", false)))
	var result: Array[StringName] = []
	for id: StringName in catalog.ids():
		var record: Dictionary = scheduler.record_of(skills(), id)
		var last: Array = firsts.get(String(id), []).slice(-5)
		var misses: int = last.count(false)
		if bool(record.get("flagged_for_review", false)) or misses >= 3:
			result.append(id)
	return result
