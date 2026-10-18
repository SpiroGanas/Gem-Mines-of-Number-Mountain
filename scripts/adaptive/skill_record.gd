## One skill's learning state as stored in the save (`skills.<skill id>` in schema v1), plus the
## rules that read it: mastered, secure, due for review, and the "better than guessing" evidence.
## Pure helpers over a plain Dictionary, so the save stays plain JSON.
##
## Schema v1 fields: p_learned, attempts, correct, correct_days, mastered_at, review_stage,
## next_review_at, flagged_for_review, recent_latency_ms. Two optional fields were added in
## Sprint 6 (docs/decisions.md; absent means false / 0.0, so every v1 save still loads):
##   placement_passed  the placement quest showed the child already knows this skill
##   guess_evidence    log-likelihood ratio of first-try answers: knows it vs. only guessing
## and one in Sprint 19 (schema v2):
##   mastery_evidence  "" for ordinary mastery, "challenge" when the Challenge Door gave it
class_name SkillRecord
extends RefCounted

## P(L) at or above this counts as learned (Phase 1 plan; do not change without Spiro).
const MASTERY_P: float = 0.95
## Correct answers on at least this many different calendar days (do not change without Spiro).
const MASTERY_DAYS: int = 2
## The guessing guard: the answers must be at least this many times more likely from a child who
## knows the skill than from one who is only guessing (ln 2000; see docs/decisions.md, Sprint 6).
const EVIDENCE_TO_MASTER: float = 7.6009024595
## Old misses never sink the evidence below this (ln 1/100), so a child who struggled early and
## then learned is not held back for weeks.
const EVIDENCE_FLOOR: float = -4.605170186
## Spaced review after mastery: 1, 3, 7, 21, then every 60 days.
const REVIEW_INTERVALS: Array[int] = [1, 3, 7, 21, 60]
## A placement-passed skill starts here (Phase 1 plan, placement quest).
const PLACEMENT_P: float = 0.85
## Latencies kept for the hidden fluency check of fact skills.
const LATENCIES_KEPT: int = 5


static func fresh(prior: float) -> Dictionary:
	return {
		"p_learned": prior, "attempts": 0, "correct": 0, "correct_days": [],
		"mastered_at": null, "review_stage": 0, "next_review_at": null,
		"flagged_for_review": false, "recent_latency_ms": [],
		"placement_passed": false, "guess_evidence": 0.0, "mastery_evidence": "",
	}


## The record for `id` in `skills`, created (and stored) with `prior` if the skill is new.
## Missing optional fields are filled in, so a v1 record works unchanged.
static func ensure(skills: Dictionary, id: StringName, prior: float) -> Dictionary:
	var key: String = String(id)
	if not skills.has(key):
		skills[key] = fresh(prior)
	var record: Dictionary = skills[key]
	for field: String in fresh(prior):
		if not record.has(field):
			record[field] = fresh(prior)[field]
	return record


## Mastered now: it was mastered once and no failed review or struggle has flagged it since.
static func is_mastered(record: Dictionary) -> bool:
	return record.get("mastered_at") != null and not bool(record.get("flagged_for_review", false))


## Learned but not yet confirmed on a second day. A secure skill already opens the skills that
## build on it, so a quick learner is never held at one skill for a whole day.
static func is_secure(record: Dictionary) -> bool:
	return float(record.get("p_learned", 0.0)) >= MASTERY_P and float(record.get("guess_evidence", 0.0)) >= EVIDENCE_TO_MASTER


## Prerequisite rule for the frontier: mastered, placement-passed or secure.
static func opens_successors(record: Dictionary) -> bool:
	return is_mastered(record) or bool(record.get("placement_passed", false)) or is_secure(record)


## Every mastery condition: P(L), two different days, better than guessing, and for fact skills
## the hidden fluency check (median of the recent latencies at or under fluency_ms).
static func is_ready_to_master(record: Dictionary, params: Dictionary, is_fact_skill: bool) -> bool:
	if float(record.get("p_learned", 0.0)) < MASTERY_P:
		return false
	if record.get("correct_days", []).size() < MASTERY_DAYS:
		return false
	if float(record.get("guess_evidence", 0.0)) < EVIDENCE_TO_MASTER:
		return false
	if is_fact_skill and params.has("fluency_ms"):
		var latencies: Array = record.get("recent_latency_ms", [])
		if latencies.is_empty() or median(latencies) > int(params["fluency_ms"]):
			return false
	return true


## Due for review today (mastered and its next review day has come).
static func is_due(record: Dictionary, today: String) -> bool:
	var next: Variant = record.get("next_review_at")
	return is_mastered(record) and next is String and next <= today


## How much one first-try answer says about knowing vs. guessing: ln of the likelihood ratio.
## A child who knows the skill is right (1 - slip) of the time; a guesser `chance` of the time.
static func evidence_of(correct: bool, chance: float, slip: float) -> float:
	var luck: float = clampf(chance, 0.0001, 0.9999)
	if correct:
		return log((1.0 - slip) / luck)
	return log(slip / (1.0 - luck))


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var middle: int = floori(sorted.size() / 2.0)
	if sorted.size() % 2 == 1:
		return float(sorted[middle])
	return (float(sorted[middle - 1]) + float(sorted[middle])) / 2.0
