## The Zone 8 pads (Sprint 35-36): number entry for answers the number pad cannot hold, never a text field
## (CLAUDE.md rule 6). Works the same with finger, stylus, mouse and keys.
##
##   SCI   scientific notation: a ones box, a fixed point, a tenths box, then "× 10" with a raised box for
##         the power (the boxes sit where the notation puts them, drawn with ExponentDisplay). Uses the
##         number pad's keys. Submits {mantissa, scale: 1, exp} exactly as typed (3.4 × 10⁵ is
##         {34, 1, 5}); a form that is not normalized is the child's answer to judge, not the pad's.
##   BASE  a number in another base: one box of digits and keys for 0 to base - 1 only (binary: 0 and 1),
##         so a digit that does not exist in the base can never be typed. Submits {base, digits} with no
##         leading zeros.
## Tap a box (SCI) to type in it; Go on a box before the last moves on. "." and "^" move on too.
class_name PowerPad
extends VBoxContainer

## The child handed in {mantissa, scale, exp} (SCI) or {base, digits} (BASE).
signal submitted(value: Dictionary)

enum Layout { SCI, BASE }

const BOX_WIDTH_MULTIPLE: float = 1.2
const BOX_HEIGHT_MULTIPLE: float = 1.2
const KEY_WIDTH_MULTIPLE: float = 1.6
const KEY_HEIGHT_MULTIPLE: float = 1.3
const BOX_FONT_SIZE: int = 48
const ACTIVE_EDGE: Color = Color("#FFD166")
const IDLE_EDGE: Color = Color(1, 1, 1, 0.35)

@export var layout: Layout = Layout.SCI
## BASE: the base (2 to 10) and how many digits the box takes.
@export var base: int = 2
@export var places: int = 6
## SCI: digits the power box takes.
@export var exponent_digits: int = 1

var _pad: NumberPad
var _boxes: Array[Button] = []
var _texts: Array[String] = []
var _limits: Array[int] = []
var _active: int = 0
var _enabled: bool = true
var _base_keys: Array[Button] = []
var _erase: Button
var _go: Button


func _ready() -> void:
	theme = UI.theme()
	add_theme_constant_override(&"separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	if layout == Layout.SCI:
		_build_sci()
	else:
		_build_base()
	select(0)


func _build_sci() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Boxes"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 6)
	add_child(row)
	row.add_child(_make_box(&"z8.pad.mantissa", 1))
	var point: Label = ExponentDisplay.make_label("Point")
	point.text = "."
	point.add_theme_font_size_override(&"font_size", ExponentDisplay.BASE_SIZE / 2)
	point.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(point)
	row.add_child(_make_box(&"z8.pad.mantissa", 1))
	var times: ExponentDisplay = ExponentDisplay.new()
	times.name = "TimesTen"
	times.size_scale = 0.5
	times.base_text = "× 10"
	times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(times)
	var power: Button = _make_box(&"z8.pad.exponent", exponent_digits)
	power.size_flags_vertical = Control.SIZE_SHRINK_BEGIN # raised, like an exponent
	row.add_child(power)
	_pad = NumberPad.new()
	_pad.name = "Keys"
	_pad.show_display = false
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_pad)
	_pad.value_changed.connect(_on_entry_changed)
	_pad.submitted.connect(func(_value: int) -> void: go())


func _build_base() -> void:
	var box: Button = _make_box(&"z8.pad.digits", clampi(places, 1, BaseGenerator.MAX_PLACES))
	UI.make_touch_target(box, maxf(BOX_WIDTH_MULTIPLE * 0.55 * float(places), 2.5), BOX_HEIGHT_MULTIPLE)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(box)
	var caption: Label = Label.new()
	caption.name = "Base"
	caption.text = Text.get_line(&"z8.notation.base_words", {"b": base})
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Keys"
	grid.columns = mini(clampi(base, 2, 10) + 2, 5) # one or two short rows: fits a landscape phone
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	for digit: int in clampi(base, 2, 10):
		var key: Button = _key(str(digit))
		key.name = "Digit%d" % digit
		key.pressed.connect(press_digit.bind(digit))
		grid.add_child(key)
		_base_keys.append(key)
	_erase = _key(Text.get_line(&"ui.numpad.erase"))
	_erase.name = "Erase"
	_erase.pressed.connect(erase)
	grid.add_child(_erase)
	_go = _key(Text.get_line(&"ui.numpad.go"))
	_go.name = "Go"
	_go.theme_type_variation = &"GoButton"
	_go.pressed.connect(go)
	grid.add_child(_go)


## The boxes' text so far.
func texts() -> Array[String]:
	return _texts.duplicate()


