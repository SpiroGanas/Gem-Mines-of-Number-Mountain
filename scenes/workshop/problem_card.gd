## One problem answered outside the mine: the workshop's recipe question and every build step use it
## (Sprint 16). It shows the AnswerPanel, reports each answer to Adaptive exactly like a rock (so it is
## learning evidence), and climbs the hint ladder on a not-quite answer. Wrong answers cost nothing;
## the card never decides what an answer pays, it only says `solved`.
##
## The ladder stops at rung 3 (the worked example): rung 4's easier problem belongs to the mine,
## where a rock can swap its problem. Here the same question stays with all the help on screen.
class_name ProblemCard
extends VBoxContainer

## The problem was answered right.
signal solved(problem: Problem)
## A not-quite answer; `rung` is the help now shown.
signal missed(rung: HintLadder.Rung)

const PANEL_SCENE: PackedScene = preload("res://scenes/mine/answer_panel.tscn")

## Bolt to read the problem and the feedback (optional; tests may leave it null).
var bolt: Bolt
## Practice (the default) reports answers to Adaptive and climbs the hint ladder. The Challenge Door
## sets it false: answers are not learning evidence there and a miss only emits `missed`.
var practice: bool = true
## Tests inject a recognizer for the slate (see AnswerPanel.recognizer).
var recognizer: Recognizer
var slate_override: Variant = null

var problem: Problem
var _panel: AnswerPanel
var _misses: int = 0
var _opened_ms: int = 0
var _done: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Shows a problem. `rng` shuffles the answer buttons.
func show_problem(new_problem: Problem, rng: RandomNumberGenerator) -> void:
	problem = new_problem
	_misses = 0
	_done = false
	if _panel != null:
		_panel.queue_free()
		remove_child(_panel)
	_panel = PANEL_SCENE.instantiate()
	_panel.slate_override = slate_override
	_panel.recognizer = recognizer
	_panel.wide_pad = true # under Bolt beside the workshop's body there is less height than in the mine
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_panel)
	_panel.setup(problem, rng)
	_panel.answered.connect(_on_answered)
	_panel.rejected.connect(_on_rejected)
	if bolt != null:
		var terms: Array[StringName] = []
		if Adaptive.catalog().has_skill(problem.skill_id):
			terms = Adaptive.catalog().skill(problem.skill_id).terms
		bolt.set_terms(terms)
		bolt.say(problem.prompt_line_id, problem.prompt_params)
	_opened_ms = Time.get_ticks_msec()
	_panel.set_enabled(true)


func answer_panel() -> AnswerPanel:
	return _panel


func misses() -> int:
	return _misses


func set_enabled(enabled: bool) -> void:
	if _panel != null:
		_panel.set_enabled(enabled and not _done)


func _attempt(correct: bool) -> Attempt:
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = problem.skill_id
	attempt.problem_seed = problem.seed
	attempt.representation = problem.representation
	attempt.answer_mode = AnswerPanel.answer_mode_for_kind(_panel.input_kind)
	attempt.correct = correct
	attempt.confirmed = _panel.slate_confirmed()
	attempt.hints_used = _misses
	attempt.latency_ms = Time.get_ticks_msec() - _opened_ms
	return attempt


func _on_answered(given: Variant) -> void:
	if _done:
		return
	var correct: bool = problem.is_correct(given)
	if practice:
		Adaptive.record(_attempt(correct), AnswerPanel.chance_for(problem, _misses))
	if correct:
		_done = true
		_panel.set_enabled(false)
		if bolt != null:
			bolt.note(&"bolt.feedback.correct" if _misses == 0 else &"bolt.feedback.correct_hint")
		solved.emit(problem)
		return
	_misses += 1
	if not practice:
		missed.emit(HintLadder.Rung.REPEAT_HIGHLIGHT)
		return
	var rung: HintLadder.Rung = mini(HintLadder.next_rung(_misses), HintLadder.Rung.WORKED_EXAMPLE) as HintLadder.Rung
	if bolt != null:
		bolt.say(problem.prompt_line_id, problem.prompt_params, false, problem.prompt_params.keys())
		bolt.note(&"bolt.feedback.not_quite")
		bolt.add_note(HintLadder.line_for(rung))
	_panel.show_hint(rung)
	missed.emit(rung)


## "Try again" to the slate's "Did you write 47?": logged apart, never a miss (CLAUDE.md).
func _on_rejected() -> void:
	if _done or not practice:
		return
	var attempt: Attempt = _attempt(false)
	attempt.low_confidence_rejected = true
	Adaptive.record(attempt, AnswerPanel.chance_for(problem, _misses))
