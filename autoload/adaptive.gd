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
## A new play session began (the first rock of the day, or after a long break or a wind-down).
signal session_started(session_id: String)

## A gap this long without an answer ends a session; the next rock starts a new one.
const SESSION_GAP_SECONDS: int = 1800

## The time source. Tests replace it with tests/helpers/fake_clock.gd through use_clock().
var clock: GameClock = GameClock.new()
var engine: AdaptiveEngine
var session_id: String = ""
var session_started_unix: int = 0

var _last_activity_unix: int = 0
var _session_skills: Dictionary = {}

var _catalog: SkillCatalog
var _placement: Placement
var _builds: Array[BuildProject] = []


func _ready() -> void:
	_catalog = SkillCatalog.load_all()
	engine = AdaptiveEngine.new(_catalog, BKT.load_defaults(), clock, [], BKT.load_fitted())
	engine.skills_source = func() -> Dictionary: return SaveSystem.data()["skills"]
	_builds = BuildProject.load_all()
	engine.scheduler.locked_zones = locked_zones
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
	session_started_unix = clock.now_unix()
	_last_activity_unix = session_started_unix
	_session_skills.clear()
	engine.scheduler.reset_session()
	session_started.emit(session_id)
	return session_id


## True while a session is running: started, and no break longer than SESSION_GAP_SECONDS since.
func has_session() -> bool:
	return session_id != "" and clock.now_unix() - _last_activity_unix < SESSION_GAP_SECONDS


func end_session() -> void:
	session_id = ""


## Seconds since the session started (0 with no session).
func session_seconds() -> int:
	return clock.now_unix() - session_started_unix if has_session() else 0


## The parent's soft limit has been reached (settings.session_minutes). The mine winds down at the
## next rock boundary; nothing is ever shown counting down.
func wind_down_due() -> bool:
	var minutes: int = int(SaveSystem.data()["settings"].get("session_minutes", 20))
	return has_session() and session_seconds() >= minutes * 60


## How many different skills were practised this session (for the recap).
func skills_practised() -> int:
	return _session_skills.size()


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
## An attempt flagged low_confidence_rejected (a handwriting reading the child turned down) is only
## logged: it changes nothing the engine knows.
func record(attempt: Attempt, chance: float) -> Dictionary:
	if not has_session():
		start_session()
	if attempt.session_id == "":
		attempt.session_id = session_id
	if attempt.ts == "":
		attempt.ts = clock.now_iso()
	SaveSystem.append_attempt(attempt)
	_last_activity_unix = clock.now_unix()
	if attempt.low_confidence_rejected:
		# "Try again" to the slate's "Did you write 47?": logged for the dashboard, but it is not an
		# answer, so it never reaches BKT, the placement quest or the guessing guard (CLAUDE.md).
		return {"mastered": false, "first_time": false, "lapsed": false}
	_session_skills[attempt.skill_id] = true
	if placement_active() and attempt.skill_id == _placement.current_skill() and attempt.hints_used == 0:
		_placement.record(attempt.correct)
		_apply_placement()
		return {"mastered": false, "first_time": false, "lapsed": false}
	if placement_active():
		return {"mastered": false, "first_time": false, "lapsed": false} # a retry on a placement rock
	return engine.record_answer(attempt.skill_id, attempt.correct, attempt.hints_used, chance, attempt.latency_ms)


## Zones a build project still keeps out of the dig (Sprint 16: the balance elevator opens Zone 4).
func locked_zones() -> Array[int]:
	return WorkshopRules.locked_zones(SaveSystem.data(), _builds, zone_has_answers)


## True when the child has answered at least one problem of `zone`.
func zone_has_answers(zone: int) -> bool:
	var skills: Dictionary = SaveSystem.data()["skills"]
	for id: String in skills:
		if _catalog.has_skill(StringName(id)) and _catalog.skill(StringName(id)).zone == zone and int(skills[id].get("attempts", 0)) > 0:
			return true
	return false


