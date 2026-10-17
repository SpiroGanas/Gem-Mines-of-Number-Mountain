## The parental gate's rules (Phase 1 plan, "Parent gate"): an adult-level question, a two-digit
## number times a one-digit number, answered on the NumberPad. Three misses in a row lock the gate
## for 30 seconds, so random tapping cannot get through. A miss always brings a new question.
## Pure: the caller passes the time in milliseconds and the rng.
class_name ParentGateRules
extends RefCounted

enum Result { PASSED, MISSED, LOCKED }

const MAX_MISSES: int = 3
const COOLDOWN_MS: int = 30000

var a: int = 0
var b: int = 0
var misses: int = 0
var locked_until_ms: int = 0

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	new_question()


## A new question: 12-99 times 3-9, so the answer is never a one-tap guess.
func new_question() -> void:
	a = _rng.randi_range(12, 99)
	b = _rng.randi_range(3, 9)


func answer() -> int:
	return a * b


func is_locked(now_ms: int) -> bool:
	return now_ms < locked_until_ms


## Checks a typed answer at time `now_ms`.
func submit(value: int, now_ms: int) -> Result:
	if is_locked(now_ms):
		return Result.LOCKED
	if value == answer():
		misses = 0
		return Result.PASSED
	misses += 1
	new_question()
	if misses >= MAX_MISSES:
		misses = 0
		locked_until_ms = now_ms + COOLDOWN_MS
		return Result.LOCKED
	return Result.MISSED
