## One answer attempt, appended to attempts.jsonl (Phase 1 plan, "Save system").
## The adaptive engine (Sprint 6) builds these; the save system only stores them.
class_name Attempt
extends RefCounted

## ISO 8601 UTC timestamp, e.g. "2026-12-03T21:10:00Z".
var ts: String = ""
var session_id: String = ""
var skill_id: StringName = &""
var problem_seed: int = 0
## concrete, pictorial or abstract.
var representation: StringName = &""
## tap, drag, number_pad or keyboard.
var answer_mode: StringName = &""
var correct: bool = false
var hints_used: int = 0
var latency_ms: int = 0
## A low-confidence handwriting reading the child rejected. Never counts as a wrong
## answer (Phase 2); always false in the MVP.
var low_confidence_rejected: bool = false


## The exact object written as one line of attempts.jsonl.
func to_json() -> Dictionary:
	return {
		"ts": ts,
		"session_id": session_id,
		"skill_id": String(skill_id),
		"problem_seed": problem_seed,
		"representation": String(representation),
		"answer_mode": String(answer_mode),
		"correct": correct,
		"hints_used": hints_used,
		"latency_ms": latency_ms,
		"low_confidence_rejected": low_confidence_rejected,
	}


static func from_json(entry: Dictionary) -> Attempt:
	var attempt: Attempt = Attempt.new()
	attempt.ts = str(entry.get("ts", ""))
	attempt.session_id = str(entry.get("session_id", ""))
	attempt.skill_id = StringName(str(entry.get("skill_id", "")))
	attempt.problem_seed = int(entry.get("problem_seed", 0))
	attempt.representation = StringName(str(entry.get("representation", "")))
	attempt.answer_mode = StringName(str(entry.get("answer_mode", "")))
	attempt.correct = bool(entry.get("correct", false))
	attempt.hints_used = int(entry.get("hints_used", 0))
	attempt.latency_ms = int(entry.get("latency_ms", 0))
	attempt.low_confidence_rejected = bool(entry.get("low_confidence_rejected", false))
	return attempt
