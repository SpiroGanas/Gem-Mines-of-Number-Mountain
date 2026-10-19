## The parental gate's rules (Phase 1 plan, "Parent gate"; reviewed for Phase 3, plan section 3.7 and
## docs/decisions.md "Parental gate review"). An adult-level task: two multiplication questions in a
## row, each a two-digit number times a one-digit number with a three-digit answer, typed on the
## NumberPad. A miss starts over with a new question; three misses in a row lock the gate, for 30
## seconds the first time and twice as long each time after (up to MAX_COOLDOWN_MS) until it is opened.
##
## Why it holds against random tapping: a random three-digit guess is right 1 time in 900, so two in a
## row is about 1 in 810,000, and the lock lets through at most MAX_MISSES guesses per lock period.
## The questions are random every time, so there is no pattern to memorise.
## Pure: the caller passes the time in milliseconds and the rng.
class_name ParentGateRules
extends RefCounted

enum Result { PASSED, MISSED, LOCKED, NEXT }

const MAX_MISSES: int = 3
const COOLDOWN_MS: int = 30000
const MAX_COOLDOWN_MS: int = 300000
## Right answers in a row that open the gate.
const QUESTIONS_TO_PASS: int = 2
## Every answer has three digits, so a one- or two-tap guess is never right.
const MIN_ANSWER: int = 100

var a: int = 0
var b: int = 0
var misses: int = 0
var locked_until_ms: int = 0
## Right answers so far in this try (0 until the first one).
var answered: int = 0
## Locks since the gate was last opened (each one lasts twice as long as the one before).
var locks: int = 0

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	new_question()


## A new question: 12-99 times 3-9, with an answer of at least 100.
func new_question() -> void:
	a = _rng.randi_range(12, 99)
	b = _rng.randi_range(3, 9)
	while a * b < MIN_ANSWER:
		a = _rng.randi_range(12, 99)


func answer() -> int:
	return a * b


## Which question of QUESTIONS_TO_PASS this is (1 or 2).
func question_number() -> int:
	return answered + 1


func is_locked(now_ms: int) -> bool:
	return now_ms < locked_until_ms


## How long the next lock lasts: 30 seconds, then 60, 120 ... at most MAX_COOLDOWN_MS.
func cooldown_ms() -> int:
	return mini(COOLDOWN_MS * int(pow(2, mini(locks, 10))), MAX_COOLDOWN_MS)


## Checks a typed answer at time `now_ms`: PASSED (the gate opens), NEXT (right; one more question),
## MISSED (a new question, start over) or LOCKED.
func submit(value: int, now_ms: int) -> Result:
	if is_locked(now_ms):
		return Result.LOCKED
	if value == answer():
		answered += 1
		new_question()
		if answered >= QUESTIONS_TO_PASS:
			answered = 0
			misses = 0
			locks = 0
			return Result.PASSED
		return Result.NEXT
	answered = 0
	misses += 1
	new_question()
	if misses >= MAX_MISSES:
		misses = 0
		locked_until_ms = now_ms + cooldown_ms()
		locks += 1
		return Result.LOCKED
	return Result.MISSED
