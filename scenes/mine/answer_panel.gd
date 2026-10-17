## The answer side of the problem panel: the problem's picture plus the right way to answer it.
##
## The input is the first of the skill's answer modes (in the order the skill lists them, GDD
## section 4) that the problem can be answered with (choose_input is pure and tested):
##   TAP_PILE    tap one of the piles in the picture (which pile has more)
##   BOARD       build with ten-bars and one-gems on the BuildBoard (build, regroup)
##   CHOICES     big answer buttons: the answer plus named wrong answers, shuffled
##   NUMBER_PAD  the on-screen number pad (write the numeral, sums and differences)
##   TILES       drag tiles into slots on the TileBoard (number strips, ordering, fact families)
##   ARRAY       drag or tap out rows and columns on the ArrayBuilder (build an array)
## Whatever the child gives comes out of `answered`; the panel never decides if it is right.
## From hint rung 2 the panel also shows the problem's picture model, and from rung 3 a solved
## "friend" of the problem (show_hint).
class_name AnswerPanel
extends VBoxContainer

## The child gave an answer. `given` is in the problem's canonical answer shape.
signal answered(given: Variant)

enum InputKind { NONE, TAP_PILE, BOARD, CHOICES, NUMBER_PAD, TILES, ARRAY }

const BOARD_SCENE: PackedScene = preload("res://scenes/input/build_board.tscn")
const CHOICES_SCENE: PackedScene = preload("res://scenes/input/choice_buttons.tscn")
const PAD_SCENE: PackedScene = preload("res://scenes/input/number_pad.tscn")
const TILES_SCENE: PackedScene = preload("res://scenes/input/tile_board.tscn")
const ARRAY_SCENE: PackedScene = preload("res://scenes/input/array_builder.tscn")
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
var _tiles: TileBoard
var _array: ArrayBuilder
var _example: PanelContainer
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
			if for_problem.meta.has("tile_board"):
				return InputKind.TILES
			if for_problem.meta.has("array_builder"):
				return InputKind.ARRAY
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
		InputKind.TILES:
			return tile_chance(for_problem.meta["tile_board"])
		InputKind.ARRAY:
			var limits: Dictionary = for_problem.meta["array_builder"]
			return 1.0 / float(maxi(int(limits["max_rows"]) * int(limits["max_cols"]), 1))
		_:
			return FREE_RESPONSE_CHANCE
	return 1.0 / float(maxi(options - eliminated, 1))


## The chance that tiles dropped into the slots at random are right: one arrangement out of all the
## ordered (or, when order does not matter, unordered) ways to fill the slots from the pool.
static func tile_chance(board: Dictionary) -> float:
	var pool: int = board.get("tiles", []).size()
	var slots: int = int(board.get("slots", 1))
	var ways: float = 1.0
	for index: int in slots:
		ways *= float(pool - index)
	if not board.get("ordered", true):
		for index: int in range(2, slots + 1):
			ways /= float(index)
	return 1.0 / maxf(ways, 1.0)


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
		InputKind.TILES:
			_add_visual(false)
			_add_tiles()
		InputKind.ARRAY:
			_add_visual(false)
			_add_array_builder()
	set_enabled(_enabled)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _board != null:
		_board.set_enabled(enabled)
	if _choices != null:
		_choices.set_enabled(enabled)
	if _pad != null:
		_pad.set_enabled(enabled)
	if _tiles != null:
		_tiles.set_enabled(enabled)
	if _array != null:
		_array.set_enabled(enabled)
	if _visual != null and input_kind == InputKind.TAP_PILE:
		for button: Button in _visual.pile_buttons():
			button.disabled = not enabled


func visual_model() -> VisualModel:
	return _visual


## The hint picture added by show_hint(), or null (it may also be shown in the problem's own
## picture slot; see show_hint).
func hint_visual() -> VisualModel:
	return _hint_visual


