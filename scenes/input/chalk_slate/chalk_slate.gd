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
##
## Layouts (Phase 4, Sprint 32). Every box is still one digit, so the recognizer is unchanged:
##   ROW       one row of boxes, ones on the right (setup)
##   FRACTION  a row of top boxes, a drawn bar (the vinculum, not interactive), a row of bottom boxes
##             (setup_fraction); hands in {num, den} and asks "Did you write 3 over 4?" when unsure
##   DECIMAL   the ones boxes, a fixed point, then exactly `places` boxes (setup_decimal); the child
##             writes digits only, never the point; hands in {mantissa, scale}, normalized
## answer_written carries the value of every layout; answer_submitted stays the ROW signal.
class_name ChalkSlate
extends VBoxContainer

## The child's number is ready (read with confidence, or confirmed with Yes). ROW layout only.
signal answer_submitted(value: int)
## The child's answer is ready in any layout: an int (ROW), {num, den} (FRACTION) or {mantissa, scale}
## (DECIMAL).
signal answer_written(value: Variant)
## The child said "Try again" to a confirmation. Not an incorrect attempt.
signal answer_rejected
## The slate cannot work here (no recognizer); the host should show the number pad instead.
signal fell_back_to_number_pad
## A digit was read and accepted as part of a submitted number. `mirrored` is true when it was
## written backwards (for numeral coaching).
signal digit_read(digit: int, mirrored: bool)

enum Layout { ROW, FRACTION, DECIMAL }

const BOX_SCENE: PackedScene = preload("res://scenes/input/chalk_slate/digit_box.tscn")
var _last_confirmed: bool = false

const BUBBLE_SCENE: PackedScene = preload("res://scenes/input/chalk_slate/confirm_bubble.tscn")
const PLACE_LINES: Array[StringName] = [&"input.slate.place_ones", &"input.slate.place_tens", &"input.slate.place_hundreds"]
## Fraction and decimal boxes are square, in touch-target multiples: at least 1.5 (the plan's
## minimum), larger when the window has room for two rows (computed from the viewport, not fixed).
const SMALL_BOX_MIN: float = 1.5
const SMALL_BOX_MAX: float = 2.2
const VINCULUM_COLOR: Color = Color("#F5F7FF")

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
var _layout: Layout = Layout.ROW
## The box indexes of each part, in reading order: one group for ROW, [top, bottom] for FRACTION,
## [ones, places] for DECIMAL.
var _groups: Array[Array] = []
var _decimal_places: int = 0


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
	if not _start(Layout.ROW, recognizer):
		return
	var row: HBoxContainer = _row("Boxes", 24)
	add_child(row)
	var digits: int = clampi(answer_digits, 1, PLACE_LINES.size())
	var group: Array[int] = []
	for position: int in digits:
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 6)
		row.add_child(column)
		group.append(_boxes.size())
		column.add_child(_new_box(DigitBox.WIDTH_MULTIPLE, DigitBox.HEIGHT_MULTIPLE))
		var caption: Label = Label.new()
		caption.text = Text.get_line(PLACE_LINES[digits - 1 - position])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.modulate = Color(1, 1, 1, 0.75)
		column.add_child(caption)
	_groups = [group]
	_finish_setup()


## FRACTION: `top_digits` boxes over a bar over `bottom_digits` boxes (a blank leading box is fine, so
## two boxes take 3 or 12). Hands in {num, den}.
func setup_fraction(top_digits: int, bottom_digits: int, recognizer: Recognizer) -> void:
	if not _start(Layout.FRACTION, recognizer):
		return
	_prompt.text = Text.get_line(&"z7.slate.prompt_fraction")
	var side: float = small_box_multiple()
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Boxes"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 8)
	add_child(stack)
	var widest: int = clampi(maxi(top_digits, bottom_digits), 1, 3)
	for part: int in 2:
		var row: HBoxContainer = _row("Top" if part == 0 else "Bottom", 12)
		var group: Array[int] = []
		for position: int in clampi(top_digits if part == 0 else bottom_digits, 1, 3):
			group.append(_boxes.size())
			row.add_child(_new_box(side, side))
		_groups.append(group)
		stack.add_child(row)
		if part == 0:
			var bar: ColorRect = ColorRect.new()
			bar.name = "Vinculum"
			bar.color = VINCULUM_COLOR
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE # drawn, never written on
			bar.custom_minimum_size = Vector2(UI.target_size(side * widest + 0.4, 1.0).x, 6)
			bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			stack.add_child(bar)
	_finish_setup()


