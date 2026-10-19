## Keyboard entry (Scholar mode part 1, Sprint 37, P4-S37-04): the child types the answer on a physical
## keyboard. It is NOT a LineEdit or TextEdit (CLAUDE.md rule 6, lint rule 2): a plain Control that reads
## keys in _unhandled_key_input and draws what was typed itself, so no system keyboard ever appears.
## It is shown only when ModeGate's KEYBOARD_ENTRY is on for the child (Scholar mode and a key already
## pressed this session) and the skill lists the `keyboard` answer mode; "Use the pad" swaps the
## on-screen pad back in at any time, so a tablet that lost its keyboard never strands the child.
##
## What it takes, by `kind`:
##   INTEGER   digits; "-" flips the sign when `allow_negative`              gives an int
##   FRACTION  digits, "/" to go to the bottom                                 gives {num, den}
##   DECIMAL   digits and one "."                                             gives {mantissa, scale}
##   SCI       the first number (digits and one "."), then "^", "x", "*" or Tab, then the power of 10
##             (shown as real notation: 3.4 × 10⁵)                            gives {mantissa, scale, exp}
##   BASE      the digits 0 to base - 1 only                                   gives {base, digits}
## Backspace erases (the plan's `ui_erase`), Enter hands in (`ui_submit`); any other key is ignored.
## Go and Erase buttons do the same for a mouse or a finger.
class_name KeyboardEntry
extends VBoxContainer

## Enter (or Go) with something typed: the value in the answer's shape.
signal submitted(value: Variant)
## "Use the pad" was pressed: the host swaps the on-screen pad in.
signal pad_requested
## What is typed changed (for tests and a sound).
signal entry_changed(text: String)

enum Kind { INTEGER, FRACTION, DECIMAL, SCI, BASE }

const BUTTON_WIDTH_MULTIPLE: float = 2.4
const BUTTON_HEIGHT_MULTIPLE: float = 1.2
const MAX_FIELD: int = 7

@export var kind: Kind = Kind.INTEGER
@export var allow_negative: bool = false
@export var max_digits: int = 3
## BASE only.
@export var base: int = 2

## The typed text of each field: one field, or two (fraction top and bottom; SCI number and power).
var _fields: Array[String] = [""]
var _field: int = 0
var _enabled: bool = true
var _display: Label
var _power: ExponentDisplay
var _go: Button
var _erase: Button
var _use_pad: Button


func _ready() -> void:
	theme = UI.theme()
	add_theme_constant_override(&"separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	if kind == Kind.FRACTION or kind == Kind.SCI:
		_fields = ["", ""]
	var how: Label = Label.new()
	how.name = "How"
	how.text = Text.get_line(&"ui.keyboard.how")
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(how)
	if kind == Kind.SCI:
		_power = ExponentDisplay.new()
		_power.name = "Typed"
		_power.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_power)
	else:
		_display = Label.new()
		_display.name = "Typed"
		_display.theme_type_variation = &"NumberLabel"
		_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_display)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	_erase = _button(&"ui.numpad.erase", "EraseButton")
	_erase.pressed.connect(erase)
	row.add_child(_erase)
	_go = _button(&"ui.numpad.go", "GoButton")
	_go.theme_type_variation = &"GoButton"
	_go.pressed.connect(submit)
	row.add_child(_go)
	# "Use the pad" on a row of its own: beside Erase and Go the row ran off a 16:9 screen.
	_use_pad = _button(&"ui.keyboard.use_pad", "UsePadButton")
	_use_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_use_pad.pressed.connect(func() -> void: pad_requested.emit())
	add_child(_use_pad)
	_refresh()


## What is typed, as shown ("3/4", "3.4^5", "-12").
func entry() -> String:
	match kind:
		Kind.FRACTION:
			return _fields[0] + ("/" + _fields[1] if _field == 1 or not _fields[1].is_empty() else "")
		Kind.SCI:
			return _fields[0] + ("^" + _fields[1] if _field == 1 or not _fields[1].is_empty() else "")
	return _fields[0]


