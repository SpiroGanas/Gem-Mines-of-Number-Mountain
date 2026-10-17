## The answer side of the problem panel: the problem's picture plus the right way to answer it.
##
## The input is the first of the skill's answer modes (in the order the skill lists them, GDD
## section 4) that the problem can be answered with (choose_input is pure and tested):
##   TAP_PILE    tap one of the piles in the picture (which pile has more)
##   BOARD       build with ten-bars and one-gems on the BuildBoard (build, regroup)
##   CHOICES     big answer buttons: the answer plus named wrong answers, shuffled
##   NUMBER_PAD  the on-screen number pad (write the numeral, sums and differences)
## Whatever the child gives comes out of `answered`; the panel never decides if it is right.
## From hint rung 2 the panel also shows the problem's picture model (show_hint).
class_name AnswerPanel
extends VBoxContainer

## The child gave an answer. `given` is in the problem's canonical answer shape.
signal answered(given: Variant)

enum InputKind { NONE, TAP_PILE, BOARD, CHOICES, NUMBER_PAD }

const BOARD_SCENE: PackedScene = preload("res://scenes/input/build_board.tscn")
const CHOICES_SCENE: PackedScene = preload("res://scenes/input/choice_buttons.tscn")
const PAD_SCENE: PackedScene = preload("res://scenes/input/number_pad.tscn")
const VISUAL_SCENE: PackedScene = preload("res://scenes/mine/visual_model.tscn")
## How often a blind guess is right when the answer is typed or built rather than picked from a
## few options (a random number on the pad, a random pile on the board). Used by the adaptive
## engine's guessing guard; deliberately generous.
const FREE_RESPONSE_CHANCE: float = 0.05
## The answer buttons show the answer and at most this many distractors.
const MAX_CHOICE_DISTRACTORS: int = 3

var problem: Problem
var input_kind: InputKind = InputKind.NONE

var _visual: VisualModel
var _hint_visual: VisualModel
var _board: BuildBoard
var _choices: ChoiceButtons
var _pad: NumberPad
var _pad_row: HBoxContainer
var _enabled: bool = false


## Which input fits a problem: the first listed answer mode this panel can serve. Pure.
static func choose_input(for_problem: Problem) -> InputKind:
	for mode: StringName in for_problem.answer_modes:
		var kind: InputKind = _input_for_mode(mode, for_problem)
		if kind != InputKind.NONE:
			return kind
	return InputKind.CHOICES if not for_problem.distractors.is_empty() else InputKind.NUMBER_PAD


static func _input_for_mode(mode: StringName, for_problem: Problem) -> InputKind:
	match mode:
		&"tap":
			if for_problem.meta.get("tap_target") == "pile":
				return InputKind.TAP_PILE
			if not for_problem.distractors.is_empty():
				return InputKind.CHOICES
		&"drag":
			if for_problem.meta.has("tools"):
				return InputKind.BOARD
		&"number_pad", &"keyboard":
			if for_problem.answer is int:
				return InputKind.NUMBER_PAD
	return InputKind.NONE


## How likely a blind guess is to be right with the input this problem gets, after `eliminated`
## options were already tried and missed on this rock. Pure; the adaptive engine weighs evidence
## by it, so tapping one of two piles counts for less than typing a number.
static func chance_for(for_problem: Problem, eliminated: int = 0) -> float:
	var options: int = 0
	match choose_input(for_problem):
		InputKind.TAP_PILE:
			options = for_problem.visual.get("piles", []).size()
		InputKind.CHOICES:
			options = mini(for_problem.distractors.size(), MAX_CHOICE_DISTRACTORS) + 1
		_:
			return FREE_RESPONSE_CHANCE
	return 1.0 / float(maxi(options - eliminated, 1))


## The attempt log's answer_mode for the input a problem gets: tap, drag or number_pad.
static func answer_mode_for(for_problem: Problem) -> StringName:
	match choose_input(for_problem):
		InputKind.TAP_PILE, InputKind.CHOICES:
			return &"tap"
		InputKind.NUMBER_PAD:
			return &"number_pad"
	return &"drag"


## The text on an answer button: numerals, symbols, "30 + 4" for expanded form and "62, 64" for lists.
static func label_for(value: Variant, for_problem: Problem) -> String:
	var words: Dictionary = for_problem.meta.get("label_lines", {})
	if words.has(Problem.label_key(value)):
		return Text.get_line(StringName(words[Problem.label_key(value)])) # "True", "Even"...
	if value is Array:
		var parts: PackedStringArray = PackedStringArray()
		for item: Variant in value:
			parts.append(str(item))
		var joiner: String = " + " if for_problem.meta.get("array_label") == "sum" else ", "
		return joiner.join(parts)
	return str(value)


