## The Sieve of Eratosthenes grid (Zone 5): numbered rocks from 1 to `size`, ten to a row. A tap
## crosses a rock out; a second tap brings it back. Rocks crossed in an earlier step of the sieve
## (precrossed) are crossed from the start and cannot be brought back. Done hands in every crossed
## rock, smallest first. It never says whether that is right: the host decides.
##
## Each rock is a Button (a tap with a finger, a stylus or a mouse, or Enter on a focused rock) at
## least UI.min_target_px() square. The state lives in one PackedByteArray and a tap redraws only
## the rock it changed, so nothing is allocated per frame. On a short screen the grid scrolls
## (ScrollContainer) rather than shrinking its rocks below the 64 dp minimum.
class_name SieveGrid
extends VBoxContainer

## Done was pressed: `crossed` is every crossed rock, smallest first.
signal submitted(crossed: Array)
## A rock was crossed out or brought back (for a sound).
signal toggled(number: int, crossed: bool)

const OPEN: int = 0
const PRECROSSED: int = 1
const CROSSED: int = 2
const GAP: int = 4
const CELL_FILL: Color = Color("#3A4566")
const CELL_EDGE: Color = Color("#C9D3E8")
const CROSS_COLOR: Color = Color("#FFD166")
const EARLIER_CROSS_COLOR: Color = Color("#8C96B3")
const DIGIT_COLOR: Color = Color("#F5F7FF")
const DONE_WIDTH_MULTIPLE: float = 3.0
const DONE_HEIGHT_MULTIPLE: float = 1.2

var size_limit: int = 0
var _state: PackedByteArray = PackedByteArray()
var _cells: Array[Button] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _done: Button
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.add_theme_constant_override(&"h_separation", GAP)
	_grid.add_theme_constant_override(&"v_separation", GAP)
	_scroll.add_child(_grid)
	_done = Button.new()
	_done.name = "DoneButton"
	_done.theme_type_variation = &"GoButton"
	_done.text = Text.get_line(&"z5.sieve.done")
	_done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_done, DONE_WIDTH_MULTIPLE, DONE_HEIGHT_MULTIPLE)
	_done.pressed.connect(submit)
	add_child(_done)
	UI.metrics_changed.connect(_relayout) # a posture change resizes the grid's width and digits


## The window changed size (a posture switch): UI has re-sized the rocks themselves (touch targets);
## the grid's width and the digits follow.
func _relayout() -> void:
	var side: Vector2 = UI.target_size(1.0, 1.0)
	var columns: int = _grid.columns
	_scroll.custom_minimum_size.x = columns * side.x + (columns - 1) * GAP
	for cell: Button in _cells:
		for child: Node in cell.get_children():
			if child is _Cross:
				(child as _Cross).font_size = _digit_size(side)
				(child as _Cross).queue_redraw()


static func _digit_size(side: Vector2) -> int:
	return int(side.y * 0.42)


## Shows rocks 1..grid_size, `columns` to a row, with `precrossed` crossed from the start.
func setup(grid_size: int, columns: int, precrossed: Array) -> void:
	size_limit = grid_size
	for cell: Button in _cells:
		_grid.remove_child(cell)
		cell.queue_free()
	_cells.clear()
	_grid.columns = maxi(columns, 1)
	_state = PackedByteArray()
	_state.resize(grid_size + 1)
	for value: Variant in precrossed:
		if int(value) >= 1 and int(value) <= grid_size:
			_state[int(value)] = PRECROSSED
	var side: Vector2 = UI.target_size(1.0, 1.0)
	_scroll.custom_minimum_size.x = columns * side.x + (columns - 1) * GAP
	for number: int in range(1, grid_size + 1):
		var cell: Button = Button.new()
		cell.name = "Rock%d" % number
		cell.tooltip_text = str(number)
		UI.make_touch_target(cell) # and re-sized by UI when the window (posture) changes
		cell.focus_mode = Control.FOCUS_ALL
		cell.clip_text = false
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			cell.add_theme_stylebox_override(style_name, _cell_style(style_name))
		var mark: _Cross = _Cross.new()
		mark.number = number
		mark.font_size = _digit_size(side)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell.add_child(mark)
		cell.pressed.connect(toggle.bind(number))
		_grid.add_child(cell)
		_cells.append(cell)
		_refresh_cell(number)


## Crosses rock `number` out, or brings it back. A precrossed rock never changes. Returns false
## when nothing changed.
func toggle(number: int) -> bool:
	if not _enabled or number < 1 or number > size_limit or _state[number] == PRECROSSED:
		return false
	_state[number] = OPEN if _state[number] == CROSSED else CROSSED
	_refresh_cell(number)
	toggled.emit(number, _state[number] == CROSSED)
	return true


## Every crossed rock (precrossed and crossed by the child), smallest first.
func crossed() -> Array:
	var result: Array = []
	for number: int in range(1, size_limit + 1):
		if _state[number] != OPEN:
			result.append(number)
	return result


func is_crossed(number: int) -> bool:
	return _state[number] != OPEN


func submit() -> void:
	if _enabled:
		submitted.emit(crossed())


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _done != null:
		_done.disabled = not enabled
	for number: int in range(1, _cells.size() + 1):
		_cells[number - 1].disabled = not enabled or _state[number] == PRECROSSED


func cell(number: int) -> Button:
	return _cells[number - 1]


func done_button() -> Button:
	return _done


func scroll() -> ScrollContainer:
	return _scroll


func _refresh_cell(number: int) -> void:
	var button: Button = _cells[number - 1]
	var mark: _Cross = button.get_child(0)
	mark.state = _state[number]
	mark.queue_redraw()
	button.disabled = not _enabled or _state[number] == PRECROSSED


func _cell_style(style_name: StringName) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CELL_FILL.lightened(0.15) if style_name == &"hover" or style_name == &"pressed" else CELL_FILL
	if style_name == &"disabled":
		style.bg_color = CELL_FILL.darkened(0.35)
	style.border_color = CROSS_COLOR if style_name == &"focus" else CELL_EDGE
	style.set_border_width_all(4 if style_name == &"focus" else 2)
	style.draw_center = style_name != &"focus"
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	return style


## The rock's number with the X of a crossed rock under it: headlamp yellow for the child's
## crosses, grey for the earlier steps. Thick and full-size, so it reads without color; the number is
## drawn last, with a dark outline, so it stays readable through the X.
class _Cross extends Control:
	var state: int = SieveGrid.OPEN
	var number: int = 0
	var font_size: int = 26

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if state != SieveGrid.OPEN:
			var color: Color = SieveGrid.CROSS_COLOR if state == SieveGrid.CROSSED else SieveGrid.EARLIER_CROSS_COLOR
			var inset: float = minf(size.x, size.y) * 0.14
			var width: float = maxf(minf(size.x, size.y) * 0.07, 3.0)
			draw_line(Vector2(inset, inset), size - Vector2(inset, inset), color, width, true)
			draw_line(Vector2(size.x - inset, inset), Vector2(inset, size.y - inset), color, width, true)
		var font: Font = get_theme_default_font()
		var text: String = str(number)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at: Vector2 = Vector2((size.x - text_size.x) / 2.0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, SieveGrid.CELL_FILL.darkened(0.5))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SieveGrid.DIGIT_COLOR)
