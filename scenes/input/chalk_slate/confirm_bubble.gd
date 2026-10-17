## Bolt's question when the slate is unsure how to read a number: "Did you write 47?" with a Yes and
## a Try again target (both at least the 64 dp minimum, CLAUDE.md rule 7). Answering "Try again" is
## never a wrong answer.
class_name ConfirmBubble
extends PanelContainer

## The child said the number is right.
signal confirmed
## The child wants to write it again.
signal retry

var _question: Label
var _yes: Button
var _again: Button


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	margin.add_child(column)
	_question = Label.new()
	_question.name = "Question"
	_question.theme_type_variation = &"HeadingLabel"
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_question)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	column.add_child(row)
	_yes = _button(&"input.slate.yes", &"GoButton")
	_yes.name = "YesButton"
	_yes.pressed.connect(func() -> void: confirmed.emit())
	row.add_child(_yes)
	_again = _button(&"input.slate.try_again", &"")
	_again.name = "TryAgainButton"
	_again.pressed.connect(func() -> void: retry.emit())
	row.add_child(_again)
	visible = false


## Shows the question for `value`.
func ask(value: int) -> void:
	_question.text = Text.get_line(&"input.slate.confirm", {"n": value})
	visible = true


func close() -> void:
	visible = false


func question_text() -> String:
	return _question.text


func yes_button() -> Button:
	return _yes


func try_again_button() -> Button:
	return _again


func set_enabled(enabled: bool) -> void:
	_yes.disabled = not enabled
	_again.disabled = not enabled


func _button(line_id: StringName, variation: StringName) -> Button:
	var button: Button = Button.new()
	button.text = Text.get_line(line_id)
	if variation != &"":
		button.theme_type_variation = variation
	UI.make_touch_target(button, 3.0, 1.5)
	return button
