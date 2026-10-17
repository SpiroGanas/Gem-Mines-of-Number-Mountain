## The answer area for "build a number with tens and ones" (skill pv.tens_ones.build).
##
## Two piles to take from (ten-bars and one-gems), a tray to drop them in, and a Done button
## beside the piles.
## Everything is driven by InputRouter pointer signals, so a finger, a stylus and a mouse behave
## the same:
##   - drag from a pile into the tray to add a piece;
##   - drag a piece out of the tray (drop it anywhere outside) to remove it;
##   - tap a pile to add one piece without dragging (a kind shortcut for small hands).
## Optional pieces: `tools` picks which piles exist (add &"hundred" for numbers over 99) and
## `initial` starts the tray filled, for regrouping ({tens: 3, ones: 13}). Set both before the
## board enters the scene tree. Tapping a piece that is already in the tray removes it.
## The board never scores anything. It reports {tens, ones} (plus hundreds when there is a
## hundred pile) through `submitted`.
class_name BuildBoard
extends VBoxContainer

## Done was pressed. `answer` is {tens: int, ones: int}.
signal submitted(answer: Dictionary)
## A piece landed in the tray.
signal item_placed(kind: StringName)
## A piece was dragged out and dropped away.
signal item_removed(kind: StringName)

## A pointer that moves less than this many canvas pixels between down and up counts as a tap.
const TAP_SLOP_PX: float = 14.0

## The pointer source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node
## Which piles to offer, left to right.
var tools: Array[StringName] = [DragItem.TEN, DragItem.ONE]
## Pieces to start with in the tray, e.g. {hundreds: 0, tens: 3, ones: 13}. Missing keys mean 0.
var initial: Dictionary = {}

var _tray: DragTarget
var _done_button: Button
var _drag_layer: Control
var _sources: Dictionary[StringName, Control] = {}
var _dragging: DragItem
var _grab_offset: Vector2 = Vector2.ZERO
var _from_tray: bool = false
var _down_position: Vector2 = Vector2.ZERO
var _down_source: StringName = &""
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 20)
	_tray = DragTarget.new()
	_tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.make_touch_target(_tray, 6.0, 3.5)
	add_child(_tray)
	var sources: HBoxContainer = HBoxContainer.new()
	sources.alignment = BoxContainer.ALIGNMENT_CENTER
	sources.add_theme_constant_override(&"separation", 64)
	add_child(sources)
	var labels: Dictionary = {DragItem.HUNDRED: &"z1.build.source_hundred", DragItem.TEN: &"z1.build.source_ten", DragItem.ONE: &"z1.build.source_one"}
	for kind: StringName in tools:
		_sources[kind] = _make_source(kind, labels[kind], sources)
	_done_button = Button.new()
	_done_button.text = Text.get_line(&"ui.mine.done")
	_done_button.theme_type_variation = &"GoButton"
	_done_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_done_button, 3.0, 1.5)
	_done_button.pressed.connect(submit)
	sources.add_child(_done_button) # beside the piles, so a worked example above still leaves room
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)
	_drag_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if router == null:
		router = InputRouter
	router.pointer_down.connect(_on_pointer_down)
	router.pointer_move.connect(_on_pointer_move)
	router.pointer_up.connect(_on_pointer_up)
	_fill_tray(initial)
	set_enabled(_enabled)


func _exit_tree() -> void:
	if router != null and router.pointer_down.is_connected(_on_pointer_down):
		router.pointer_down.disconnect(_on_pointer_down)
		router.pointer_move.disconnect(_on_pointer_move)
		router.pointer_up.disconnect(_on_pointer_up)


func tray() -> DragTarget:
	return _tray


func done_button() -> Button:
	return _done_button


## The pile control for a kind (its on-screen rectangle is the drag start area).
func source(kind: StringName) -> Control:
	return _sources[kind]


## The answer as the tray stands: {tens, ones}, plus hundreds when there is a hundred pile.
func answer() -> Dictionary:
	var counts: Dictionary = _tray.counts()
	var result: Dictionary = {"tens": counts[DragItem.TEN], "ones": counts[DragItem.ONE]}
	if tools.has(DragItem.HUNDRED):
		result["hundreds"] = counts[DragItem.HUNDRED]
	return result


func is_dragging() -> bool:
	return _dragging != null


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _done_button != null:
		_done_button.disabled = not enabled
	if not enabled:
		_cancel_drag()


func submit() -> void:
	if _enabled:
		submitted.emit(answer())


func _fill_tray(pieces: Dictionary) -> void:
	for kind: StringName in [DragItem.HUNDRED, DragItem.TEN, DragItem.ONE]:
		var key: String = {DragItem.HUNDRED: "hundreds", DragItem.TEN: "tens", DragItem.ONE: "ones"}[kind]
		for i: int in int(pieces.get(key, 0)):
			_tray.add_item(DragItem.make(kind))


func _make_source(kind: StringName, line_id: StringName, parent: Control) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END # pile labels line up along the bottom
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sample: DragItem = DragItem.make(kind)
	sample.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(sample)
	var label: Label = Label.new()
	label.text = Text.get_line(line_id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	parent.add_child(column)
	return column


func _on_pointer_down(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _enabled or _dragging != null:
		return
	_down_position = pos
	_down_source = &""
	# A piece already in the tray: pick it up (topmost first).
	var placed: Array[DragItem] = _tray.items()
	placed.reverse()
	for item: DragItem in placed:
		if item.get_global_rect().has_point(pos):
			_tray.remove_item(item)
			_begin_drag(item, item.global_position - pos, true)
			return
	# A pile: take a fresh piece.
	for kind: StringName in _sources:
		if _sources[kind].get_global_rect().has_point(pos):
			var fresh: DragItem = DragItem.make(kind)
			_down_source = kind
			_begin_drag(fresh, Vector2.ZERO, false)
			fresh.global_position = pos - fresh.size * 0.5
			_grab_offset = -fresh.size * 0.5
			return


func _on_pointer_move(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if _dragging != null:
		_dragging.global_position = pos + _grab_offset


func _on_pointer_up(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if _dragging == null:
		return
	var item: DragItem = _dragging
	_dragging = null
	var is_tap: bool = pos.distance_to(_down_position) <= TAP_SLOP_PX
	if _from_tray and is_tap:
		# A tap on a piece already in the tray takes it out.
		item_removed.emit(item.kind)
		item.queue_free()
		return
	var over_tray: bool = _tray.contains_point(pos)
	if _down_source != &"" and is_tap:
		over_tray = true # tapping a pile adds one piece
	if over_tray and _tray.add_item(item):
		item_placed.emit(item.kind)
	else:
		if _from_tray:
			item_removed.emit(item.kind)
		item.queue_free()


func _begin_drag(item: DragItem, offset: Vector2, from_tray: bool) -> void:
	_dragging = item
	_grab_offset = offset
	_from_tray = from_tray
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	_drag_layer.add_child(item)


func _cancel_drag() -> void:
	if _dragging != null:
		_dragging.queue_free()
		_dragging = null