## DECIMAL: `whole_digits` boxes for the ones, a fixed point, then `places` boxes. A blank ones box
## reads as 0 (".5" is 0.5). Hands in {mantissa, scale}, normalized.
func setup_decimal(whole_digits: int, places: int, recognizer: Recognizer) -> void:
	if not _start(Layout.DECIMAL, recognizer):
		return
	_prompt.text = Text.get_line(&"z7.slate.prompt_decimal")
	_decimal_places = clampi(places, 1, 3)
	var side: float = small_box_multiple()
	var row: HBoxContainer = _row("Boxes", 12)
	add_child(row)
	for part: int in 2:
		var group: Array[int] = []
		for position: int in (clampi(whole_digits, 1, 2) if part == 0 else _decimal_places):
			group.append(_boxes.size())
			row.add_child(_new_box(side, side * 1.2))
		_groups.append(group)
		if part == 0:
			var point: Label = Label.new()
			point.name = "Point"
			point.text = "."
			point.theme_type_variation = &"NumberLabel"
			point.size_flags_vertical = Control.SIZE_SHRINK_END
			point.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(point)
	_finish_setup()


func layout() -> Layout:
	return _layout


## The square box size for the fraction and decimal layouts, in touch-target multiples: as big as two
## rows of boxes, the bar, the buttons and the prompt allow on this window, within 1.5 and 2.2.
static func small_box_multiple() -> float:
	var target: float = float(UI.min_target_px())
	var height: float = 800.0
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		height = float(tree.root.get_visible_rect().size.y)
	# The panel gets about two thirds of the screen; the prompt, buttons and gaps take about 3 targets.
	var room: float = (height * 0.66 / target - 3.0) / 2.0
	return clampf(room, SMALL_BOX_MIN, SMALL_BOX_MAX)


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
	var read: Dictionary = _interpret_groups()
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
			_submit(read["value"])
		SlateReader.Status.UNSURE:
			_pending = read
			_flag(read["boxes"])
			_show_message(&"")
			_show_controls(false)
			_ask(read["value"])
			set_enabled(_enabled)


func _on_confirmed() -> void:
	if _pending.is_empty():
		return
	var value: Variant = _pending["value"]
	_pending = {}
	_bubble.close()
	_show_controls(true)
	_submit(value, true)


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


## True when the last submitted answer needed "Did you write 47?" and the child said Yes (the
## dashboard's handwriting confirmation rate, Sprint 21).
func last_answer_confirmed() -> bool:
	return _last_confirmed


## Clears the slate for a new layout. False (and the number pad fallback) when there is no recognizer.
func _start(new_layout: Layout, recognizer: Recognizer) -> bool:
	_recognizer = recognizer
	_layout = new_layout
	_prompt.text = Text.get_line(&"input.slate.prompt")
	for child: Node in get_children():
		if child != _prompt and child != _message:
			child.queue_free()
			remove_child(child)
	_boxes.clear()
	_groups.clear()
	if recognizer == null:
		fell_back_to_number_pad.emit.call_deferred()
		return false
	return true


