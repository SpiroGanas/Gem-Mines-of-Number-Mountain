## The answer area for "build an array with {rows} rows and {cols} columns" (meta.array_builder).
##
## A grid of empty cells. Pressing on a cell and dragging fills the array from the top-left corner to
## the cell under the pointer; a tap on a cell does the same in one go. Done reports
## {rows: int, cols: int}. Driven by InputRouter pointer signals, so a finger, a stylus and a mouse
## behave the same. The builder never scores anything.
class_name ArrayBuilder
extends VBoxContainer

signal submitted(answer: Dictionary)
## The array changed size while the child dragged or tapped.
signal size_changed(rows: int, cols: int)

const CELL_MULTIPLE: float = 1.0
const EMPTY: Color = Color(1, 1, 1, 0.08)
const EDGE: Color = Color("#F5F7FF")

## The pointer source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node
var max_rows: int = 5
var max_cols: int = 5

var _rows: int = 0
var _cols: int = 0
var _cells: Array[_Cell] = []
var _grid: GridContainer
var _done_button: Button
var _pressing: bool = false
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 24)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_grid = GridContainer.new()
	_grid.columns = max_cols
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_grid)
	for row: int in max_rows:
		for col: int in max_cols:
			var cell: _Cell = _Cell.new()
			UI.make_touch_target(cell, CELL_MULTIPLE, CELL_MULTIPLE)
			_grid.add_child(cell)
			_cells.append(cell)
	_done_button = Button.new()
	_done_button.text = Text.get_line(&"ui.mine.done")
	_done_button.theme_type_variation = &"GoButton"
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_done_button, 3.0, 1.5)
	_done_button.pressed.connect(submit)
	add_child(_done_button)
	if router == null:
		router = InputRouter
	router.pointer_down.connect(_on_pointer_down)
	router.pointer_move.connect(_on_pointer_move)
	router.pointer_up.connect(_on_pointer_up)
	router.pointer_cancelled.connect(_on_pointer_cancelled)
	_refresh()


func _exit_tree() -> void:
	if router != null and router.pointer_down.is_connected(_on_pointer_down):
		router.pointer_down.disconnect(_on_pointer_down)
		router.pointer_move.disconnect(_on_pointer_move)
		router.pointer_up.disconnect(_on_pointer_up)
		router.pointer_cancelled.disconnect(_on_pointer_cancelled)


## A paused game (the pause menu) ends the press in progress; see BuildBoard.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pressing = false


## The press was a resting palm the pen took over from: it ends without a tap.
func _on_pointer_cancelled(_index: int) -> void:
	_pressing = false


## True while the builder may react to the pointer: shown on screen and not paused.
func _accepts_pointer() -> bool:
	return is_visible_in_tree() and can_process()


func answer() -> Dictionary:
	return {"rows": _rows, "cols": _cols}


## The cell at `row`, `col` (0-based), for tests and layout code.
func cell(row: int, col: int) -> Control:
	return _cells[row * max_cols + col]


func is_filled(row: int, col: int) -> bool:
	return row < _rows and col < _cols


func done_button() -> Button:
	return _done_button


## Sets the array to `rows` x `cols` (clamped to the grid). Tests and tools use this directly.
func set_array(rows: int, cols: int) -> void:
	var new_rows: int = clampi(rows, 0, max_rows)
	var new_cols: int = clampi(cols, 0, max_cols)
	if new_rows == _rows and new_cols == _cols:
		return
	_rows = new_rows
	_cols = new_cols
	_refresh()
	size_changed.emit(_rows, _cols)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_pressing = false
	_refresh()


func submit() -> void:
	if _enabled and _rows > 0 and _cols > 0:
		submitted.emit(answer())


func _cell_at(pos: Vector2) -> Vector2i:
	for index: int in _cells.size():
		if _cells[index].get_global_rect().has_point(pos):
			return Vector2i(floori(float(index) / float(max_cols)), index % max_cols)
	return Vector2i(-1, -1)


func _on_pointer_down(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _enabled or not _accepts_pointer():
		return
	var hit: Vector2i = _cell_at(pos)
	if hit.x < 0:
		return
	_pressing = true
	set_array(hit.x + 1, hit.y + 1)


func _on_pointer_move(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _pressing or not _accepts_pointer():
		return
	var hit: Vector2i = _cell_at(pos)
	if hit.x >= 0:
		set_array(hit.x + 1, hit.y + 1)


func _on_pointer_up(_pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	_pressing = false


func _refresh() -> void:
	if _done_button == null:
		return
	for index: int in _cells.size():
		_cells[index].filled = is_filled(floori(float(index) / float(max_cols)), index % max_cols)
	_done_button.disabled = not _enabled or _rows == 0 or _cols == 0


## One cell: an empty outlined square, or a gem when it is part of the array.
class _Cell extends Control:
	var filled: bool = false:
		set(value):
			filled = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = ArrayBuilder.EMPTY
		box.border_color = ArrayBuilder.EDGE
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		if not filled:
			return
		var points: PackedVector2Array = GemArt.shape_points(GemArt.PYRITE)
		var scaled: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in points:
			scaled.append(size * 0.15 + point * size * 0.7)
		draw_colored_polygon(scaled, GemArt.color_for(GemArt.PYRITE))
		scaled.append(scaled[0])
		draw_polyline(scaled, GemArt.OUTLINE, 2.0, true)
