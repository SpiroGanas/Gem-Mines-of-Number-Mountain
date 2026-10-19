## The parental gate's question, feedback and NumberPad (ParentGateRules), as one block that the
## gate screen and the first-run parent onboarding both use. Emits `passed` after two right answers in
## a row. Three misses lock the pad (30 seconds, then longer); no countdown is shown.
##
## The lock, the miss count and the lock count outlive the panel: Back and then "Grown-ups" again make
## a new panel, and the wait (and the three tries) must not start over.
class_name GatePanel
extends VBoxContainer

signal passed

static var _remembered_locked_until_ms: int = 0
static var _remembered_misses: int = 0
static var _remembered_locks: int = 0

var rules: ParentGateRules
## Milliseconds now; tests replace it to move time.
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()

var _step: Label
var _question: Label
var _feedback: Label
var _pad: NumberPad
var _unlock_timer: Timer


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 24)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	rules = ParentGateRules.new(rng)
	rules.locked_until_ms = _remembered_locked_until_ms
	rules.misses = _remembered_misses
	rules.locks = _remembered_locks
	_step = Label.new()
	_step.name = "StepLabel"
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_step)
	_question = Label.new()
	_question.name = "QuestionLabel"
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_question)
	_feedback = Label.new()
	_feedback.name = "FeedbackLabel"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
	add_child(_feedback)
	_pad = load("res://scenes/input/number_pad.tscn").instantiate()
	_pad.max_digits = 3
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_pad)
	_pad.submitted.connect(_on_submitted)
	_unlock_timer = Timer.new()
	_unlock_timer.one_shot = true
	_unlock_timer.timeout.connect(_on_unlocked)
	add_child(_unlock_timer)
	_show_question()
	if rules.is_locked(now_ms.call()):
		_lock_pad()


## Forgets a lock from an earlier visit (tests).
static func forget_lock() -> void:
	_remembered_locked_until_ms = 0
	_remembered_misses = 0
	_remembered_locks = 0


func number_pad() -> NumberPad:
	return _pad


func question_text() -> String:
	return _question.text


func step_text() -> String:
	return _step.text


func feedback_text() -> String:
	return _feedback.text


func _show_question() -> void:
	_step.text = Text.get_line(&"parent.gate.step", {"n": rules.question_number(), "total": ParentGateRules.QUESTIONS_TO_PASS})
	_question.text = Text.get_line(&"parent.gate.question", {"a": rules.a, "b": rules.b})


func _on_submitted(value: int) -> void:
	_pad.clear()
	var result: ParentGateRules.Result = rules.submit(value, now_ms.call())
	_remembered_locked_until_ms = rules.locked_until_ms
	_remembered_misses = rules.misses
	_remembered_locks = rules.locks
	match result:
		ParentGateRules.Result.PASSED:
			_feedback.text = ""
			_show_question()
			passed.emit()
		ParentGateRules.Result.NEXT:
			_feedback.text = Text.get_line(&"parent.gate.one_more")
			_show_question()
		ParentGateRules.Result.MISSED:
			_feedback.text = Text.get_line(&"parent.gate.missed")
			_show_question()
		ParentGateRules.Result.LOCKED:
			_show_question()
			_lock_pad()


## "Wait" with the pad asleep until the lock ends; no countdown is shown.
func _lock_pad() -> void:
	_feedback.text = Text.get_line(&"parent.gate.wait")
	_pad.set_enabled(false)
	_unlock_timer.start(float(maxi(rules.locked_until_ms - now_ms.call(), 1)) / 1000.0)


func _on_unlocked() -> void:
	_feedback.text = ""
	_pad.set_enabled(true)
