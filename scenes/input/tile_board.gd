## The answer area for "put the tiles in the slots": fill the blanks of a number strip, put
## numbers in order, skip count, build a fact family (meta.tile_board in Problem).
##
## A row of slots (optionally with the known numbers of a strip between them), a pool of tiles,
## and a Done button. Like BuildBoard it is driven by InputRouter pointer signals, so a finger, a
## stylus and a mouse behave the same:
##   - drag a tile from the pool onto a slot (a tile already there goes back to the pool);
##   - drag a placed tile to another slot to swap, or anywhere else to take it out;
##   - tap a pool tile to drop it in the first empty slot; tap a placed tile to take it out.
## Each tile is used at most once; a used tile stays dimmed in the pool so the layout never jumps.
## The board never scores anything. Done (enabled once every slot is full) reports the slots'
## values in order, or sorted with Problem.sorted_values when `ordered` is false.
class_name TileBoard
extends VBoxContainer

## Done was pressed with every slot filled.
signal submitted(answer: Array)
signal tile_placed(value: Variant)
signal tile_removed(value: Variant)

const TAP_SLOP_PX: float = 14.0
const TILE_HEIGHT_MULTIPLE: float = 1.4
const SLOT_FILL: Color = Color(1, 1, 1, 0.08)
const SLOT_EDGE: Color = Color("#F5F7FF")
const TILE_FILL: Color = Color("#FFD166")
const TILE_TEXT: Color = Color("#1F2945")

## The pointer source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node
## Tile values in pool order. Set before the board enters the tree.
var tiles: Array = []
var slot_count: int = 1
var ordered: bool = true
## Optional reading order for the slot row: known values and null for each slot, e.g.
## [60, null, 62, null, 64]. Empty means slot_count bare slots.
var sequence: Array = []

var _placed: Array = []
var _pool_faces: Array[TileFace] = []
var _slot_faces: Array[TileFace] = []
var _done_button: Button
var _drag_layer: Control
var _ghost: TileFace
var _drag_value: Variant = null
var _drag_from_slot: int = -1
var _dragging: bool = false
var _down_position: Vector2 = Vector2.ZERO
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 24)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_placed.resize(slot_count)
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"h_separation", 16)
	row.add_theme_constant_override(&"v_separation", 16)
	add_child(row)
	var layout: Array = sequence if not sequence.is_empty() else _bare_slots()
	for item: Variant in layout:
		if item == null:
			var slot: TileFace = TileFace.new(_widest(), true)
			_slot_faces.append(slot)
			row.add_child(slot)
		else:
			var known: Label = Label.new()
			known.text = str(item)
			known.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(known)
	var pool: HFlowContainer = HFlowContainer.new()
	pool.alignment = FlowContainer.ALIGNMENT_CENTER
	pool.add_theme_constant_override(&"h_separation", 16)
	pool.add_theme_constant_override(&"v_separation", 16)
	add_child(pool)
	for value: Variant in tiles:
		var face: TileFace = TileFace.new(_widest(), false)
		face.show_value(value)
		_pool_faces.append(face)
		pool.add_child(face)
	_done_button = Button.new()
	_done_button.text = Text.get_line(&"ui.mine.done")
	_done_button.theme_type_variation = &"GoButton"
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_done_button, 3.0, 1.5)
	_done_button.pressed.connect(submit)
	add_child(_done_button)
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.top_level = true
	add_child(_drag_layer)
	if router == null:
		router = InputRouter
	router.pointer_down.connect(_on_pointer_down)
	router.pointer_move.connect(_on_pointer_move)
	router.pointer_up.connect(_on_pointer_up)
	_refresh()


func _exit_tree() -> void:
	if router != null and router.pointer_down.is_connected(_on_pointer_down):
		router.pointer_down.disconnect(_on_pointer_down)
		router.pointer_move.disconnect(_on_pointer_move)
		router.pointer_up.disconnect(_on_pointer_up)


## A paused game (the pause menu) drops a half-finished drag; see BuildBoard.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_cancel_drag()


## True while the board may react to the pointer: shown on screen and not paused.
func _accepts_pointer() -> bool:
	return is_visible_in_tree() and can_process()


## The values in the slots, left to right (null for an empty slot).
func placed() -> Array:
	return _placed.duplicate()


## The answer as it stands: the slot values, sorted when the order does not matter.
func answer() -> Array:
	return _placed.duplicate() if ordered else Problem.sorted_values(_placed)


func is_full() -> bool:
	return not _placed.has(null)


func slot_face(index: int) -> TileFace:
	return _slot_faces[index]


## The pool face showing `value`, or null.
func tile_face(value: Variant) -> TileFace:
	for index: int in tiles.size():
		if Problem.same(tiles[index], value):
			return _pool_faces[index]
	return null


func done_button() -> Button:
	return _done_button


func is_dragging() -> bool:
	return _dragging


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_cancel_drag()
	_refresh()


