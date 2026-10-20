## The mixing table (Zone 10, Clockwork Depths; meta.mixing_table = {n, op}): the table of (Z_n, adding) or
## (Z_n, multiplying) with a row of number buttons under it. Tapping a number lights its row and column in the table;
## the do-nothing number is the one whose row repeats the top and whose column repeats the side. Done hands in the
## number chosen. The table is drawn by ClockArt, so it looks like the problem pictures.
##
## Buttons are at least one touch target (a table of 12 has 12 of them, wrapping onto a second row), so finger,
## stylus and mouse all work the same; the number keys pick a number for n up to 10 and Enter presses Done. The widget
## never says whether the number is right; the host decides.
class_name MixingTable
extends VBoxContainer

## Done was pressed: the number chosen.
signal submitted(number: int)
## A number was tapped (for a click).
signal chosen_changed(number: int)

const TABLE_HEIGHT_MULTIPLE: float = 3.6
const COMPACT_TABLE_HEIGHT_MULTIPLE: float = 2.4
const TABLE_WIDTH_MULTIPLE: float = 4.0
const NUMBER_WIDTH_MULTIPLE: float = 1.0

var n: int = 3
var op: StringName = &"add"
## The number tapped last, or -1 before the first tap.
var chosen: int = -1

var _picture: _TablePicture
var _numbers: HFlowContainer
var _buttons: Array[Button] = []
var _done: Button
var _how: Label
var _enabled: bool = true


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Builds the table; `spec` is meta.mixing_table.
func setup(spec: Dictionary) -> void:
	n = int(spec["n"])
	op = StringName(str(spec["op"]))
	chosen = -1
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	if not UI.is_compact(): # a phone has no room for the line of help
		_how = Label.new()
		_how.name = "How"
		_how.text = Text.get_line(&"z10.table.how")
		_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_how)
	_picture = _TablePicture.new()
	_picture.name = "Table"
	_picture.table = self
	UI.make_touch_target(_picture, TABLE_WIDTH_MULTIPLE, COMPACT_TABLE_HEIGHT_MULTIPLE if UI.is_compact() else TABLE_HEIGHT_MULTIPLE)
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	_numbers = HFlowContainer.new()
	_numbers.name = "Numbers"
	_numbers.alignment = FlowContainer.ALIGNMENT_CENTER
	_numbers.add_theme_constant_override(&"h_separation", 8)
	_numbers.add_theme_constant_override(&"v_separation", 8)
	add_child(_numbers)
	for number: int in n:
		var button: Button = Button.new()
		button.name = "Number%d" % number
		button.text = Text.display_value(number)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, NUMBER_WIDTH_MULTIPLE, 1.0)
		button.pressed.connect(choose.bind(number))
		_numbers.add_child(button)
		_buttons.append(button)
	_done = Button.new()
	_done.name = "DoneButton"
	_done.text = Text.get_line(&"z10.table.done")
	_done.theme_type_variation = &"GoButton"
	_done.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_done, 1.8, 1.0)
	_done.pressed.connect(submit)
	_numbers.add_child(_done) # one flow: the numbers, then Done
	_refresh()


## Lights the row and column of a number.
func choose(number: int) -> void:
	if not _enabled:
		return
	chosen = number
	chosen_changed.emit(number)
	_refresh()


func submit() -> void:
	if _enabled and chosen >= 0:
		submitted.emit(chosen)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func number_button(number: int) -> Button:
	return _buttons[number]


func done_button() -> Button:
	return _done


func _refresh() -> void:
	for index: int in _buttons.size():
		_buttons[index].button_pressed = index == chosen
		_buttons[index].disabled = not _enabled
	if _done != null:
		_done.disabled = not _enabled or chosen < 0
	if _picture != null:
		_picture.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree() or not _enabled:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		submit()
	elif event.unicode >= KEY_0 and event.unicode <= KEY_9 and event.unicode - KEY_0 < n:
		choose(event.unicode - KEY_0)
	else:
		return
	get_viewport().set_input_as_handled()


## The table, with the chosen number's row and column lit.
class _TablePicture:
	extends Control

	var table: MixingTable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if table == null:
			return
		var area: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var picture: Dictionary = GroupGenerator.cayley_picture(table.n, table.op, true)
		ClockArt.draw_table(self, area, picture, get_theme_default_font())
		if table.chosen >= 0:
			var n: int = table.n
			var lit_row: Rect2 = ClockArt.cell_rect(area, n, table.chosen, -1).merge(ClockArt.cell_rect(area, n, table.chosen, n - 1))
			var lit_col: Rect2 = ClockArt.cell_rect(area, n, -1, table.chosen).merge(ClockArt.cell_rect(area, n, n - 1, table.chosen))
			draw_rect(lit_row, ClockArt.CART, false, 4.0)
			draw_rect(lit_col, ClockArt.SECOND, false, 4.0)
