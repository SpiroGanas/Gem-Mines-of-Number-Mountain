## The answer side of the problem panel: the problem's picture plus the right way to answer it.
##
## One of four inputs is chosen from the problem (choose_input is pure and tested):
##   TAP_PILE    tap one of the piles in the picture (which pile has more)
##   BOARD       build with ten-bars and one-gems on the BuildBoard (build, regroup)
##   CHOICES     big answer buttons: the answer plus named wrong answers, shuffled
##   NUMBER_PAD  the on-screen number pad (write the numeral)
## Whatever the child gives comes out of `answered`; the panel never decides if it is right.
class_name AnswerPanel
extends VBoxContainer

## The child gave an answer. `given` is in the problem's canonical answer shape.
signal answered(given: Variant)

enum InputKind { NONE, TAP_PILE, BOARD, CHOICES, NUMBER_PAD }

const BOARD_SCENE: PackedScene = preload("res://scenes/input/build_board.tscn")
const CHOICES_SCENE: PackedScene = preload("res://scenes/input/choice_buttons.tscn")
const PAD_SCENE: PackedScene = preload("res://scenes/input/number_pad.tscn")
const VISUAL_SCENE: PackedScene = preload("res://scenes/mine/visual_model.tscn")

var problem: Problem
var input_kind: InputKind = InputKind.NONE

var _visual: VisualModel
var _board: BuildBoard
var _choices: ChoiceButtons
var _pad: NumberPad
var _enabled: bool = false


## Which input fits a problem. Pure.
static func choose_input(for_problem: Problem) -> InputKind:
	if for_problem.meta.get("tap_target") == "pile":
		return InputKind.TAP_PILE
	if for_problem.meta.has("tools"):
		return InputKind.BOARD
	if for_problem.answer_modes.has(&"tap") and not for_problem.distractors.is_empty():
		return InputKind.CHOICES
	if for_problem.answer_modes.has(&"number_pad"):
		return InputKind.NUMBER_PAD
	return InputKind.CHOICES


## The text on an answer button: numerals, symbols, "30 + 4" for expanded form and "62, 64" for lists.
static func label_for(value: Variant, for_problem: Problem) -> String:
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
	_board = null
	_choices = null
	_pad = null


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
	_choices.setup(problem.choice_options(label_for_value), rng)
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
