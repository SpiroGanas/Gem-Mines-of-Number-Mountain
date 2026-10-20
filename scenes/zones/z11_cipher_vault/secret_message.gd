## The secret message (Zone 11, Cipher Vault; P5-S45-08), reached from the Gem Museum once the child can encode with a
## Caesar shift. The child types a short note on the letter pad (A to Z and space, at most 40 letters), picks a code
## (a shift, or a times-and-shift once the affine cipher is learned) and sees the coded note in big letters with a key
## card. Bolt says to show it to a grown-up: can they crack it on paper?
##
## Nothing leaves the screen (CLAUDE.md rules 1 and 2): there is no share button, no clipboard, no screenshot helper
## and no file. The note and the code exist only as Label text while the screen is open; nothing is saved, not even
## how many notes were made (a counter would be a new save field; see docs/decisions.md). There is no LineEdit: the
## child types on the LetterPad (rule 6). tools/ci/lint_content.py checks this file for any of those.
class_name SecretMessageScreen
extends WorkshopScreen

const MAX_LETTERS: int = 40
const STEP_WIDTH_MULTIPLE: float = 1.6
const CARD_FONT: int = 44

## The note, capital letters and spaces.
var message: String = ""
## 0: a shift code, 1: a times-and-shift code.
var kind: int = 0
var shift: int = 3
var multiplier_index: int = 0
var addend: int = 4

var _note_label: Label
var _code_label: Label
var _key_label: Label
var _pad: LetterPad
var _kind_buttons: Array[Button] = []
var _shift_row: HBoxContainer
var _affine_row: VBoxContainer
var _shift_value: Label
var _a_value: Label
var _b_value: Label
var _affine_ready: bool = false


func _ready() -> void:
	super()
	build_frame(&"z11.secret.title")
	back_to = &"museum"
	_affine_ready = Adaptive.mastered().has(&"cipher.affine.encode")
	var how: Label = Label.new()
	how.text = Text.get_line(&"z11.secret.how")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(how)
	_note_label = _card(&"z11.secret.note", "Note")
	_code_label = _card(&"z11.secret.code", "Code")
	_key_label = Label.new()
	_key_label.name = "Key"
	_key_label.theme_type_variation = &"NumberLabel"
	body.add_child(_key_label)
	var kinds: HBoxContainer = HBoxContainer.new()
	kinds.add_theme_constant_override(&"separation", 12)
	body.add_child(kinds)
	for pair: Array in [[&"z11.secret.shift_code", 0], [&"z11.secret.times_code", 1]]:
		if pair[1] == 1 and not _affine_ready:
			continue
		var choice: Button = Button.new()
		choice.name = "Kind%d" % pair[1]
		choice.text = Text.get_line(pair[0])
		choice.toggle_mode = true
		choice.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(choice, 2.6, 1.0)
		choice.pressed.connect(choose_kind.bind(pair[1]))
		kinds.add_child(choice)
		_kind_buttons.append(choice)
	_shift_row = HBoxContainer.new()
	_shift_row.add_theme_constant_override(&"separation", 8)
	body.add_child(_shift_row)
	_shift_value = _stepper(_shift_row, &"z11.secret.shift_label", "Shift", change_shift)
	_affine_row = VBoxContainer.new()
	_affine_row.add_theme_constant_override(&"separation", 8)
	body.add_child(_affine_row)
	var a_row: HBoxContainer = HBoxContainer.new()
	a_row.add_theme_constant_override(&"separation", 8)
	_affine_row.add_child(a_row)
	_a_value = _stepper(a_row, &"z11.secret.a_label", "A", change_multiplier)
	var b_row: HBoxContainer = HBoxContainer.new()
	b_row.add_theme_constant_override(&"separation", 8)
	_affine_row.add_child(b_row)
	_b_value = _stepper(b_row, &"z11.secret.b_label", "B", change_addend)
	_pad = load("res://scenes/input/letter_pad.tscn").instantiate()
	_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_pad)
	_pad.key_pressed.connect(type_letter)
	_pad.backspace_pressed.connect(backspace)
	_pad.clear_pressed.connect(clear)
	bolt_node.say(&"z11.secret.show")
	_refresh()


