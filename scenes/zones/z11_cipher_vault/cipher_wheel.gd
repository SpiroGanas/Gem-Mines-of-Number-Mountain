## The cipher wheel (Zone 11, Cipher Vault; meta.cipher_wheel = {text, max}): two rings of letters, plain letters
## outside and code letters inside, and a row of cards that shows the code with every letter moved BACK by the shift
## the wheel is set to. The child turns the wheel with Back and Forward until the cards spell a word, then presses
## Set, which hands the shift in. The secret-message screen uses the same wheel to choose a shift (no code to read).
##
## Buttons work the same with finger, stylus and mouse; the Left and Right arrows turn the wheel and Enter sets it.
## The widget never says whether the shift is right; the host decides. The rules (moving letters) live in
## CipherGenerator; this scene only draws them (VaultArt).
class_name CipherWheel
extends VBoxContainer

## Set was pressed: the shift the wheel is on.
signal submitted(shift: int)
## The wheel turned (for a click).
signal turned(shift: int)

const BUTTON_WIDTH_MULTIPLE: float = 2.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.2
const PICTURE_WIDTH_MULTIPLE: float = 6.0
const PICTURE_HEIGHT_MULTIPLE: float = 3.4

## The code on the cards, before it is turned back ("" on the secret-message screen).
var code: String = ""
var max_shift: int = 25
var shift: int = 0

var _picture: _WheelPicture
var _back: Button
var _forward: Button
var _set: Button
var _shift_label: Label
var _how: Label
var _enabled: bool = true


func _init() -> void:
	add_theme_constant_override(&"separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Builds the wheel; `spec` is meta.cipher_wheel.
func setup(spec: Dictionary) -> void:
	code = str(spec.get("text", ""))
	max_shift = int(spec.get("max", 25))
	shift = 0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_how = Label.new()
	_how.name = "How"
	_how.text = Text.get_line(&"z11.wheel.how")
	_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_how)
	_picture = _WheelPicture.new()
	_picture.name = "Wheel"
	_picture.wheel = self
	UI.make_touch_target(_picture, PICTURE_WIDTH_MULTIPLE, PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Controls"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)
	_back = _button(&"z11.wheel.back", "BackButton")
	_back.pressed.connect(turn.bind(-1))
	row.add_child(_back)
	_shift_label = Label.new()
	_shift_label.name = "Shift"
	_shift_label.theme_type_variation = &"NumberLabel"
	row.add_child(_shift_label)
	_forward = _button(&"z11.wheel.forward", "ForwardButton")
	_forward.pressed.connect(turn.bind(1))
	row.add_child(_forward)
	_set = _button(&"z11.wheel.set", "SetButton")
	_set.theme_type_variation = &"GoButton"
	_set.pressed.connect(submit)
	row.add_child(_set)
	_refresh()


## Turns the wheel `steps` places (positive: forward), round the 26 letters but within 0 to max_shift.
func turn(steps: int) -> void:
	if not _enabled:
		return
	var before: int = shift
	shift = clampi(shift + steps, 0, max_shift)
	if shift != before:
		turned.emit(shift)
	_refresh()


## Sets the wheel straight to a shift (tests and the keyboard).
func set_shift(new_shift: int) -> void:
	shift = clampi(new_shift, 0, max_shift)
	_refresh()


func submit() -> void:
	if _enabled:
		submitted.emit(shift)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


## The code on the cards with the wheel's shift undone.
func shown_text() -> String:
	return CipherGenerator.shift_text(code, -shift)


func back_button() -> Button:
	return _back


func forward_button() -> Button:
	return _forward


func set_button() -> Button:
	return _set


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():
		return
	match event.keycode:
		KEY_LEFT:
			turn(-1)
		KEY_RIGHT:
			turn(1)
		KEY_ENTER, KEY_KP_ENTER:
			submit()
		_:
			return
	get_viewport().set_input_as_handled()


func _button(line_id: StringName, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	return button


func _refresh() -> void:
	if _back == null:
		return
	_back.disabled = not _enabled or shift <= 0
	_forward.disabled = not _enabled or shift >= max_shift
	_set.disabled = not _enabled
	_shift_label.text = Text.get_line(&"z11.wheel.shift", {"k": shift})
	if _picture != null:
		_picture.queue_redraw()


## The wheel and, when there is a code, the cards that show it turned back by the shift.
class _WheelPicture:
	extends Control

	var wheel: CipherWheel

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if wheel == null:
			return
		var picture: Dictionary = CipherGenerator.cipher_picture(wheel.shown_text() if wheel.code != "" else "", wheel.shift)
		if wheel.code == "":
			var side: float = minf(size.x, size.y)
			VaultArt.draw_wheel(self, size / 2.0, side / 2.0 - 4.0, wheel.shift, get_theme_default_font())
			return
		VaultArt.draw_cipher(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), picture, get_theme_default_font())