## Builds the picture and the input for a problem. `rng` shuffles the answer buttons.
func setup(new_problem: Problem, rng: RandomNumberGenerator) -> void:
	_clear()
	problem = new_problem
	input_kind = choose_input(problem)
	add_theme_constant_override(&"separation", 32)
	alignment = BoxContainer.ALIGNMENT_CENTER # the content sits in the middle of the free space
	match input_kind:
		InputKind.TAP_PILE:
			_add_visual(true)
		InputKind.BOARD:
			_add_board()
		InputKind.CHOICES:
			_add_visual(false)
			_add_choices(rng)
		InputKind.NUMBER_PAD:
			_add_pad_with_visual()
	set_enabled(_enabled)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _board != null:
		_board.set_enabled(enabled)
	if _choices != null:
		_choices.set_enabled(enabled)
	if _pad != null:
		_pad.set_enabled(enabled)
	if _visual != null and input_kind == InputKind.TAP_PILE:
		for button: Button in _visual.pile_buttons():
			button.disabled = not enabled


func visual_model() -> VisualModel:
	return _visual


## The hint picture added by show_hint(), or null (it may also be shown in the problem's own
## picture slot; see show_hint).
func hint_visual() -> VisualModel:
	return _hint_visual


## Shows the help a hint rung puts in the answer area. From rung 2 (VISUAL_MODEL) that is the
## problem's picture model (hint_steps[1].visual): it takes the place of the problem's own picture
## when that picture is only to look at, and is added above the input otherwise (tappable piles,
## the build board, or a problem with no picture). Returns the VisualModel showing it.
func show_hint(rung: HintLadder.Rung) -> VisualModel:
	if not HintLadder.shows_model(rung) or problem.hint_steps.size() < 2:
		return null
	var model: Dictionary = problem.hint_steps[1].get("visual", {})
	if model.is_empty():
		return null
	if _visual != null and input_kind != InputKind.TAP_PILE:
		_visual.show_visual(model, false)
		_hint_visual = _visual
		return _hint_visual
	if _hint_visual == null:
		_hint_visual = VISUAL_SCENE.instantiate()
		_hint_visual.compact = true
		_hint_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hint_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pad_row != null:
			_pad_row.add_child(_hint_visual)
			_pad_row.move_child(_hint_visual, 0)
		else:
			add_child(_hint_visual)
			move_child(_hint_visual, 0)
	_hint_visual.show_visual(model, false)
	return _hint_visual


func board() -> BuildBoard:
	return _board


func choices() -> ChoiceButtons:
	return _choices


func number_pad() -> NumberPad:
	return _pad


func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_visual = null
	_hint_visual = null
	_board = null
	_choices = null
	_pad = null
	_pad_row = null


func _add_visual(tappable: bool) -> void:
	if problem.visual.is_empty():
		return
	_visual = VISUAL_SCENE.instantiate()
	_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER # sized to its content, not the whole panel
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_visual)
	_visual.show_visual(problem.visual, tappable)
	if tappable:
		_visual.pile_tapped.connect(_on_value_given)


func _add_choices(rng: RandomNumberGenerator) -> void:
	_choices = CHOICES_SCENE.instantiate()
	add_child(_choices)
	var label_for_value: Callable = func(value: Variant) -> String: return label_for(value, problem)
	_choices.setup(problem.choice_options(label_for_value, MAX_CHOICE_DISTRACTORS), rng)
	_choices.chosen.connect(_on_value_given)


func _add_board() -> void:
	_board = BOARD_SCENE.instantiate()
	var tools: Array[StringName] = []
	for tool: Variant in problem.meta["tools"]:
		tools.append(StringName(str(tool)))
	_board.tools = tools
	var start: Dictionary = problem.meta.get("start", {})
	_board.initial = {"hundreds": start.get("hundreds", 0), "tens": start.get("tens", 0), "ones": start.get("ones", 0)}
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_board)
	_board.submitted.connect(_on_value_given)


## The number pad sits beside the picture so both fit on a 16:9 screen.
func _add_pad_with_visual() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_pad_row = row
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 32)
	add_child(row)
	if not problem.visual.is_empty():
		_visual = VISUAL_SCENE.instantiate()
		_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_visual)
		_visual.show_visual(problem.visual, false)
	_pad = PAD_SCENE.instantiate()
	_pad.max_digits = 3
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pad)
	_pad.submitted.connect(_on_value_given)


func _on_value_given(given: Variant) -> void:
	if _enabled:
		answered.emit(given)
