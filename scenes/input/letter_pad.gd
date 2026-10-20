## On-screen letter pad: the child's way to type a short note (CLAUDE.md rule 6).
##
## Never a LineEdit or TextEdit: a text field would raise the system keyboard in tablet mode. The keys are
## Buttons sized from UI.min_target_px() (rule 7): A to Z in rows that wrap to the width, then Space, Delete and Clear. Works the
## same with finger, stylus and mouse because Buttons are driven by Godot's GUI; in laptop posture the keyboard's
## letters, Space and Backspace work too.
##
## The pad only emits keys. The host scene (the secret-message screen) keeps the note and decides what it means; the
## pad never stores a letter. Nothing is saved or sent anywhere.
class_name LetterPad
extends VBoxContainer

## A letter key (or Space, as " ") was pressed.
signal key_pressed(character: String)
## Delete was pressed.
signal backspace_pressed
## Clear was pressed.
signal clear_pressed

const KEY_WIDTH_MULTIPLE: float = 1.0
const KEY_HEIGHT_MULTIPLE: float = 1.0
const WIDE_KEY_WIDTH_MULTIPLE: float = 2.4

var _enabled: bool = true
var _letters: Dictionary[String, Button] = {}
var _space: Button
var _delete: Button
var _clear: Button


func _ready() -> void:
	theme = UI.theme()
	add_theme_constant_override(&"separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var grid: HFlowContainer = HFlowContainer.new() # wraps to the width it is given (a phone has four keys across)
	grid.name = "Letters"
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	add_child(grid)
	for index: int in 26:
		var letter: String = char(65 + index)
		var key: Button = Button.new()
		key.name = "Key_%s" % letter
		key.text = letter
		key.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(key, KEY_WIDTH_MULTIPLE, KEY_HEIGHT_MULTIPLE)
		key.pressed.connect(press.bind(letter))
		grid.add_child(key)
		_letters[letter] = key
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 6)
	add_child(row)
	_space = _wide_key(&"z11.pad.space", "SpaceKey")
	_space.pressed.connect(press.bind(" "))
	row.add_child(_space)
	_delete = _wide_key(&"z11.pad.delete", "DeleteKey")
	_delete.pressed.connect(backspace)
	row.add_child(_delete)
	_clear = _wide_key(&"z11.pad.clear", "ClearKey")
	_clear.pressed.connect(clear)
	row.add_child(_clear)
	_refresh()


## Presses a key: a capital letter A-Z or a space. Anything else is ignored.
func press(character: String) -> void:
	if not _enabled:
		return
	if character == " " or (character.length() == 1 and character >= "A" and character <= "Z"):
		key_pressed.emit(character)


func backspace() -> void:
	if _enabled:
		backspace_pressed.emit()


func clear() -> void:
	if _enabled:
		clear_pressed.emit()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func letter_button(letter: String) -> Button:
	return _letters[letter]


func space_button() -> Button:
	return _space


func delete_button() -> Button:
	return _delete


func clear_button() -> Button:
	return _clear


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():
		return
	if event.keycode == KEY_BACKSPACE:
		backspace()
	elif event.keycode == KEY_SPACE:
		press(" ")
	elif event.unicode >= 65 and event.unicode <= 90 or event.unicode >= 97 and event.unicode <= 122:
		press(char(event.unicode).to_upper())
	else:
		return
	get_viewport().set_input_as_handled()


func _wide_key(line_id: StringName, node_name: String) -> Button:
	var key: Button = Button.new()
	key.name = node_name
	key.text = Text.get_line(line_id)
	key.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(key, WIDE_KEY_WIDTH_MULTIPLE, KEY_HEIGHT_MULTIPLE)
	return key


func _refresh() -> void:
	for key: Button in _letters.values():
		key.disabled = not _enabled
	for key: Button in [_space, _delete, _clear]:
		if key != null:
			key.disabled = not _enabled
