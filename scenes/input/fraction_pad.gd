## The fraction and decimal pad (Zone 7): the number pad's keys beside or under two answer boxes, so
## a child types a fraction (top over bottom) or a decimal (ones, a fixed point, then the places)
## without a text field (CLAUDE.md rule 6). It is the slate's fallback when handwriting is
## unavailable (no touch screen, switched off, mouse-only devices) and works the same with finger,
## stylus, mouse and keys.
##
##   FRACTION  the top box over a bar over the bottom box; submits {num, den}
##   DECIMAL   the ones box, the point, the places box (exactly `decimal_places` digits; fewer typed
##             digits count as trailing zeros, so 5 typed after the point is 0.5); submits
##             {mantissa, scale}, normalized
## Tap a box to type in it; Go on the first box moves to the next one, Go on the last hands in the
## answer once every box has a number. The "/" and "." keys move on too. Presentation only: the pad
## never says whether the answer is right.
class_name FractionPad
extends VBoxContainer

## The child handed in a fraction {num, den} or a decimal {mantissa, scale}.
signal submitted(value: Dictionary)

enum Layout { FRACTION, DECIMAL }

const BOX_WIDTH_MULTIPLE: float = 2.5
const BOX_HEIGHT_MULTIPLE: float = 1.25
const ACTIVE_EDGE: Color = Color("#FFD166")
const IDLE_EDGE: Color = Color(1, 1, 1, 0.35)

@export var layout: Layout = Layout.FRACTION
## Digits each box takes (the top, the bottom, or the ones).
@export var box_digits: int = 2
## DECIMAL only: digits after the point.
@export var decimal_places: int = 1

var _pad: NumberPad
var _boxes: Array[Button] = []
var _texts: Array[String] = []
var _active: int = 0
var _enabled: bool = true


func _ready() -> void:
	theme = UI.theme()
	add_theme_constant_override(&"separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var how: Label = Label.new()
	how.name = "How"
	how.text = Text.get_line(&"z7.pad.pick_box")
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.modulate = Color(1, 1, 1, 0.8)
	add_child(how)
	var holder: BoxContainer = VBoxContainer.new() if layout == Layout.FRACTION else HBoxContainer.new()
	holder.name = "Boxes"
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override(&"separation", 6)
	add_child(holder)
	if layout == Layout.FRACTION:
		holder.add_child(_make_box(&"z7.pad.top"))
		var bar: ColorRect = ColorRect.new()
		bar.name = "Vinculum"
		bar.color = Color("#F5F7FF")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(UI.target_size(BOX_WIDTH_MULTIPLE, 1.0).x, 6)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(bar)
		holder.add_child(_make_box(&"z7.pad.bottom"))
	else:
		holder.add_child(_make_box(&""))
		var point: Label = Label.new()
		point.name = "Point"
		point.text = "."
		point.theme_type_variation = &"NumberLabel"
		point.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		holder.add_child(point)
		holder.add_child(_make_box(&""))
	_pad = NumberPad.new()
	_pad.name = "Keys"
	_pad.show_display = false
	_pad.max_digits = _limit(0)
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Room is short beside the picture under Bolt. A fraction's boxes stand to the left of the keys (top
	# over bottom is tall). A decimal's boxes are a row: they stay over the keys, which are the wide
	# pad's three rows (on a phone the keys are always the wide pad's, NumberPad.is_wide).
	_pad.wide = layout == Layout.DECIMAL
	if layout == Layout.FRACTION:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Row"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 24)
		remove_child(holder)
		row.add_child(holder)
		row.add_child(_pad)
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(row)
	else:
		add_child(_pad)
	_pad.value_changed.connect(_on_entry_changed)
	_pad.submitted.connect(func(_value: int) -> void: go())
	select(0)


## The boxes' text so far: [top, bottom] or [ones, places].
func texts() -> Array[String]:
	return _texts.duplicate()


func box(index: int) -> Button:
	return _boxes[index]


func keys() -> NumberPad:
	return _pad


func active_box() -> int:
	return _active


## Makes box `index` the one the keys type into.
func select(index: int) -> void:
	_active = clampi(index, 0, _boxes.size() - 1)
	_pad.max_digits = _limit(_active)
	_pad.set_entry(_texts[_active])
	_refresh()


## Types one digit into the active box (also what the keys do).
func press_digit(digit: int) -> void:
	_pad.press_digit(digit)


## Go: on a box before the last, move to the next box; on the last, hand in the answer when every box
## has a number (an empty box gets picked instead).
func go() -> void:
	if not _enabled:
		return
	if _texts[_active].is_empty():
		return
	for index: int in _boxes.size():
		if _texts[index].is_empty():
			select(index)
			return
	submitted.emit(value())


## The value the boxes hold now ({} while a box is empty).
func value() -> Dictionary:
	for text: String in _texts:
		if text.is_empty():
			return {}
	if layout == Layout.FRACTION:
		return {"num": int(_texts[0]), "den": int(_texts[1])}
	var places: String = _texts[1]
	while places.length() < decimal_places:
		places += "0" # 5 typed after the point is 0.5
	return Rational.normalize_decimal(int(_texts[0]) * Rational.pow10(decimal_places) + int(places), decimal_places)


## Empties every box and goes back to the first.
func clear() -> void:
	for index: int in _texts.size():
		_texts[index] = ""
	select(0)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_pad.set_enabled(enabled)
	for button: Button in _boxes:
		button.disabled = not enabled


## Keyboard: "/" or "." moves to the next box; the digits, Backspace and Enter go to the keys.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not is_visible_in_tree() or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if key == KEY_SLASH or key == KEY_KP_DIVIDE or key == KEY_PERIOD or key == KEY_KP_PERIOD:
		select(mini(_active + 1, _boxes.size() - 1))
		get_viewport().set_input_as_handled()


func _make_box(caption_line: StringName) -> Button:
	var button: Button = Button.new()
	button.name = "Box%d" % _boxes.size()
	button.theme_type_variation = &"NumberLabel"
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = Text.get_line(caption_line) if caption_line != &"" else ""
	UI.make_touch_target(button, BOX_WIDTH_MULTIPLE, BOX_HEIGHT_MULTIPLE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(select.bind(_boxes.size()))
	_boxes.append(button)
	_texts.append("")
	return button


func _limit(index: int) -> int:
	return decimal_places if layout == Layout.DECIMAL and index == 1 else box_digits


func _on_entry_changed(text: String) -> void:
	_texts[_active] = text
	_refresh()


func _refresh() -> void:
	for index: int in _boxes.size():
		var button: Button = _boxes[index]
		var shown: String = _texts[index]
		if layout == Layout.DECIMAL and index == 1:
			while shown.length() < decimal_places:
				shown += "_"
		button.text = shown if not shown.is_empty() else "_"
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.08)
			style.border_color = ACTIVE_EDGE if index == _active else IDLE_EDGE
			style.set_border_width_all(6 if index == _active else 2)
			style.set_corner_radius_all(12)
			button.add_theme_stylebox_override(state, style)
