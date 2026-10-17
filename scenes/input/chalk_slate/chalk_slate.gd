## The chalk slate: the child writes the answer with a finger or a stylus, one digit per box.
##
## One DigitBox per digit of the answer (so place value shows: ones, tens, hundreds), an Erase button
## and a Done button. Done reads every box with a Recognizer and then
##   - submits the number when every digit is read with confidence;
##   - asks "Did you write 47?" (ConfirmBubble) when any digit is unsure. Yes submits; Try again
##     wipes only the unsure boxes and emits answer_rejected, which is never a wrong answer;
##   - nudges (never penalizes) when a box is blank after the first number, or its marks are not a digit.
## The strokes stay in memory only so the child can see them; they are discarded on submit, on Erase
## and when the slate is freed, and are never saved (CLAUDE.md rule 2). Presentation only: the slate
## never says whether the answer is right.
class_name ChalkSlate
extends VBoxContainer

## The child's number is ready (read with confidence, or confirmed with Yes).
signal answer_submitted(value: int)
## The child said "Try again" to a confirmation. Not an incorrect attempt.
signal answer_rejected
## The slate cannot work here (no recognizer); the host should show the number pad instead.
signal fell_back_to_number_pad
## A digit was read and accepted as part of a submitted number. `mirrored` is true when it was
## written backwards (for numeral coaching).
signal digit_read(digit: int, mirrored: bool)

const BOX_SCENE: PackedScene = preload("res://scenes/input/chalk_slate/digit_box.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/input/chalk_slate/confirm_bubble.tscn")
const PLACE_LINES: Array[StringName] = [&"input.slate.place_ones", &"input.slate.place_tens", &"input.slate.place_hundreds"]

## Below this confidence a reading is confirmed with the child. Tuned from the evaluation sweep
## (tools/handwriting/evaluate.py; docs/decisions.md, Sprint 14).
@export var confidence_threshold: float = 0.9

## The stroke source handed to every box. Defaults to the InputRouter autoload; tests inject theirs.
var router: Node

var _recognizer: Recognizer
var _boxes: Array[DigitBox] = []
var _prompt: Label
var _message: Label
var _buttons: HBoxContainer
var _clear_button: Button
var _done_button: Button
var _bubble: ConfirmBubble
var _pending: Dictionary = {}
var _readings: Array[Dictionary] = []
var _enabled: bool = true


func _ready() -> void:
	if theme == null:
		theme = UI.theme()
	add_theme_constant_override(&"separation", 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = Text.get_line(&"input.slate.prompt")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_message = Label.new()
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	add_child(_message)


## Builds `answer_digits` boxes (leading digits are never pre-filled) and reads them with `recognizer`.
func setup(answer_digits: int, recognizer: Recognizer) -> void:
	_recognizer = recognizer
	for child: Node in get_children():
		if child != _prompt and child != _message:
			child.queue_free()
			remove_child(child)
	_boxes.clear()
	if recognizer == null:
		fell_back_to_number_pad.emit.call_deferred()
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Boxes"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	add_child(row)
	var digits: int = clampi(answer_digits, 1, PLACE_LINES.size())
	for position: int in digits:
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 6)
		row.add_child(column)
		var box: DigitBox = BOX_SCENE.instantiate()
		box.router = router
		box.name = "DigitBox%d" % position
		column.add_child(box)
		_boxes.append(box)
		var caption: Label = Label.new()
		caption.text = Text.get_line(PLACE_LINES[digits - 1 - position])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.modulate = Color(1, 1, 1, 0.75)
		column.add_child(caption)
	_bubble = BUBBLE_SCENE.instantiate()
	_bubble.name = "ConfirmBubble"
	_bubble.confirmed.connect(_on_confirmed)
	_bubble.retry.connect(_on_retry)
	add_child(_bubble)
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 24)
	add_child(_buttons)
	_clear_button = Button.new()
	_clear_button.name = "ClearButton"
	_clear_button.text = Text.get_line(&"input.slate.clear")
	UI.make_touch_target(_clear_button, 3.0, 1.5)
	_clear_button.pressed.connect(clear)
	_buttons.add_child(_clear_button)
	_done_button = Button.new()
	_done_button.name = "DoneButton"
	_done_button.text = Text.get_line(&"input.slate.done")
	_done_button.theme_type_variation = &"GoButton"
	UI.make_touch_target(_done_button, 3.0, 1.5)
	_done_button.pressed.connect(_on_done_pressed)
	_buttons.add_child(_done_button)
	set_enabled(_enabled)


