## On-screen number pad: the child's way to type a number (CLAUDE.md rule 6).
##
## Never a LineEdit: a text field would raise the system keyboard in tablet mode. The
## display is a Label; the keys are Buttons sized from UI.min_target_px() (rule 7). Works
## the same with finger, stylus and mouse because Buttons are driven by Godot's GUI. In
## laptop posture the keyboard's digits, Backspace and Enter work too.
##
## The pad only collects digits. The host scene decides what a submitted number means and
## calls clear() when it is ready for the next answer.
##
## Zone 7 (Phase 4): `allow_negative` adds a minus key beside the display, which flips the sign of the
## number (depths below zero; the "-" key on a keyboard does the same). `show_display` false hides the
## display so a host (the FractionPad) can show the entry in its own boxes.
class_name NumberPad
extends VBoxContainer

## The player pressed Go with at least one digit entered.
signal submitted(value: int)
## The entry changed (digit added, erased, cleared). `text` is what the display shows.
signal value_changed(text: String)

## Key size as a multiple of the 64 dp minimum: roomy enough for small fingers. Every key
## has the same width, wide enough for the longest label ("Erase"), so the columns line up.
const KEY_WIDTH_MULTIPLE: float = 2.5
const KEY_HEIGHT_MULTIPLE: float = 1.75
const COLUMNS: int = 3
## Phone-style order, so counting reads left to right, top to bottom.
const KEY_ORDER: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]

@export var max_digits: int = 3
## A minus key that flips the sign (numbers below zero). Set before the pad enters the tree.
@export var allow_negative: bool = false
## False hides the display (the FractionPad shows the entry in its own boxes).
@export var show_display: bool = true

var _entry: String = ""
var _enabled: bool = true
var _display: Label
var _digit_buttons: Dictionary[int, Button] = {}
var _erase_button: Button
var _go_button: Button
var _minus_button: Button


func _ready() -> void:
	theme = UI.theme()
	_build()
	_refresh()


## The digits entered so far, as text ("" when empty).
func entry() -> String:
	return _entry


## The entered number, or -1 when nothing has been entered (with the minus key, check entry()).
func value() -> int:
	return -1 if _digits().is_empty() else int(_entry)


## Replaces the entry (the FractionPad moves between its boxes). Keeps only digits and a leading minus.
func set_entry(text: String) -> void:
	var cleaned: String = ""
	for character: String in text:
		if character >= "0" and character <= "9" and cleaned.length() - int(cleaned.begins_with("-")) < max_digits:
			cleaned += character
		elif character == "-" and cleaned.is_empty() and allow_negative:
			cleaned = "-"
	_entry = cleaned
	_changed()


## Flips the sign of the entry (the minus key). Only when allow_negative.
func toggle_sign() -> void:
	if not _enabled or not allow_negative:
		return
	_entry = _entry.substr(1) if _entry.begins_with("-") else "-" + _entry
	_changed()


func minus_button() -> Button:
	return _minus_button


## Allows or blocks input (for example while Bolt's feedback is showing).
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func press_digit(digit: int) -> void:
	if not _enabled or digit < 0 or digit > 9:
		return
	if _digits() == "0":
		_entry = _entry.trim_suffix("0") # a leading zero is replaced, so "0" then "5" shows 5
	if _digits().length() >= max_digits:
		return
	_entry += str(digit)
	_changed()


func erase() -> void:
	if not _enabled or _entry.is_empty():
		return
	_entry = _entry.substr(0, _entry.length() - 1)
	_changed()


func clear() -> void:
	if _entry.is_empty():
		return
	_entry = ""
	_changed()


func submit() -> void:
	if not _enabled or _digits().is_empty():
		return
	submitted.emit(int(_entry))


## Handles a keyboard event for the pad. Returns true if the key was one of ours.
## Public so tests can drive it without engine-delivered input.
func handle_key_event(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var digit: int = _digit_for_key(event.keycode)
	if digit >= 0:
		press_digit(digit)
		return true
	if event.keycode == KEY_BACKSPACE:
		erase()
		return true
	if allow_negative and (event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT):
		toggle_sign()
		return true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		submit()
		return true
	return false


## The button for a digit, so tests and layout code can inspect it.
func digit_button(digit: int) -> Button:
	return _digit_buttons.get(digit)


func go_button() -> Button:
	return _go_button


func erase_button() -> Button:
	return _erase_button


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and is_visible_in_tree() and handle_key_event(event):
		get_viewport().set_input_as_handled()


func _build() -> void:
	add_theme_constant_override(&"separation", 16)
	_display = Label.new()
	_display.theme_type_variation = &"NumberLabel"
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.make_touch_target(_display, 1.0, 1.5)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 16)
	top.visible = show_display or allow_negative
	_display.visible = show_display
	add_child(top)
	if allow_negative:
		_minus_button = _make_key(Text.get_line(&"ui.numpad.minus"))
		_minus_button.name = "MinusButton"
		_minus_button.pressed.connect(toggle_sign)
		top.add_child(_minus_button)
	top.add_child(_display)

	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 16)
	add_child(grid)

	for digit: int in KEY_ORDER:
		grid.add_child(_make_digit_button(digit))
	_erase_button = _make_key(Text.get_line(&"ui.numpad.erase"))
	_erase_button.pressed.connect(erase)
	grid.add_child(_erase_button)
	grid.add_child(_make_digit_button(0))
	_go_button = _make_key(Text.get_line(&"ui.numpad.go"))
	_go_button.theme_type_variation = &"GoButton"
	_go_button.pressed.connect(submit)
	grid.add_child(_go_button)


func _make_digit_button(digit: int) -> Button:
	var button: Button = _make_key(str(digit))
	button.pressed.connect(press_digit.bind(digit))
	_digit_buttons[digit] = button
	return button


func _make_key(label: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE # keys are tapped, not tabbed through
	UI.make_touch_target(button, KEY_WIDTH_MULTIPLE, KEY_HEIGHT_MULTIPLE)
	return button


func _changed() -> void:
	_refresh()
	value_changed.emit(_entry)


func _refresh() -> void:
	if _display == null:
		return
	_display.text = _entry.replace("-", Text.MINUS)
	for button: Button in _digit_buttons.values():
		button.disabled = not _enabled
	_erase_button.disabled = not _enabled or _entry.is_empty()
	_go_button.disabled = not _enabled or _digits().is_empty()
	if _minus_button != null:
		_minus_button.disabled = not _enabled


## The entry without its minus sign.
func _digits() -> String:
	return _entry.trim_prefix("-")


func _digit_for_key(keycode: Key) -> int:
	if keycode >= KEY_0 and keycode <= KEY_9:
		return keycode - KEY_0
	if keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_0
	return -1