func _row(row_name: String, separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = row_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", separation)
	return row


func _new_box(width_multiple: float, height_multiple: float) -> DigitBox:
	var box: DigitBox = BOX_SCENE.instantiate()
	box.router = router
	box.width_multiple = width_multiple
	box.height_multiple = height_multiple
	box.name = "DigitBox%d" % _boxes.size()
	_boxes.append(box)
	return box


func _finish_setup() -> void:
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


## "Did you write 47?", "Did you write 3 over 4?" or "Did you write 2.75?"
func _ask(value: Variant) -> void:
	match _layout:
		Layout.FRACTION:
			_bubble.ask_line(&"z7.slate.confirm_fraction", {"num": int(value["num"]), "den": int(value["den"])})
		Layout.DECIMAL:
			_bubble.ask_line(&"z7.slate.confirm_decimal", {"d": value})
		_:
			_bubble.ask(int(value))


## Reads each group of boxes with SlateReader and combines them: the first group that is not ready
## decides (every box blank is EMPTY; a DECIMAL's blank ones group reads as 0, but every place after
## the point must be written). `boxes` in the result are slate box indexes.
func _interpret_groups() -> Dictionary:
	var parts: Array[Dictionary] = []
	var all_empty: bool = true
	for group: Array in _groups:
		var readings: Array[Dictionary] = []
		for index: int in group:
			readings.append(_readings[index])
		var read: Dictionary = SlateReader.interpret(readings, confidence_threshold)
		var slate_boxes: Array[int] = []
		for local: int in read["boxes"]:
			slate_boxes.append(int(group[local]))
		read["boxes"] = slate_boxes
		if read["status"] == SlateReader.Status.EMPTY:
			read["boxes"] = GeneratorKit.ints_of(group)
		else:
			all_empty = false
		parts.append(read)
	if all_empty:
		return {"status": SlateReader.Status.EMPTY, "value": -1, "boxes": [] as Array[int]}
	var unsure: Array[int] = []
	for index: int in parts.size():
		var read: Dictionary = parts[index]
		if _layout == Layout.DECIMAL and index == 0 and read["status"] == SlateReader.Status.EMPTY:
			read["value"] = 0 # no ones written: 0.5
			continue
		if read["status"] == SlateReader.Status.EMPTY:
			return {"status": SlateReader.Status.INCOMPLETE, "value": -1, "boxes": read["boxes"]}
		if read["status"] == SlateReader.Status.INCOMPLETE or read["status"] == SlateReader.Status.UNREADABLE:
			return read
		if _layout == Layout.DECIMAL and index == 1:
			var blank: Array[int] = _blank_boxes(_groups[1])
			if not blank.is_empty(): # a blank first place would read as a leading zero
				return {"status": SlateReader.Status.INCOMPLETE, "value": -1, "boxes": blank}
		if read["status"] == SlateReader.Status.UNSURE:
			unsure.append_array(read["boxes"])
	var value: Variant = int(parts[0]["value"])
	match _layout:
		Layout.FRACTION:
			value = {"num": int(parts[0]["value"]), "den": int(parts[1]["value"])}
		Layout.DECIMAL:
			value = Rational.normalize_decimal(int(parts[0]["value"]) * Rational.pow10(_decimal_places) + int(parts[1]["value"]), _decimal_places)
	return {"status": SlateReader.Status.UNSURE if not unsure.is_empty() else SlateReader.Status.SURE, "value": value, "boxes": unsure}


func _blank_boxes(group: Array) -> Array[int]:
	var blank: Array[int] = []
	for index: Variant in group:
		if _readings[int(index)].is_empty():
			blank.append(int(index))
	return blank


func _submit(value: Variant, confirmed: bool = false) -> void:
	_last_confirmed = confirmed
	var readings: Array[Dictionary] = _readings.duplicate()
	clear() # the strokes are discarded as the answer goes
	# The answer first: a digit_read listener may put a demonstration over the panel and disable it,
	# and an answer that arrives at a disabled panel is dropped.
	if _layout == Layout.ROW:
		answer_submitted.emit(int(value))
	answer_written.emit(value)
	for reading: Dictionary in readings:
		if not reading.is_empty():
			digit_read.emit(int(reading["digit"]), bool(reading.get("mirrored", false)))


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
