## Chooses which skill the next rock practises (Phase 1 plan, "Adaptive engine"). Pure: it reads the
## save's skill records and a day string, and keeps only this session's short memory.
##
##   frontier   skills not mastered whose prerequisites are all mastered, placement-passed or secure,
##              outside a zone a build project still keeps closed (locked_zones, Sprint 16)
##   resting    a secure skill that was already answered right today: it waits for another day,
##              because a second correct day is what confirms mastery
##   practice   the frontier minus the resting skills (the resting ones if nothing else is left)
##   review     mastered skills whose next review day has come (1, 3, 7, 21, 60 days)
##
## Each rock is review while reviews are due and fewer than REVIEW_SHARE (30%) of this session's
## rocks have been review; otherwise practice. Practice interleaves an active set of up to 3
## frontier skills (flagged skills first, then curriculum order) and never gives the same skill
## three rocks in a row when another one is available.
class_name Scheduler
extends RefCounted

const INTERLEAVE: int = 3
const REVIEW_SHARE: float = 0.3

var catalog: SkillCatalog
## Skills that can be served, in curriculum order (built generators only, or a test's limit).
var playable: Array[StringName] = []
## Returns the zones the dig must not offer yet (Array[int]); unset means none. The Adaptive autoload
## sets it from the build projects (WorkshopRules.locked_zones); the engine's tests leave it unset.
var locked_zones: Callable = Callable()

var _active: Array[StringName] = []
var _recent: Array[StringName] = []
var _rocks: int = 0
var _reviews: int = 0


func _init(skill_catalog: SkillCatalog, limit_to: Array[StringName] = []) -> void:
	catalog = skill_catalog
	for id: StringName in catalog.ids():
		if not GeneratorRegistry.callable_for(catalog.skill(id)).is_valid():
			continue
		if limit_to.is_empty() or limit_to.has(id):
			playable.append(id)


## Forgets the session's interleave set and review count (a new session starts).
func reset_session() -> void:
	_active.clear()
	_recent.clear()
	_rocks = 0
	_reviews = 0


func review_count() -> int:
	return _reviews


func rock_count() -> int:
	return _rocks


## The record for a skill, or a fresh one (not stored) if the child has never seen it.
func record_of(skills: Dictionary, id: StringName) -> Dictionary:
	if skills.has(String(id)):
		return skills[String(id)]
	return SkillRecord.fresh(0.0)


func is_unlocked(skills: Dictionary, id: StringName) -> bool:
	for prereq: StringName in catalog.skill(id).prereqs:
		if not SkillRecord.opens_successors(record_of(skills, prereq)):
			return false
	return true


func frontier(skills: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var closed: Array = locked_zones.call() if locked_zones.is_valid() else []
	for id: StringName in playable:
		if not closed.is_empty() and closed.has(catalog.skill(id).zone):
			continue
		if not SkillRecord.is_mastered(record_of(skills, id)) and is_unlocked(skills, id):
			result.append(id)
	return result


func is_resting(skills: Dictionary, id: StringName, today: String) -> bool:
	var record: Dictionary = record_of(skills, id)
	return SkillRecord.is_secure(record) and record.get("correct_days", []).has(today)


## Frontier skills worth practising today, flagged ones first, then in curriculum order.
func practice_pool(skills: Dictionary, today: String) -> Array[StringName]:
	var flagged: Array[StringName] = []
	var others: Array[StringName] = []
	for id: StringName in frontier(skills):
		if is_resting(skills, id, today):
			continue
		if bool(record_of(skills, id).get("flagged_for_review", false)):
			flagged.append(id)
		else:
			others.append(id)
	flagged.append_array(others)
	return flagged


## Mastered skills due for review, the longest overdue first.
func due_reviews(skills: Dictionary, today: String) -> Array[StringName]:
	var due: Array[StringName] = []
	for id: StringName in playable:
		if SkillRecord.is_due(record_of(skills, id), today):
			due.append(id)
	due.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(record_of(skills, a)["next_review_at"]) < str(record_of(skills, b)["next_review_at"]))
	return due


## The next rock: {skill_id: StringName, review: bool}. Uses only `rng` for its one random pick.
func choose(skills: Dictionary, today: String, rng: RandomNumberGenerator) -> Dictionary:
	var due: Array[StringName] = due_reviews(skills, today)
	var pool: Array[StringName] = practice_pool(skills, today)
	var want_review: bool = not due.is_empty() and float(_reviews) < REVIEW_SHARE * float(_rocks + 1)
	var choice: Dictionary
	if want_review or (pool.is_empty() and not due.is_empty()):
		choice = {"skill_id": _avoid_repeat(due, rng, true), "review": true}
	elif not pool.is_empty():
		_refresh_active(pool)
		choice = {"skill_id": _avoid_repeat(_active, rng, false), "review": false}
	else:
		choice = {"skill_id": _avoid_repeat(_fallback(skills), rng, false), "review": false}
	_rocks += 1
	if choice["review"]:
		_reviews += 1
	_recent.append(choice["skill_id"])
	if _recent.size() > 2:
		_recent.pop_front()
	return choice


## Concrete first, then pictorial, then abstract as P(L) rises; a review uses the most abstract.
func representation_for(skill: Skill, record: Dictionary, review: bool) -> StringName:
	var count: int = skill.representations.size()
	if count == 0:
		return &"concrete"
	if review:
		return skill.representations[count - 1]
	var step: float = SkillRecord.MASTERY_P / float(count)
	var index: int = clampi(int(float(record.get("p_learned", 0.0)) / step), 0, count - 1)
	return skill.representations[index]


func _refresh_active(pool: Array[StringName]) -> void:
	var kept: Array[StringName] = []
	for id: StringName in _active:
		if pool.has(id):
			kept.append(id)
	_active = kept
	for id: StringName in pool:
		if _active.size() >= INTERLEAVE:
			break
		if not _active.has(id):
			_active.append(id)


## A random pick from `options` that is not the skill of the last two rocks, if possible.
## Reviews take the most overdue that is allowed rather than a random one.
func _avoid_repeat(options: Array[StringName], rng: RandomNumberGenerator, take_first: bool) -> StringName:
	var allowed: Array[StringName] = []
	for id: StringName in options:
		if not (_recent.size() == 2 and _recent[0] == id and _recent[1] == id):
			allowed.append(id)
	if allowed.is_empty():
		allowed = options
	if take_first:
		return allowed[0]
	return allowed[rng.randi_range(0, allowed.size() - 1)]


## Nothing to practise or review (everything open is mastered or resting): keep digging on the
## resting skills, else the mastered ones, so the child always has rocks to crack.
func _fallback(skills: Dictionary) -> Array[StringName]:
	var open: Array[StringName] = frontier(skills)
	if not open.is_empty():
		return open
	var mastered: Array[StringName] = []
	for id: StringName in playable:
		if SkillRecord.is_mastered(record_of(skills, id)):
			mastered.append(id)
	if not mastered.is_empty():
		return mastered
	var first: Array[StringName] = [playable[0]]
	return first
