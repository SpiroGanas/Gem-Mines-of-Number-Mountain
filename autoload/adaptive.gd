## Adaptive autoload: picks every rock's problem and learns from every answer (Phase 1 plan,
## "Adaptive engine"). The rules live in scripts/adaptive/ (AdaptiveEngine, Scheduler, BKT,
## Placement), which are pure and tested by the simulated learners; this script connects them to
## the save (SaveSystem.data()["skills"] and ["placement"]) and to the attempt log.
##
## The mine calls next_problem() when a rock is picked and record() after every answer. Rewards
## and the parent dashboard listen to skill_mastered and skill_flagged.
extends Node

signal skill_mastered(skill_id: StringName, first_time: bool)
signal skill_flagged(skill_id: StringName)
## The placement quest ended; `passed` are the skills it marked as already known.
signal placement_finished(passed: Array[StringName])

## The time source. Tests replace it with tests/helpers/fake_clock.gd through use_clock().
var clock: GameClock = GameClock.new()
var engine: AdaptiveEngine
var session_id: String = ""

var _catalog: SkillCatalog
var _placement: Placement


func _ready() -> void:
	_catalog = SkillCatalog.load_all()
	engine = AdaptiveEngine.new(_catalog, BKT.load_defaults(), clock)
	engine.skills_source = func() -> Dictionary: return SaveSystem.data()["skills"]
	engine.skill_mastered.connect(skill_mastered.emit)
	engine.skill_flagged.connect(skill_flagged.emit)
	SaveSystem.profile_loaded.connect(_on_profile_loaded)


func catalog() -> SkillCatalog:
	return _catalog


func use_clock(new_clock: GameClock) -> void:
	clock = new_clock
	engine.clock = new_clock


## Starts a play session: a new session id for the attempt log and a fresh interleave set.
func start_session() -> String:
	session_id = "s%d" % clock.now_unix()
	engine.scheduler.reset_session()
	return session_id


func has_session() -> bool:
	return session_id != ""


func end_session() -> void:
	session_id = ""


## The next rock's problem. In the placement quest it probes the quest's current skill.
func next_problem(rng: RandomNumberGenerator, only: Array[StringName] = []) -> Problem:
	if not has_session():
		start_session()
	if only.is_empty() and placement_active():
		return engine.problem_for(_placement.current_skill(), rng)
	return engine.next_problem(rng, only)


## The easier problem for hint rung 4.
func easier_problem(problem: Problem, rng: RandomNumberGenerator) -> Problem:
	return engine.easier_problem(problem, rng)


## Logs one answer to attempts.jsonl and learns from it. `chance` is how likely a blind guess was
## to be right (AnswerPanel.chance_for). Returns the engine's {mastered, first_time, lapsed}.
func record(attempt: Attempt, chance: float) -> Dictionary:
	if not has_session():
		start_session()
	if attempt.session_id == "":
		attempt.session_id = session_id
	if attempt.ts == "":
		attempt.ts = clock.now_iso()
	SaveSystem.append_attempt(attempt)
	if placement_active() and attempt.skill_id == _placement.current_skill() and attempt.hints_used == 0:
		_placement.record(attempt.correct)
		_apply_placement()
		return {"mastered": false, "first_time": false, "lapsed": false}
	if placement_active():
		return {"mastered": false, "first_time": false, "lapsed": false} # a retry on a placement rock
	return engine.record_answer(attempt.skill_id, attempt.correct, attempt.hints_used, chance, attempt.latency_ms)


func flag_for_review(skill_id: StringName) -> void:
	engine.flag_for_review(skill_id)


func frontier() -> Array[StringName]:
	return engine.frontier()


func mastered() -> Array[StringName]:
	return engine.mastered()


## Flagged skills and skills with 3 or more misses in their last 5 first tries (from the log).
func struggling() -> Array[StringName]:
	return engine.struggling(SaveSystem.read_attempts()["entries"])


# --- Placement quest -----------------------------------------------------------------------------


## True until the child has finished the placement quest once (or a grown-up asks for a re-run).
func needs_placement() -> bool:
	return not bool(SaveSystem.data()["placement"].get("done", false))


func placement_active() -> bool:
	return _placement != null


## Starts the "survey the mountain" quest from the save's seed set.
func start_placement() -> void:
	var already: Array[StringName] = []
	for id: String in SaveSystem.data()["skills"]:
		if bool(SaveSystem.data()["skills"][id].get("placement_passed", false)):
			already.append(StringName(id))
	var seed_name: String = str(SaveSystem.data()["placement"].get("seed", ""))
	_placement = Placement.new(_catalog, engine.scheduler.playable, seed_name, clock.now_unix(), already)
	if _placement.is_done(clock.now_unix()):
		_finish_placement()


## The parent area's "re-run placement": the next dig starts with the quest again.
func rerun_placement() -> void:
	SaveSystem.data()["placement"]["done"] = false
	SaveSystem.save_now()


func placement() -> Placement:
	return _placement


func _apply_placement() -> void:
	engine.apply_placement(_placement.passed)
	if _placement.is_done(clock.now_unix()):
		_finish_placement()


## Another profile was loaded: an unfinished quest or session belonged to the old one.
func _on_profile_loaded() -> void:
	_placement = null
	end_session()


func _finish_placement() -> void:
	var passed: Array[StringName] = _placement.passed.duplicate()
	_placement = null
	SaveSystem.data()["placement"]["done"] = true
	SaveSystem.save_now()
	placement_finished.emit(passed)
