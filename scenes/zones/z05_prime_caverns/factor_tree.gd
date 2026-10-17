## The factor tree (Zone 5): the child splits a number again and again until every piece is a prime
## gem. Built on Zone 4's BoulderSplit: the pickaxe splits the picked piece on its factor rail (a
## finger, a stylus or a mouse through InputRouter, or a tap on a split point), and the tree beside
## it grows two branches. A prime piece has only the split 1 × n, so the pickaxe bounces and the piece
## becomes a gem. Pieces stay plain rocks until tested (BoulderSplit.reveal_primes is off), so the
## tree never gives the answer away.
##
## Tap a rock in the tree to work on it; after each split or bounce the next rock waits on the rail.
## When every leaf is a gem the tree is complete: tree_completed fires and the leaves are handed in.
## Done hands in the leaves as they are (a rock left unsplit is a "not quite"). The leaves always
## multiply to the starting number, whichever split points were chosen: the Fundamental Theorem of
## Arithmetic says they always end up the same primes. It never judges the answer: the host decides.
class_name FactorTree
extends VBoxContainer

## The leaves were handed in (Done, or the tree completed), smallest first.
signal submitted(leaves: Array)
## Every leaf is a prime gem. Fires only then.
signal tree_completed(leaves: Array)
## A piece was split (for a sound).
signal piece_split(value: int, factor_a: int, factor_b: int)
## A piece turned out prime and became a gem.
signal piece_became_gem(value: int)

const SPLIT_SCENE: PackedScene = preload("res://scenes/mine/boulder_split/boulder_split.tscn")
const NODE_MULTIPLE: float = 1.25
const ROW_GAP_MULTIPLE: float = 0.6
## The space between two leaves, in touch targets.
const LEAF_GAP_MULTIPLE: float = 0.4
const PAUSE_SECONDS: float = 0.5
const EDGE_COLOR: Color = Color("#C9D3E8")
const ROCK_FILL: Color = Color("#6B5B4E")
const ROCK_EDGE: Color = Color("#2A2320")
const PICKED_RING: Color = Color("#FFD166")
const DONE_WIDTH_MULTIPLE: float = 3.0
const DONE_HEIGHT_MULTIPLE: float = 1.2

## The pointer source for the BoulderSplit. Defaults to the InputRouter autoload; tests inject one.
var router: Node
## 1.0 is normal speed; tests raise it.
var speed_scale: float = 1.0
## The pause after a split or a bounce before the next rock comes up. Test drivers set 0, and then
## the next rock is on the rail at once.
var pause_seconds: float = PAUSE_SECONDS

## The tree: [{value, parent, children: Array[int], depth, gem}]; node 0 is the root.
var _nodes: Array[Dictionary] = []
var _picked: int = -1
var _enabled: bool = true
var _busy: bool = false
var _finished: bool = false
var _view: _TreeView
var _split: BoulderSplit
var _done: Button
var _hint: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 24)
	add_child(row)
	_view = _TreeView.new()
	_view.name = "TreeView"
	_view.host = self
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for four leaves side by side and four rows: a tree of at most four primes.
	_view.custom_minimum_size = UI.target_size(NODE_MULTIPLE * (4.0 + 3.0 * LEAF_GAP_MULTIPLE), NODE_MULTIPLE * (4.0 + 3.0 * ROW_GAP_MULTIPLE))
	row.add_child(_view)
	_split = SPLIT_SCENE.instantiate()
	_split.name = "BoulderSplit"
	_split.router = router
	_split.reveal_primes = false
	_split.speed_scale = speed_scale
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_split)
	_split.split_chosen.connect(_on_split_chosen)
	_split.prime_declared.connect(_on_prime_declared)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 24)
	add_child(bottom)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = Text.get_line(&"z5.tree.pick_piece")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_hint)
	_done = Button.new()
	_done.name = "DoneButton"
	_done.theme_type_variation = &"GoButton"
	_done.text = Text.get_line(&"z5.tree.done")
	UI.make_touch_target(_done, DONE_WIDTH_MULTIPLE, DONE_HEIGHT_MULTIPLE)
	_done.pressed.connect(submit)
	bottom.add_child(_done)