func box(index: int) -> Button:
	return _boxes[index]


func box_count() -> int:
	return _boxes.size()


func active_box() -> int:
	return _active


## The key for a digit on the BASE pad (null for a digit the base does not have).
func base_key(digit: int) -> Button:
	return _base_keys[digit] if digit >= 0 and digit < _base_keys.size() else null


func select(index: int) -> void:
	_active = clampi(index, 0, _boxes.size() - 1)
	if _pad != null:
		_pad.max_digits = _limits[_active]
		_pad.set_entry(_texts[_active])
	_refresh()


## Types one digit into the active box. On the BASE pad a digit the base does not have is ignored.
func press_digit(digit: int) -> void:
	if not _enabled:
		return
	if layout == Layout.BASE:
		if digit < 0 or digit >= base or _texts[0].length() >= _limits[0]:
			return
		_texts[0] += str(digit)
		_refresh()
		return
	_pad.press_digit(digit)


func erase() -> void:
	if not _enabled:
		return
	if layout == Layout.BASE:
		_texts[0] = _texts[0].substr(0, maxi(_texts[0].length() - 1, 0))
		_refresh()
		return
	if _texts[_active].is_empty() and _active > 0:
		select(_active - 1)
	_pad.erase()


## Go: on a box before the last, move on; on the last, hand in the answer once every box has a digit.
func go() -> void:
	if not _enabled or _texts[_active].is_empty():
		return
	for index: int in _boxes.size():
		if _texts[index].is_empty():
			select(index)
			return
	submitted.emit(value())


## The value the boxes hold ({} while a box is empty).
func value() -> Dictionary:
	for text: String in _texts:
		if text.is_empty():
			return {}
	if layout == Layout.BASE:
		var digits: Array[int] = []
		for character: String in _texts[0]:
			digits.append(int(character))
		return {"base": base, "digits": Notation.trimmed(digits)}
	return Notation.sci(int(_texts[0]) * 10 + int(_texts[1]), 1, int(_texts[2]))


func clear() -> void:
	for index: int in _texts.size():
		_texts[index] = ""
	select(0)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _pad != null:
		_pad.set_enabled(enabled)
	_refresh()


## Keyboard: "." and "^" move to the next box (SCI); on the BASE pad the digits, Backspace and Enter.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not is_visible_in_tree() or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if layout == Layout.SCI:
		if key == KEY_PERIOD or key == KEY_KP_PERIOD or key == KEY_ASCIICIRCUM or key == KEY_TAB:
			select(mini(_active + 1, _boxes.size() - 1))
			get_viewport().set_input_as_handled()
		return
	var digit: int = -1
	if key >= KEY_0 and key <= KEY_9:
		digit = key - KEY_0
	elif key >= KEY_KP_0 and key <= KEY_KP_9:
		digit = key - KEY_KP_0
	if digit >= 0:
		press_digit(digit)
	elif key == KEY_BACKSPACE:
		erase()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		go()
	else:
		return
	get_viewport().set_input_as_handled()


func _make_box(caption_line: StringName, limit: int) -> Button:
	var button: Button = Button.new()
	button.name = "Box%d" % _boxes.size()
	button.theme_type_variation = &"NumberLabel"
	button.add_theme_font_size_override(&"font_size", BOX_FONT_SIZE) # a box one touch target tall, not the big number size
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = Text.get_line(caption_line)
	UI.make_touch_target(button, BOX_WIDTH_MULTIPLE, BOX_HEIGHT_MULTIPLE)
	button.pressed.connect(select.bind(_boxes.size()))
	_boxes.append(button)
	_texts.append("")
	_limits.append(limit)
	return button


func _key(label: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(button, KEY_WIDTH_MULTIPLE, KEY_HEIGHT_MULTIPLE)
	return button


func _on_entry_changed(text: String) -> void:
	_texts[_active] = text
	if text.length() >= _limits[_active] and _active < _boxes.size() - 1:
		select(_active + 1) # a full box moves on by itself (keys, taps and the keyboard alike)
		return
	_refresh()


func _refresh() -> void:
	for index: int in _boxes.size():
		var button: Button = _boxes[index]
		button.text = _texts[index] if not _texts[index].is_empty() else "_"
		button.disabled = not _enabled
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.08)
			style.border_color = ACTIVE_EDGE if index == _active else IDLE_EDGE
			style.set_border_width_all(6 if index == _active else 2)
			style.set_corner_radius_all(12)
			button.add_theme_stylebox_override(state, style)
	for key: Button in _base_keys:
		key.disabled = not _enabled
	if _erase != null:
		_erase.disabled = not _enabled or _texts[0].is_empty()
		_go.disabled = not _enabled or _texts[0].is_empty()
