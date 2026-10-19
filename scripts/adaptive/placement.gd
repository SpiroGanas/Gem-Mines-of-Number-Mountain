## The placement quest, "survey the mountain" (Phase 1 plan): about ten minutes of rocks that find
## where the child should start, so a child who already knows Zone 1 is not made to count to 20.
##
## Probe a skill with two problems. Both right on the first try: the skill and every skill below
## it are placement-passed (P(L) 0.85, not mastered) and the skills that build on it join the
## queue. A miss: its prerequisites join the queue instead. The quest ends at ten minutes, after
## MAX_PROBLEMS problems, or when the queue is empty (nothing left that could change the frontier).
## Pure: it never touches the save; Adaptive applies `passed` to the skill records.
##
## Generic placement (Phase 3, Sprint 23): a profile a parent creates with a starting grade gets
## seed "grade_<n>". Its skills start from that grade's priors (seed_from_grade, from
## curriculum/placement_priors.json) and the quest starts from that grade's probes instead of
## Charlie's Star skills. The quest itself is unchanged: it still walks down on a miss and up on a pass.
class_name Placement
extends RefCounted

## Named starting sets. Charlie's comes from his Star report (seed "star_2026_09" in the save).
const SEED_SETS: Dictionary = {
	"star_2026_09": [&"count.to_120.read", &"pv.tens_ones.build", &"add.to_10.sums"],
}
const DEFAULT_SEED_SET: Array[StringName] = [&"count.to_20.objects"]
## The generic placement table (plan section 3.6).
const PRIORS_PATH: String = "res://curriculum/placement_priors.json"
const GRADE_SEED_PREFIX: String = "grade_"
const PROBLEMS_PER_PROBE: int = 2
const TIME_LIMIT_SECONDS: int = 600
const MAX_PROBLEMS: int = 40

## Every skill marked placement-passed so far (probed ones and everything below them).
var passed: Array[StringName] = []
## Probed skills the child missed.
var failed: Array[StringName] = []

var _catalog: SkillCatalog
var _playable: Array[StringName]
var _queue: Array[StringName] = []
var _current: StringName = &""
var _answers: Array[bool] = []
var _started_at: int = 0
var _problems_given: int = 0

static var _priors_table: Dictionary = {}


## `playable` limits the quest to skills the game can serve; `already_passed` (from the save) are
## skipped. `started_at` is the clock's Unix time.
func _init(catalog: SkillCatalog, playable: Array[StringName], seed_name: String, started_at: int, already_passed: Array[StringName] = []) -> void:
	_catalog = catalog
	_playable = playable
	_started_at = started_at
	passed = already_passed.duplicate()
	var seeds: Array = SEED_SETS.get(seed_name, probes_for(seed_name))
	for id: StringName in seeds:
		_enqueue(id)
	_advance()


## The skill being probed, or &"" when the quest is over.
func current_skill() -> StringName:
	return _current


func problems_given() -> int:
	return _problems_given


func is_done(now_unix: int) -> bool:
	return _current == &"" or now_unix - _started_at >= TIME_LIMIT_SECONDS or _problems_given >= MAX_PROBLEMS


## Records the first-try result of one placement problem for the current skill.
func record(correct: bool) -> void:
	if _current == &"":
		return
	_problems_given += 1
	_answers.append(correct)
	if not correct:
		failed.append(_current)
		for prereq: StringName in _catalog.skill(_current).prereqs:
			_enqueue(prereq)
		_advance()
	elif _answers.size() >= PROBLEMS_PER_PROBE:
		for id: StringName in [_current] + ancestors(_current):
			if not passed.has(id):
				passed.append(id)
		for id: StringName in successors(_current):
			_enqueue(id)
		_advance()


## Every skill below `id` in the prerequisite graph (its prerequisites, theirs, and so on).
func ancestors(id: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	var stack: Array[StringName] = _catalog.skill(id).prereqs.duplicate()
	while not stack.is_empty():
		var next: StringName = stack.pop_back()
		if found.has(next):
			continue
		found.append(next)
		stack.append_array(_catalog.skill(next).prereqs)
	return found


## Skills that list `id` as a prerequisite and whose other prerequisites are already passed.
func successors(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for other: StringName in _catalog.ids():
		var skill: Skill = _catalog.skill(other)
		if not skill.prereqs.has(id):
			continue
		var ready: bool = true
		for prereq: StringName in skill.prereqs:
			ready = ready and passed.has(prereq)
		if ready:
			result.append(other)
	return result


func _enqueue(id: StringName) -> void:
	if _playable.has(id) and not passed.has(id) and not failed.has(id) and not _queue.has(id) and id != _current:
		_queue.append(id)


func _advance() -> void:
	_answers.clear()
	_current = &""
	while not _queue.is_empty():
		var next: StringName = _queue.pop_front()
		if not passed.has(next) and not failed.has(next):
			_current = next
			return


# --- Generic placement from a starting grade (Sprint 23) ---------------------------------------------


## The placement seed of a profile created with `grade` (K = 0).
static func grade_seed_name(grade: int) -> String:
	return GRADE_SEED_PREFIX + str(Profile.clamp_grade(grade))


## The quest's first probes for a seed name: a grade seed's probes from the table, else the default.
static func probes_for(seed_name: String) -> Array[StringName]:
	var probes: Array[StringName] = []
	if seed_name.begins_with(GRADE_SEED_PREFIX) and seed_name.trim_prefix(GRADE_SEED_PREFIX).is_valid_int():
		for id: Variant in grade_row(int(seed_name.trim_prefix(GRADE_SEED_PREFIX))).get("probes", []):
			probes.append(StringName(str(id)))
	return probes if not probes.is_empty() else DEFAULT_SEED_SET.duplicate()


## BKT priors per skill id for a child starting at `grade`: every skill of a zone the grade's row lists
## gets that zone's prior; other skills are left out (they keep their bkt_defaults.json prior).
static func seed_from_grade(grade: int, catalog: SkillCatalog = null) -> Dictionary[String, float]:
	var skills: SkillCatalog = catalog if catalog != null else SkillCatalog.load_all()
	var zones: Dictionary = grade_row(grade).get("zones", {})
	var priors: Dictionary[String, float] = {}
	for id: StringName in skills.ids():
		var zone_key: String = str(skills.skill(id).zone)
		if zones.has(zone_key):
			priors[String(id)] = clampf(float(zones[zone_key]), 0.0, 1.0)
	return priors


## The table row for `grade`: its own, or the highest grade below it that has one.
static func grade_row(grade: int) -> Dictionary:
	var rows: Dictionary = priors_table().get("grades", {})
	var best: int = -1
	for key: Variant in rows:
		var value: int = int(str(key)) if str(key).is_valid_int() else -1
		if value <= Profile.clamp_grade(grade) and value > best:
			best = value
	return rows.get(str(best), {}) if best >= 0 else {}


## curriculum/placement_priors.json, read once.
static func priors_table() -> Dictionary:
	if _priors_table.is_empty():
		var parsed: Variant = JsonUtil.parse_file(PRIORS_PATH)
		_priors_table = parsed if parsed is Dictionary else {"grades": {}}
	return _priors_table