## Starts the tree of `value`: one rock, already on the rail.
func setup(value: int) -> void:
	_nodes = [{"value": value, "parent": -1, "children": [], "depth": 0, "gem": false}]
	_finished = false
	_busy = false
	_hint.text = Text.get_line(&"z5.tree.pick_piece")
	_view.rebuild()
	pick(0)


## Puts tree node `index` on the rail, if it is a rock still to test. Returns false otherwise.
func pick(index: int) -> bool:
	if index < 0 or index >= _nodes.size() or not is_leaf(index) or _nodes[index]["gem"] or _finished:
		return false
	_picked = index
	var value: int = _nodes[index]["value"]
	_split.setup(value, proper_factors(value))
	_split.set_enabled(_enabled and not _busy)
	_view.refresh()
	return true


## The leaves, smallest first.
func leaves() -> Array:
	var result: Array = []
	for index: int in _nodes.size():
		if is_leaf(index):
			result.append(int(_nodes[index]["value"]))
	result.sort()
	return result


func is_leaf(index: int) -> bool:
	return _nodes[index]["children"].is_empty()


func is_complete() -> bool:
	for index: int in _nodes.size():
		if is_leaf(index) and not _nodes[index]["gem"]:
			return false
	return not _nodes.is_empty()


func node_count() -> int:
	return _nodes.size()


func node(index: int) -> Dictionary:
	return _nodes[index]


func picked() -> int:
	return _picked


## The tree's node indexes left to right (leaves in reading order).
func leaf_order() -> Array[int]:
	var result: Array[int] = []
	for index: int in _view.order:
		if is_leaf(index):
			result.append(index)
	return result


func boulder_split() -> BoulderSplit:
	return _split


func done_button() -> Button:
	return _done


## The tappable piece of tree node `index`, for tests.
func piece_button(index: int) -> Button:
	return _view.buttons[index]


func submit() -> void:
	if _enabled and not _finished:
		submitted.emit(leaves())


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_done.disabled = not enabled
	_split.set_enabled(enabled and not _busy)
	_view.refresh()


## Every divisor of `value` from 2 up to value / 2: the factors its rail may offer (none for a prime).
static func proper_factors(value: int) -> Array[int]:
	var found: Array[int] = []
	for divisor: int in range(2, floori(value / 2.0) + 1):
		if value % divisor == 0:
			found.append(divisor)
	return found


func _on_split_chosen(value: int, factor_a: int, factor_b: int) -> void:
	if _picked < 0:
		return
	var parent: int = _picked
	var depth: int = int(_nodes[parent]["depth"]) + 1
	for factor: int in [factor_a, factor_b]:
		_nodes[parent]["children"].append(_nodes.size())
		_nodes.append({"value": factor, "parent": parent, "children": [], "depth": depth, "gem": false})
	_view.rebuild()
	piece_split.emit(value, factor_a, factor_b)
	await _pause()
	_pick_next(parent)


func _on_prime_declared(value: int) -> void:
	if _picked < 0:
		return
	_nodes[_picked]["gem"] = true
	_view.refresh()
	piece_became_gem.emit(value)
	if is_complete():
		_finished = true
		_hint.text = Text.get_line(&"z5.tree.all_gems")
		var result: Array = leaves()
		tree_completed.emit(result)
		submitted.emit(result)
		return
	await _pause()
	_pick_next(_picked)


## A short pause so the child sees the crack or the bounce before the next rock comes up.
func _pause() -> void:
	if pause_seconds <= 0.0 or not is_inside_tree():
		return
	_busy = true
	_split.set_enabled(false)
	await get_tree().create_timer(pause_seconds / maxf(speed_scale, 0.01)).timeout
	_busy = false


## The next rock to test: the first leaf, left to right, that is not a gem yet.
func _pick_next(_after: int) -> void:
	if not is_inside_tree() or _finished:
		return
	for index: int in leaf_order():
		if not _nodes[index]["gem"]:
			pick(index)
			return