## Puts `value` in slot `index` (a tile already there goes back to the pool). Tests and tools use
## this; the child does it by dragging or tapping.
func put(value: Variant, index: int) -> void:
	var previous: int = _slot_of(value)
	if previous >= 0:
		_placed[previous] = null
	_placed[index] = value
	tile_placed.emit(value)
	_refresh()


func take_out(index: int) -> void:
	var value: Variant = _placed[index]
	if value == null:
		return
	_placed[index] = null
	tile_removed.emit(value)
	_refresh()


## Empties every slot.
func clear() -> void:
	for index: int in _placed.size():
		_placed[index] = null
	_refresh()


func submit() -> void:
	if _enabled and is_full():
		submitted.emit(answer())


func _bare_slots() -> Array:
	var slots: Array = []
	slots.resize(slot_count)
	return slots


## Width for every tile and slot, in touch-target multiples: enough for the longest label.
func _widest() -> float:
	var longest: int = 1
	for value: Variant in tiles:
		longest = maxi(longest, str(value).length())
	return maxf(1.5, 0.42 * float(longest) + 0.6)


func _slot_of(value: Variant) -> int:
	for index: int in _placed.size():
		if _placed[index] != null and Problem.same(_placed[index], value):
			return index
	return -1


func _refresh() -> void:
	if _done_button == null:
		return
	for index: int in _slot_faces.size():
		_slot_faces[index].show_value(_placed[index])
	for index: int in tiles.size():
		_pool_faces[index].set_dimmed(_slot_of(tiles[index]) >= 0)
	_done_button.disabled = not _enabled or not is_full()


func _on_pointer_down(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _enabled or _dragging or not _accepts_pointer():
		return
	_down_position = pos
	for index: int in _slot_faces.size():
		if _placed[index] != null and _slot_faces[index].get_global_rect().has_point(pos):
			_begin_drag(_placed[index], index, pos)
			return
	for index: int in tiles.size():
		if _slot_of(tiles[index]) < 0 and _pool_faces[index].get_global_rect().has_point(pos):
			_begin_drag(tiles[index], -1, pos)
			return


func _on_pointer_move(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if _dragging and _ghost != null:
		_ghost.global_position = pos - _ghost.size * 0.5


func _on_pointer_up(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _dragging:
		return
	var value: Variant = _drag_value
	var from_slot: int = _drag_from_slot
	_cancel_drag()
	var is_tap: bool = pos.distance_to(_down_position) <= TAP_SLOP_PX
	if is_tap:
		if from_slot >= 0:
			take_out(from_slot)
		else:
			var empty: int = _placed.find(null)
			if empty >= 0:
				put(value, empty)
		return
	var target: int = -1
	for index: int in _slot_faces.size():
		if _slot_faces[index].get_global_rect().has_point(pos):
			target = index
	if target < 0:
		if from_slot >= 0:
			take_out(from_slot)
		return
	if from_slot >= 0 and target != from_slot:
		var other: Variant = _placed[target] # swap with whatever is there
		_placed[target] = value
		_placed[from_slot] = other
		tile_placed.emit(value)
		_refresh()
	elif from_slot < 0:
		put(value, target)


func _begin_drag(value: Variant, from_slot: int, pos: Vector2) -> void:
	_dragging = true
	_drag_value = value
	_drag_from_slot = from_slot
	_ghost = TileFace.new(_widest(), false)
	_ghost.show_value(value)
	_drag_layer.add_child(_ghost)
	_ghost.reset_size()
	_ghost.global_position = pos - _ghost.size * 0.5


func _cancel_drag() -> void:
	_dragging = false
	_drag_value = null
	_drag_from_slot = -1
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


## One tile or one slot: a rounded box with the value's text. An empty slot is an outlined box.
class TileFace extends PanelContainer:
	var value: Variant = null
	var _label: Label
	var _is_slot: bool

	func _init(width_multiple: float, is_slot: bool) -> void:
		_is_slot = is_slot
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UI.make_touch_target(self, width_multiple, TileBoard.TILE_HEIGHT_MULTIPLE)
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_color_override(&"font_color", TileBoard.TILE_TEXT)
		add_child(_label)
		show_value(null)

	func show_value(new_value: Variant) -> void:
		value = new_value
		_label.text = "" if new_value == null else str(new_value)
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.set_corner_radius_all(18)
		box.set_border_width_all(4)
		if new_value == null:
			box.bg_color = TileBoard.SLOT_FILL
			box.border_color = TileBoard.SLOT_EDGE
		else:
			box.bg_color = TileBoard.TILE_FILL
			box.border_color = TileBoard.TILE_TEXT
		add_theme_stylebox_override(&"panel", box)

	func set_dimmed(dimmed: bool) -> void:
		modulate.a = 0.3 if dimmed else 1.0

	func text() -> String:
		return _label.text