## Shows the help a hint rung puts in the answer area and returns the picture model it shows (or
## null). From rung 2 (VISUAL_MODEL) that is the problem's picture model (hint_steps[1].visual): it
## takes the place of the problem's own picture when that picture is only to look at, and is added
## above the input otherwise (tappable piles, the build board, a problem with no picture). From
## rung 3 (WORKED_EXAMPLE) a card above the input shows a solved problem of the same skill with
## other numbers; an added model box steps aside for it so everything still fits the screen.
func show_hint(rung: HintLadder.Rung) -> VisualModel:
	if not HintLadder.shows_model(rung) or problem.hint_steps.size() < 2:
		return null
	var shown: VisualModel = _show_model()
	if HintLadder.shows_example(rung) and problem.hint_steps.size() >= 3:
		_show_example()
		if _hint_visual != null and _hint_visual != _visual:
			_hint_visual.visible = false
	return shown


## The worked-example card from rung 3, or null.
func example_card() -> PanelContainer:
	return _example


func _show_model() -> VisualModel:
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


func _show_example() -> void:
	if _example != null:
		return
	var step: Dictionary = problem.hint_steps[2]
	var example: Dictionary = step.get("example", {})
	if example.is_empty():
		return
	_example = PanelContainer.new()
	_example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	_example.add_child(column)
	var asked: Label = Label.new()
	asked.text = Text.get_line(StringName(example["prompt_line_id"]), example["prompt_params"])
	asked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(asked)
	var picture: Dictionary = step.get("visual", {})
	if not picture.is_empty():
		var visual: VisualModel = VISUAL_SCENE.instantiate()
		visual.compact = true
		visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(visual)
		visual.show_visual(picture, false)
	var solved: Label = Label.new()
	solved.text = Text.get_line(StringName(example["answer_line_id"]), example["answer_params"])
	solved.add_theme_color_override(&"font_color", Color(Text.HIGHLIGHT_COLOR))
	solved.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(solved)
	add_child(_example)
	move_child(_example, 0)


func board() -> BuildBoard:
	return _board


func choices() -> ChoiceButtons:
	return _choices


func number_pad() -> NumberPad:
	return _pad


func tile_board() -> TileBoard:
	return _tiles


func array_builder() -> ArrayBuilder:
	return _array


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
	_tiles = null
	_array = null
	_example = null


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


func _add_tiles() -> void:
	var spec: Dictionary = problem.meta["tile_board"]
	_tiles = TILES_SCENE.instantiate()
	_tiles.tiles = spec["tiles"].duplicate()
	_tiles.slot_count = int(spec["slots"])
	_tiles.ordered = bool(spec.get("ordered", true))
	_tiles.sequence = strip_sequence(problem)
	_tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tiles)
	_tiles.submitted.connect(_on_value_given)


func _add_array_builder() -> void:
	var limits: Dictionary = problem.meta["array_builder"]
	_array = ARRAY_SCENE.instantiate()
	_array.max_rows = int(limits["max_rows"])
	_array.max_cols = int(limits["max_cols"])
	_array.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_array)
	_array.submitted.connect(_on_value_given)


## For a number strip (a number line whose blanks are the answer), the strip in reading order with
## null where each blank goes, so the slots sit between the numbers around them. Otherwise empty.
static func strip_sequence(for_problem: Problem) -> Array:
	var line: Dictionary = for_problem.visual
	var slots: int = int(for_problem.meta.get("tile_board", {}).get("slots", 0))
	if line.get("type") != "number_line" or line.get("blanks", []).size() != slots:
		return []
	var step: int = maxi(int(line["labeled_every"]), 1)
	var sequence: Array = []
	for value: int in range(int(line["min"]), int(line["max"]) + 1, step):
		sequence.append(null if line["blanks"].has(value) else value)
	return sequence if sequence.count(null) == slots and sequence.size() <= 8 else []


func _on_value_given(given: Variant) -> void:
	if _enabled:
		answered.emit(given)