## Handles one key. Returns true when the key was one of ours (digits, the kind's symbols, Backspace,
## Enter); everything else is left alone. Public so tests can type without the engine.
func handle_key_event(event: InputEventKey) -> bool:
	if not event.pressed or event.echo or not _enabled:
		return false
	var key: Key = event.keycode
	var digit: int = -1
	if key >= KEY_0 and key <= KEY_9:
		digit = key - KEY_0
	elif key >= KEY_KP_0 and key <= KEY_KP_9:
		digit = key - KEY_KP_0
	if digit >= 0:
		type_digit(digit)
		return true
	match key:
		KEY_BACKSPACE:
			erase()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			submit()
			return true
		KEY_MINUS, KEY_KP_SUBTRACT:
			if kind == Kind.INTEGER and allow_negative:
				_fields[0] = _fields[0].substr(1) if _fields[0].begins_with("-") else "-" + _fields[0]
				_changed()
				return true
		KEY_SLASH, KEY_KP_DIVIDE:
			if kind == Kind.FRACTION and _field == 0 and not _fields[0].is_empty():
				_field = 1
				_changed()
				return true
		KEY_PERIOD, KEY_KP_PERIOD:
			if (kind == Kind.DECIMAL or (kind == Kind.SCI and _field == 0)) and not _fields[_field].contains("."):
				_fields[_field] += "." if not _fields[_field].is_empty() else "0."
				_changed()
				return true
		KEY_ASCIICIRCUM, KEY_X, KEY_ASTERISK, KEY_KP_MULTIPLY, KEY_TAB, KEY_E:
			if kind == Kind.SCI and _field == 0 and not _fields[0].is_empty():
				_field = 1
				_changed()
				return true
	return false


## Types a digit into the field being typed (a base's missing digits are ignored).
func type_digit(digit: int) -> void:
	if not _enabled or digit < 0 or digit > 9:
		return
	if kind == Kind.BASE and digit >= base:
		return
	var text: String = _fields[_field]
	if text.replace("-", "").replace(".", "").length() >= _limit(_field):
		return
	_fields[_field] = text + str(digit)
	_changed()


## The digits a field takes: scientific notation's first number 3 (3.4, or 34 as typed), its power 2.
func _limit(field: int) -> int:
	if kind == Kind.SCI:
		return 3 if field == 0 else 2
	return clampi(max_digits, 1, MAX_FIELD)


func erase() -> void:
	if not _enabled:
		return
	if _fields[_field].is_empty() and _field > 0:
		_field -= 1
	else:
		_fields[_field] = _fields[_field].substr(0, maxi(_fields[_field].length() - 1, 0))
	_changed()


## Enter or Go: hands in the value once it is complete (every field has a digit).
func submit() -> void:
	if not _enabled:
		return
	var given: Variant = value()
	if given == null:
		return
	submitted.emit(given)


## The typed value in the answer's shape, or null while it is not complete.
func value() -> Variant:
	for index: int in _fields.size():
		if _fields[index].replace("-", "").replace(".", "").is_empty():
			return null
	match kind:
		Kind.FRACTION:
			return {"num": int(_fields[0]), "den": int(_fields[1])}
		Kind.DECIMAL:
			return _decimal(_fields[0])
		Kind.SCI:
			var first: Dictionary = _decimal(_fields[0])
			return Notation.sci(int(first["mantissa"]), int(first["scale"]), int(_fields[1]))
		Kind.BASE:
			var digits: Array[int] = []
			for character: String in _fields[0]:
				digits.append(int(character))
			return {"base": base, "digits": Notation.trimmed(digits)}
	return int(_fields[0])


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func clear() -> void:
	for index: int in _fields.size():
		_fields[index] = ""
	_field = 0
	_changed()


func go_button() -> Button:
	return _go


func use_pad_button() -> Button:
	return _use_pad


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and is_visible_in_tree() and handle_key_event(event):
		get_viewport().set_input_as_handled()


## "3.40" as {mantissa: 34, scale: 1}: digits after the point give the scale, trailing zeros dropped.
static func _decimal(text: String) -> Dictionary:
	var parts: PackedStringArray = text.split(".")
	var whole: String = parts[0] if not parts[0].is_empty() else "0"
	var places: String = parts[1] if parts.size() > 1 else ""
	return Rational.normalize_decimal(int(whole + places), places.length())


func _button(line_id: StringName, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	return button


func _changed() -> void:
	_refresh()
	entry_changed.emit(entry())


func _refresh() -> void:
	if _go == null:
		return
	if _power != null:
		var first: String = _fields[0] if not _fields[0].is_empty() else "_"
		_power.base_text = first + " × 10"
		_power.exponent_text = _fields[1] if not _fields[1].is_empty() else ("_" if _field == 1 else "")
	else:
		var shown: String = entry().replace("-", Text.MINUS)
		_display.text = shown if not shown.is_empty() else "_"
	_go.disabled = not _enabled or value() == null
	_erase.disabled = not _enabled or entry().is_empty()
	_use_pad.disabled = not _enabled
