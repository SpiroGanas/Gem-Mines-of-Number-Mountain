## The Fib poem maker (Zone 9, Sprint 40, P4-S40-03), reached from the Gem Museum. Six lines with
## syllable goals 1, 1, 2, 3, 5, 8: the child taps a line, then taps word tiles to add them (a tapped word
## in a line goes back out). Each line shows its goal as beat dots, lit as the syllables add up; a line
## glows when it fits. When every line fits, Save my poem keeps the poem in the child's save (word ids
## only; save schema v4). My poems shows the saved ones. Nothing here is judged right or wrong: a line
## that does not fit yet just does not glow, and nothing is ever lost (CLAUDE.md rule 8).
##
## Every word on screen comes from the text table (the tiles are z9.word.* lines). There is no free text
## entry: the child never types (CLAUDE.md rule 6). Taps work the same with finger, stylus and mouse.
## Rules are pure in FibPoem (scripts/zones/fib_poem.gd); this screen only shows them.
class_name FibPoemScreen
extends WorkshopScreen

## The poem was saved (for tests and a sound).
signal poem_saved

const LINE_HEIGHT_MULTIPLE: float = 1.2
const WORD_WIDTH_MULTIPLE: float = 1.6
const LINE_GLOW: Color = Color("#FFB3E6")
const DOT_ON: Color = Color("#FFB3E6")
const DOT_OFF: Color = Color(1, 1, 1, 0.3)
const DOT_OVER: Color = Color("#7FC8F8")

var _lines: Array = FibPoem.blank_poem()
var _selected: int = 0
var _line_rows: Array[Button] = []
var _line_words: Array[HFlowContainer] = []
var _line_dots: Array[_BeatDots] = []
var _bank: HFlowContainer
var _bank_scroll: ScrollContainer
var _poems_scroll: ScrollContainer
var _poems_list: VBoxContainer
var _save_button: Button
var _clear_button: Button
var _poems_button: Button
var _new_button: Button


func _ready() -> void:
	super()
	build_frame(&"z9.poem.title")
	back_to = &"museum"
	var lines_scroll: ScrollContainer = ScrollContainer.new()
	lines_scroll.name = "Lines"
	lines_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lines_scroll)
	var lines_column: VBoxContainer = VBoxContainer.new()
	lines_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines_column.add_theme_constant_override(&"separation", 8)
	lines_scroll.add_child(lines_column)
	for index: int in FibPoem.TARGETS.size():
		lines_column.add_child(_make_line_row(index))
	var controls: HFlowContainer = HFlowContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override(&"h_separation", 12)
	controls.add_theme_constant_override(&"v_separation", 12)
	body.add_child(controls)
	_clear_button = _control_button(&"z9.poem.clear", "ClearButton", clear_line)
	controls.add_child(_clear_button)
	_save_button = _control_button(&"z9.poem.save", "SaveButton", save_poem)
	_save_button.theme_type_variation = &"GoButton"
	controls.add_child(_save_button)
	_new_button = _control_button(&"z9.poem.new", "NewButton", new_poem)
	controls.add_child(_new_button)
	_poems_button = _control_button(&"z9.poem.my_poems", "PoemsButton", toggle_poems)
	controls.add_child(_poems_button)
	_bank_scroll = ScrollContainer.new()
	_bank_scroll.name = "WordBank"
	_bank_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bank_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_bank_scroll)
	_bank = HFlowContainer.new()
	_bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank.add_theme_constant_override(&"h_separation", 8)
	_bank.add_theme_constant_override(&"v_separation", 8)
	_bank_scroll.add_child(_bank)
	for word: String in PoemWords.ids():
		var tile: Button = Button.new()
		tile.name = "Word_%s" % word
		tile.text = Text.get_line(PoemWords.line_id(word))
		tile.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(tile, WORD_WIDTH_MULTIPLE, 1.0)
		tile.pressed.connect(add_word.bind(word))
		_bank.add_child(tile)
	_poems_scroll = ScrollContainer.new()
	_poems_scroll.name = "MyPoems"
	_poems_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_poems_scroll.visible = false
	side.add_child(_poems_scroll)
	_poems_list = VBoxContainer.new()
	_poems_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poems_list.add_theme_constant_override(&"separation", 16)
	_poems_scroll.add_child(_poems_list)
	bolt_node.say(&"z9.poem.how")
	_refresh()


## The six lines as they stand (word ids), for tests.
func lines() -> Array:
	return _lines.duplicate(true)


func selected_line() -> int:
	return _selected


func line_row(index: int) -> Button:
	return _line_rows[index]


## The button of a word placed in a line (tapping it takes the word back out), or null.
func placed_chip(line: int, position: int) -> Button:
	return _line_words[line].get_node_or_null(NodePath("Placed%d" % position)) as Button


func save_button() -> Button:
	return _save_button


func word_tile(word: String) -> Button:
	return _bank.get_node_or_null(NodePath("Word_%s" % word)) as Button


func showing_poems() -> bool:
	return _poems_scroll.visible


## The saved poems as the child reads them: one string a poem, its lines joined by new lines.
func saved_poem_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for poem: Variant in FibPoem.saved(SaveSystem.data()):
		var shown: PackedStringArray = PackedStringArray()
		for line: Variant in poem["lines"]:
			shown.append(AnswerPanel.poem_line_text(line))
		texts.append("\n".join(shown))
	return texts