func _card(title_line: StringName, node_name: String) -> Label:
	var caption: Label = Label.new()
	caption.text = Text.get_line(title_line)
	body.add_child(caption)
	var card: PanelContainer = PanelContainer.new()
	card.name = node_name + "Card"
	body.add_child(card)
	var label: Label = Label.new()
	label.name = node_name
	label.add_theme_font_size_override(&"font_size", CARD_FONT)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.custom_minimum_size = UI.target_size(4.0, 1.4)
	card.add_child(label)
	return label


## A row with Less and More buttons around a value label; returns the value label.
func _stepper(row: HBoxContainer, title_line: StringName, node_name: String, callback: Callable) -> Label:
	var title: Label = Label.new()
	title.text = Text.get_line(title_line)
	row.add_child(title)
	var less: Button = Button.new()
	less.name = node_name + "Less"
	less.text = Text.get_line(&"z11.coins.less")
	less.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(less, STEP_WIDTH_MULTIPLE, 1.0)
	less.pressed.connect(callback.bind(-1))
	row.add_child(less)
	var value: Label = Label.new()
	value.name = node_name + "Value"
	value.theme_type_variation = &"NumberLabel"
	value.custom_minimum_size.x = UI.target_size(1.0, 1.0).x
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var more: Button = Button.new()
	more.name = node_name + "More"
	more.text = Text.get_line(&"z11.coins.more")
	more.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(more, STEP_WIDTH_MULTIPLE, 1.0)
	more.pressed.connect(callback.bind(1))
	row.add_child(more)
	return value


## The multipliers a times-and-shift code may use: the numbers that have an undo partner on the loop of 26.
static func multipliers() -> Array[int]:
	var found: Array[int] = []
	for a: int in range(3, 26):
		if CipherGenerator.is_coprime_26(a):
			found.append(a)
	return found


func type_letter(letter: String) -> void:
	if message.length() < MAX_LETTERS:
		message += letter
		_refresh()


func backspace() -> void:
	message = message.left(maxi(message.length() - 1, 0))
	_refresh()


func clear() -> void:
	message = ""
	_refresh()


func choose_kind(new_kind: int) -> void:
	kind = new_kind if new_kind == 0 or _affine_ready else 0
	_refresh()


func change_shift(delta: int) -> void:
	shift = clampi(shift + delta, 1, 25)
	_refresh()


func change_multiplier(delta: int) -> void:
	multiplier_index = clampi(multiplier_index + delta, 0, multipliers().size() - 1)
	_refresh()


func change_addend(delta: int) -> void:
	addend = clampi(addend + delta, 0, 25)
	_refresh()


## The coded note for the current choice.
func coded() -> String:
	if kind == 0:
		return CipherGenerator.shift_text(message, shift)
	return CipherGenerator.affine_text(message, multipliers()[multiplier_index], addend)


func pad() -> LetterPad:
	return _pad


func note_label() -> Label:
	return _note_label


func code_label() -> Label:
	return _code_label


func key_label() -> Label:
	return _key_label


func _refresh() -> void:
	if _note_label == null:
		return
	_note_label.text = message
	_code_label.text = coded()
	for index: int in _kind_buttons.size():
		_kind_buttons[index].button_pressed = index == kind
	_shift_row.visible = kind == 0
	_affine_row.visible = kind == 1
	_shift_value.text = Text.display_value(shift)
	_a_value.text = Text.display_value(multipliers()[multiplier_index])
	_b_value.text = Text.display_value(addend)
	if kind == 0:
		_key_label.text = Text.get_line(&"z11.secret.key_shift", {"k": shift})
	else:
		_key_label.text = Text.get_line(&"z11.secret.key_affine", {"a": multipliers()[multiplier_index], "b": addend})