## Draws the tree: rows by depth, leaves spread left to right in tree order, a parent centred over
## its children, branches as lines. Each piece is a flat Button (at least a touch target) so a rock
## can be tapped to put it on the rail.
class _TreeView extends Control:
	var host: FactorTree
	var buttons: Array[Button] = []
	## Node indexes in left-to-right (depth-first) order.
	var order: Array[int] = []
	var _centres: Dictionary[int, Vector2] = {}

	func _ready() -> void:
		resized.connect(_layout)

	func rebuild() -> void:
		for button: Button in buttons:
			remove_child(button)
			button.queue_free()
		buttons.clear()
		for index: int in host.node_count():
			var button: Button = Button.new()
			button.name = "Piece%d" % index
			button.text = str(int(host.node(index)["value"]))
			button.focus_mode = Control.FOCUS_ALL
			UI.make_touch_target(button, FactorTree.NODE_MULTIPLE, FactorTree.NODE_MULTIPLE)
			for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
				var style: StyleBoxEmpty = StyleBoxEmpty.new()
				button.add_theme_stylebox_override(style_name, style)
			button.add_theme_color_override(&"font_color", Color("#F5F7FF"))
			button.add_theme_color_override(&"font_disabled_color", Color("#F5F7FF"))
			button.pressed.connect(host.pick.bind(index))
			add_child(button)
			buttons.append(button)
		_layout()

	func refresh() -> void:
		for index: int in buttons.size():
			buttons[index].disabled = not host.is_leaf(index) or bool(host.node(index)["gem"])
		queue_redraw()

	func _layout() -> void:
		order.clear()
		_centres.clear()
		if buttons.is_empty():
			return
		var side: Vector2 = UI.target_size(FactorTree.NODE_MULTIPLE, FactorTree.NODE_MULTIPLE)
		var row_height: float = side.y * (1.0 + FactorTree.ROW_GAP_MULTIPLE)
		var slot: Array[int] = [0]
		_place(0, slot)
		var leaf_count: int = maxi(slot[0], 1)
		var gap: float = side.x * FactorTree.LEAF_GAP_MULTIPLE
		var span: float = leaf_count * side.x + (leaf_count - 1) * gap
		var left: float = maxf((size.x - span) / 2.0, 0.0)
		for index: int in order:
			var x: float = left + float(_centres[index].x) * (side.x + gap) + side.x / 2.0
			var y: float = float(host.node(index)["depth"]) * row_height + side.y / 2.0
			_centres[index] = Vector2(x, y)
			buttons[index].size = side
			buttons[index].position = _centres[index] - side / 2.0
		refresh()

	## Depth-first: a leaf takes the next slot, a parent sits at the middle of its children's slots.
	func _place(index: int, slot: Array[int]) -> float:
		var children: Array = host.node(index)["children"]
		var at: float
		if children.is_empty():
			at = float(slot[0])
			slot[0] += 1
			order.append(index)
		else:
			var first: float = _place(int(children[0]), slot)
			order.append(index)
			var last: float = first
			for child: int in range(1, children.size()):
				last = _place(int(children[child]), slot)
			at = (first + last) / 2.0
		_centres[index] = Vector2(at, 0.0)
		return at

	func _draw() -> void:
		for index: int in _centres:
			var parent: int = int(host.node(index)["parent"])
			if parent >= 0 and _centres.has(parent):
				draw_line(_centres[parent], _centres[index], FactorTree.EDGE_COLOR, 4.0, true)
		var radius: float = UI.target_size(FactorTree.NODE_MULTIPLE, FactorTree.NODE_MULTIPLE).x * 0.48
		for index: int in _centres:
			var centre: Vector2 = _centres[index]
			if bool(host.node(index)["gem"]):
				var points: PackedVector2Array = GemArt.shape_points(GemArt.AMETHYST)
				var scaled: PackedVector2Array = PackedVector2Array()
				for point: Vector2 in points:
					scaled.append(centre - Vector2(radius, radius) + point * radius * 2.0)
				draw_colored_polygon(scaled, GemArt.color_for(GemArt.AMETHYST))
				scaled.append(scaled[0])
				draw_polyline(scaled, GemArt.OUTLINE, GemArt.OUTLINE_WIDTH, true)
			else:
				draw_circle(centre, radius, FactorTree.ROCK_FILL)
				draw_circle(centre, radius, FactorTree.ROCK_EDGE, false, 3.0, true)
			if index == host.picked():
				draw_circle(centre, radius + 6.0, FactorTree.PICKED_RING, false, 5.0, true)