func select_line(index: int) -> void:
	_selected = clampi(index, 0, FibPoem.TARGETS.size() - 1)
	sfx.play(&"select")
	_refresh()


## Adds a word to the chosen line. When the line starts to fit, the next open line is chosen.
func add_word(word: String) -> void:
	if not FibPoem.add_word(_lines, _selected, word):
		return
	sfx.play(&"tap")
	if FibPoem.line_fits(_lines[_selected], _selected):
		bolt_node.say(&"z9.poem.all_fit" if FibPoem.is_complete(_lines) else &"z9.poem.line_fits")
		var next: int = FibPoem.next_open_line(_lines)
		if next >= 0:
			_selected = next
	_refresh()


func remove_word(index: int, position: int) -> void:
	FibPoem.remove_word(_lines, index, position)
	_selected = index
	sfx.play(&"tap")
	_refresh()


func clear_line() -> void:
	_lines[_selected] = []
	_refresh()


func new_poem() -> void:
	_lines = FibPoem.blank_poem()
	_selected = 0
	_refresh()


## Saves the finished poem (word ids only) and writes the save at once (a save point, like a crafted
## recipe).
func save_poem() -> void:
	if not FibPoem.add_poem(SaveSystem.data(), _lines, Adaptive.clock.now_iso()):
		return
	SaveSystem.save_now()
	sfx.play(&"select")
	bolt_node.say(&"z9.poem.saved")
	poem_saved.emit()
	_lines = FibPoem.blank_poem()
	_selected = 0
	_refresh()
	_show_poems(true)


func toggle_poems() -> void:
	_show_poems(not _poems_scroll.visible)


func _show_poems(show: bool) -> void:
	_poems_scroll.visible = show
	_bank_scroll.visible = not show
	for child: Node in _poems_list.get_children():
		child.queue_free()
		_poems_list.remove_child(child)
	if not show:
		return
	var texts: PackedStringArray = saved_poem_texts()
	if texts.is_empty():
		var none: Label = Label.new()
		none.text = Text.get_line(&"z9.poem.none_yet")
		_poems_list.add_child(none)
	for index: int in range(texts.size() - 1, -1, -1): # newest first
		var card: PanelContainer = PanelContainer.new()
		var text: Label = Label.new()
		text.text = texts[index]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(text)
		_poems_list.add_child(card)


func _control_button(line_id: StringName, node_name: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(button, 2.6, 1.0)
	button.pressed.connect(action)
	return button


## One line: a tap target holding the goal's beat dots and the words placed so far (each a small button
## that takes the word back out).
func _make_line_row(index: int) -> Button:
	var row: Button = Button.new()
	row.name = "Line%d" % (index + 1)
	row.focus_mode = Control.FOCUS_NONE
	row.toggle_mode = true
	UI.make_touch_target(row, 6.0, LINE_HEIGHT_MULTIPLE)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.pressed.connect(select_line.bind(index))
	var inside: HBoxContainer = HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8
	inside.offset_right = -8
	inside.add_theme_constant_override(&"separation", 12)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inside)
	var dots: _BeatDots = _BeatDots.new()
	dots.goal = FibPoem.TARGETS[index]
	dots.custom_minimum_size = Vector2(UI.target_size(2.2, 1.0).x, 0)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(dots)
	var words: HFlowContainer = HFlowContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = FlowContainer.ALIGNMENT_BEGIN
	words.add_theme_constant_override(&"h_separation", 6)
	words.mouse_filter = Control.MOUSE_FILTER_PASS
	inside.add_child(words)
	_line_rows.append(row)
	_line_words.append(words)
	_line_dots.append(dots)
	return row


func _refresh() -> void:
	if _save_button == null:
		return
	for index: int in _line_rows.size():
		var words: Array = _lines[index]
		var state: StringName = FibPoem.line_state(words, index)
		_line_rows[index].button_pressed = index == _selected
		_line_rows[index].modulate = LINE_GLOW if state == FibPoem.FITS else Color.WHITE
		_line_dots[index].have = FibPoem.line_syllables(words)
		var holder: HFlowContainer = _line_words[index]
		for child: Node in holder.get_children():
			child.queue_free()
			holder.remove_child(child)
		for position: int in words.size():
			var chip: Button = Button.new()
			chip.name = "Placed%d" % position
			chip.text = Text.get_line(PoemWords.line_id(str(words[position])))
			chip.focus_mode = Control.FOCUS_NONE
			UI.make_touch_target(chip, 1.0, 1.0)
			chip.pressed.connect(remove_word.bind(index, position))
			holder.add_child(chip)
	_save_button.disabled = not FibPoem.is_complete(_lines)
	_clear_button.disabled = _lines[_selected].is_empty()


## A line's goal as beat dots: lit as the syllables add up, and blue extra dots when there are too many.
class _BeatDots:
	extends Control

	var goal: int = 1:
		set(value):
			goal = value
			queue_redraw()
	var have: int = 0:
		set(value):
			have = value
			queue_redraw()

	func _draw() -> void:
		var count: int = maxi(goal, have)
		if count <= 0 or size.x < 8.0:
			return
		var radius: float = minf(size.y * 0.16, size.x / float(count) * 0.36)
		var step: float = size.x / float(count)
		for beat: int in count:
			var color: Color = FibPoemScreen.DOT_OVER if beat >= goal else (FibPoemScreen.DOT_ON if beat < have else FibPoemScreen.DOT_OFF)
			draw_circle(Vector2(step * (beat + 0.5), size.y * 0.5), radius, color)