## True when a skill opens the skills after it (mastered, placement-passed or secure): what makes a
## recipe or a build appear in the workshop.
func opens_successors(skill_id: StringName) -> bool:
	return SkillRecord.opens_successors(engine.scheduler.record_of(SaveSystem.data()["skills"], skill_id))


# --- Deep Dig and Challenge Door (Sprint 19) ---------------------------------------------------------


## This week's Deep Dig: MotivationRules.DEEP_DIG_PROBLEMS review problems spread over the mastered
## skills. Deterministic for the same rng state and mastered set.
func build_deep_dig(rng: RandomNumberGenerator) -> Array[Problem]:
	var problems: Array[Problem] = []
	for skill_id: StringName in MotivationRules.deep_dig_skills(mastered(), rng.randi()):
		problems.append(engine.problem_for(skill_id, rng, true))
	return problems


func deep_dig_available() -> bool:
	return MotivationRules.deep_dig_available(SaveSystem.data(), clock.today(), mastered().size())


## The Challenge Door's problems for a skill: three, or more for a skill whose questions are easy to
## guess (MotivationRules.CHALLENGE_MAX_LUCK).
func challenge(skill_id: StringName, rng: RandomNumberGenerator) -> Array[Problem]:
	return engine.challenge_problems(skill_id, rng, MotivationRules.CHALLENGE_PROBLEMS, MotivationRules.CHALLENGE_MAX_LUCK, MotivationRules.CHALLENGE_MOST, AnswerPanel.chance_for)


## The skill the Challenge Door offers now, or &"": a frontier skill the child has practised, whose
## door is not closed today, the one closest to mastery first. None during the placement quest.
func challenge_candidate() -> StringName:
	if placement_active():
		return &""
	var best: StringName = &""
	var best_p: float = -1.0
	for id: StringName in frontier():
		var record: Dictionary = engine.scheduler.record_of(SaveSystem.data()["skills"], id)
		if int(record.get("attempts", 0)) < 1 or MotivationRules.door_closed(SaveSystem.data(), id, clock.today()):
			continue
		if float(record.get("p_learned", 0.0)) > best_p:
			best = id
			best_p = float(record.get("p_learned", 0.0))
	return best


## Three right at the door: the skill is mastered (evidence "challenge").
func pass_challenge(skill_id: StringName) -> void:
	MotivationRules.record_door_passed(SaveSystem.data(), skill_id)
	engine.master_by_challenge(skill_id)
	SaveSystem.save_now()


## A miss at the door: it closes until tomorrow. Not a wrong answer: BKT never hears of it.
func fail_challenge(skill_id: StringName) -> void:
	MotivationRules.close_door(SaveSystem.data(), skill_id, clock.today())
	SaveSystem.save_now()


# --- Dashboard v2 (Sprint 21) -------------------------------------------------------------------------

const STATE_NOT_STARTED: StringName = &"not_started"
const STATE_PRACTICING: StringName = &"practicing"
const STATE_MASTERED: StringName = &"mastered"
const STATE_NEEDS_REVIEW: StringName = &"needs_review"


## Each playable skill's state for the parent's skill map, in curriculum order: needs_review (flagged:
## a missed review or the fourth hint), mastered, practicing (answered at least once) or not_started.
## The dashboard shows these and never works mastery out itself.
func skill_states() -> Dictionary:
	var states: Dictionary = {}
	for id: StringName in engine.scheduler.playable:
		states[id] = state_of(id)
	return states


func state_of(skill_id: StringName) -> StringName:
	var record: Dictionary = engine.scheduler.record_of(SaveSystem.data()["skills"], skill_id)
	if bool(record.get("flagged_for_review", false)):
		return STATE_NEEDS_REVIEW
	if SkillRecord.is_mastered(record):
		return STATE_MASTERED
	if int(record.get("attempts", 0)) > 0:
		return STATE_PRACTICING
	return STATE_NOT_STARTED


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
