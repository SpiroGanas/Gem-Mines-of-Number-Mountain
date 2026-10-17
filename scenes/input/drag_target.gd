## A tray that accepts DragItems and reports how many of each kind it holds.
## Items inside are laid out by a flow container, tens first, so the tray always reads left to
## right as "tens then ones". It shows a hint line while empty.
class_name DragTarget
extends PanelContainer

## An item was added or removed.
signal changed

## Kinds this tray accepts.
@export var accepts: PackedStringArray = PackedStringArray(["hundred", "ten", "one"])

var _flow: HFlowContainer
var _hint: Label


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var stack: Control = Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	_hint = Label.new()
	_hint.text = Text.get_line(&"z1.build.tray")
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hint.modulate = Color(1, 1, 1, 0.6)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_hint)
	_flow = HFlowContainer.new()
	_flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flow.add_theme_constant_override(&"h_separation", 12)
	_flow.add_theme_constant_override(&"v_separation", 12)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_flow)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func accepts_kind(kind: StringName) -> bool:
	return accepts.has(String(kind))


## True when a canvas-space point is over the tray.
func contains_point(global_point: Vector2) -> bool:
	return get_global_rect().has_point(global_point)


## Adds an item if its kind is accepted. Hundreds come first, then tens, then ones.
func add_item(item: DragItem) -> bool:
	if not accepts_kind(item.kind):
		return false
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.position = Vector2.ZERO
	_flow.add_child(item)
	var ahead: int = 0
	for existing: Node in _flow.get_children():
		if existing != item and existing is DragItem and _rank((existing as DragItem).kind) <= _rank(item.kind):
			ahead += 1
	_flow.move_child(item, ahead)
	_refresh()
	changed.emit()
	return true


## Sort order inside the tray: hundreds, tens, ones.
static func _rank(kind: StringName) -> int:
	match kind:
		DragItem.HUNDRED:
			return 0
		DragItem.TEN:
			return 1
	return 2


## Takes an item out (the caller owns it afterwards).
func remove_item(item: DragItem) -> void:
	if item.get_parent() == _flow:
		_flow.remove_child(item)
		_refresh()
		changed.emit()


func items() -> Array[DragItem]:
	var result: Array[DragItem] = []
	for child: Node in _flow.get_children():
		if child is DragItem:
			result.append(child)
	return result


## How many items of each kind are in the tray, e.g. {hundred: 0, ten: 3, one: 4}.
func counts() -> Dictionary:
	var result: Dictionary = {DragItem.HUNDRED: 0, DragItem.TEN: 0, DragItem.ONE: 0}
	for item: DragItem in items():
		result[item.kind] = int(result.get(item.kind, 0)) + 1
	return result


func clear() -> void:
	for item: DragItem in items():
		_flow.remove_child(item)
		item.queue_free()
	_refresh()
	changed.emit()


func _refresh() -> void:
	if _hint != null:
		_hint.visible = _flow == null or _flow.get_child_count() == 0