func boxes() -> Array[DigitBox]:
	return _boxes


func done_button() -> Button:
	return _done_button


func clear_button() -> Button:
	return _clear_button


func confirm_bubble() -> ConfirmBubble:
	return _bubble


func message_text() -> String:
	return _message.text if _message.visible else ""


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for box: DigitBox in _boxes:
		box.set_enabled(enabled and not _bubble_open())
	if _done_button != null:
		_done_button.disabled = not enabled
		_clear_button.disabled = not enabled
	if _bubble != null:
		_bubble.set_enabled(enabled)


## Wipes every box (and any question Bolt was asking).
func clear() -> void:
	_pending = {}
	if _bubble != null:
		_bubble.close()
	for box: DigitBox in _boxes:
		box.clear()
	_show_message(&"")
	_show_controls(true)
	set_enabled(_enabled)


## Reads every box, then submits, asks, or nudges. Public so tests (and the Done button) call it.
func _on_done_pressed() -> void:
	if not _enabled or _bubble_open():
		return
	_readings = []
	for box: DigitBox in _boxes:
		_readings.append(_recognizer.recognize(box.strokes(), box.box_size()) if box.has_ink() else {})
	var read: Dictionary = SlateReader.interpret(_readings, confidence_threshold)
	for box: DigitBox in _boxes:
		box.set_flagged(false)
	match read["status"]:
		SlateReader.Status.EMPTY:
			_show_message(&"input.slate.write_first")
		SlateReader.Status.INCOMPLETE:
			_flag(read["boxes"])
			_show_message(&"input.slate.fill_boxes")
		SlateReader.Status.UNREADABLE:
			_flag(read["boxes"])
			_show_message(&"input.slate.unreadable")
		SlateReader.Status.SURE:
			_submit(int(read["value"]))
		SlateReader.Status.UNSURE:
			_pending = read
			_flag(read["boxes"])
			_show_message(&"")
			_show_controls(false)
			_bubble.ask(int(read["value"]))
			set_enabled(_enabled)


func _on_confirmed() -> void:
	if _pending.is_empty():
		return
	var value: int = int(_pending["value"])
	_pending = {}
	_bubble.close()
	_show_controls(true)
	_submit(value)


## "Try again": only the unsure boxes are wiped; the digits already read with confidence stay.
func _on_retry() -> void:
	if _pending.is_empty():
		return
	var unsure: Array = _pending["boxes"]
	_pending = {}
	_bubble.close()
	_show_controls(true)
	for index: int in unsure:
		_boxes[index].clear()
		_boxes[index].set_flagged(true)
	set_enabled(_enabled)
	answer_rejected.emit()


func _submit(value: int) -> void:
	for index: int in _readings.size():
		if not _readings[index].is_empty():
			digit_read.emit(int(_readings[index]["digit"]), bool(_readings[index].get("mirrored", false)))
	clear() # the strokes are discarded as the answer goes
	answer_submitted.emit(value)


func _flag(indexes: Array) -> void:
	for index: int in indexes:
		_boxes[index].set_flagged(true)


func _show_message(line_id: StringName) -> void:
	_message.visible = line_id != &""
	_message.text = Text.get_line(line_id) if line_id != &"" else ""


func _show_controls(shown: bool) -> void:
	if _buttons != null:
		_buttons.visible = shown


func _bubble_open() -> bool:
	return _bubble != null and _bubble.visible
