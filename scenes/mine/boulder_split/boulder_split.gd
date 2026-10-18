## "Split the boulder" (Zone 4): a boulder shows its number; the child drags the pickaxe from the
## rail's end to a split point, a factor pair such as 3 × 4, and the boulder cracks into two rocks.
## A prime boulder has only the split point 1 × n: the pickaxe bounces off ("7 is a prime. It won't
## break!") and the rock turns into a gem. Zone 5's factor trees reuse this node for every piece.
##
## Driven by InputRouter pointer signals, so a finger, a stylus and a mouse drag the same way, and a
## tap on a split point works too (no drag needed). It reports what the child chose and never says
## whether that answers a question: the host decides (CLAUDE.md: scene scripts only present).
class_name BoulderSplit
extends VBoxContainer

## A split point was chosen: `value` cracked into `factor_a` and `factor_b` (a x b = value, a <= b).
signal split_chosen(value: int, factor_a: int, factor_b: int)
## The pickaxe bounced off a prime boulder.
signal prime_declared(value: int)

const BOULDER_TEXTURE: String = "res://assets/art/kenney/rocks/rock_02.png"
const PIECE_TEXTURE: String = "res://assets/art/kenney/rocks/rock_01.png"
const NOTCH_WIDTH_MULTIPLE: float = 2.4
const PICKAXE_MULTIPLE: float = 1.3
const SNAP_RADIUS_MULTIPLE: float = 1.2
const BOUNCE_SECONDS: float = 0.25
const CRACK_SECONDS: float = 0.35
const INK: Color = Color("#1F2945")
const ROCK_LABEL: Color = Color("#F5F7FF")
const PICKAXE_HEAD: Color = Color("#C9D3E8")
const PICKAXE_HANDLE: Color = Color("#B07A45")
const NOTCH_HOT: Color = Color("#FFD166")

## The pointer source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node
## 1.0 is normal speed; tests raise it so animations finish quickly.
var speed_scale: float = 1.0
## A prime piece turns into a gem as soon as the boulder cracks. Zone 5's factor tree turns this off:
## there the child tests each piece with the pickaxe, so the split must not give the answer away.
var reveal_primes: bool = true

var value: int = 0
var _pairs: Array[Vector2i] = []
var _enabled: bool = true
var _done: bool = false
var _dragging: bool = false
var _stage: Control
var _boulder: _Rock
var _boulder_label: Label
var _message: Label
var _rail: HBoxContainer
var _notches: Array[Button] = []
var _pickaxe: _Pickaxe
var _rest: Vector2
var _grab_offset: Vector2 = Vector2.ZERO
var _pieces: Array[Control] = []
var _factors: Array[int] = []
var _tween: Tween


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = UI.target_size(6.0, 3.5)
	add_child(_stage)
	_boulder = _Rock.new()
	_boulder.name = "Boulder"
	_boulder.texture = load(BOULDER_TEXTURE)
	_stage.add_child(_boulder)
	_boulder_label = _label_in(_boulder)
	_message = Label.new()
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text = Text.get_line(&"z4.split.prompt")
	add_child(_message)
	_rail = HBoxContainer.new()
	_rail.name = "Rail"
	_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	_rail.add_theme_constant_override(&"separation", 16)
	add_child(_rail)
	_pickaxe = _Pickaxe.new()
	_pickaxe.name = "Pickaxe"
	UI.make_touch_target(_pickaxe, PICKAXE_MULTIPLE, PICKAXE_MULTIPLE)
	_pickaxe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pickaxe)
	_pickaxe.top_level = true
	if router == null:
		router = InputRouter
	router.pointer_down.connect(_on_pointer_down)
	router.pointer_move.connect(_on_pointer_move)
	router.pointer_up.connect(_on_pointer_up)
	resized.connect(_layout)
	sort_children.connect(_layout)


func _exit_tree() -> void:
	if router != null and router.pointer_down.is_connected(_on_pointer_down):
		router.pointer_down.disconnect(_on_pointer_down)
		router.pointer_move.disconnect(_on_pointer_move)
		router.pointer_up.disconnect(_on_pointer_up)


## A paused game ends a drag in progress (the pause menu is on top); see BuildBoard.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _dragging:
		_drop_pickaxe_back()


## Shows a boulder of `boulder_value`. `allowed_factors` are the factors the rail may use (any
## divisor from 2 up to the boulder's own half); each pair a x b with a <= b becomes one split point.
## With none, the rail shows only 1 x n, the split a prime cannot make.
func setup(boulder_value: int, allowed_factors: Array[int]) -> void:
	value = boulder_value
	_factors = allowed_factors.duplicate()
	_done = false
	_dragging = false
	if _tween != null:
		_tween.kill()
	for piece: Control in _pieces:
		piece.queue_free()
	_pieces.clear()
	_boulder.is_gem = false
	_boulder.queue_redraw()
	_boulder.visible = true
	_boulder.modulate = Color.WHITE
	_boulder_label.text = str(value)
	_message.text = Text.get_line(&"z4.split.prompt")
	_pairs = pairs_for(value, allowed_factors)
	for child: Node in _rail.get_children():
		child.queue_free()
		_rail.remove_child(child)
	_notches.clear()
	for pair: Vector2i in _pairs:
		var notch: Button = Button.new()
		notch.name = "Notch%dx%d" % [pair.x, pair.y]
		notch.text = Text.get_line(&"z4.split.pair", {"a": pair.x, "b": pair.y})
		UI.make_touch_target(notch, NOTCH_WIDTH_MULTIPLE, 1.0)
		notch.pressed.connect(choose_pair.bind(pair.x))
		_rail.add_child(notch)
		_notches.append(notch)
	_pickaxe.visible = true
	_layout.call_deferred()


## The split points for a boulder: every pair a x b = value with a <= b built from `allowed_factors`
## (a factor or its partner), or just 1 x value when there is none. Pure.
static func pairs_for(boulder_value: int, allowed_factors: Array[int]) -> Array[Vector2i]:
	var seen: Dictionary[int, bool] = {}
	var pairs: Array[Vector2i] = []
	for factor: int in allowed_factors:
		if factor < 2 or factor >= boulder_value or boulder_value % factor != 0:
			continue
		var low: int = mini(factor, boulder_value / factor)
		if not seen.has(low):
			seen[low] = true
			pairs.append(Vector2i(low, boulder_value / low))
	pairs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	if pairs.is_empty():
		pairs.append(Vector2i(1, boulder_value))
	return pairs


## Disabled while a result is judged. Enabled again after a split that was not what was asked,
## the boulder is whole again and the pickaxe is back on the rail.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled and _done:
		setup(value, _factors)
	if not enabled and _dragging:
		_drop_pickaxe_back()
	for notch: Button in _notches:
		notch.disabled = not enabled or _done


## Splits at the pair whose smaller factor is `low` (the same call a tap, a drop and a test make).
## 1 x n (the only split a prime has) bounces. Returns false when nothing happened.
func choose_pair(low: int) -> bool:
	if not _enabled or _done or value <= 0:
		return false
	var pair: Vector2i = Vector2i(-1, -1)
	for candidate: Vector2i in _pairs:
		if candidate.x == low:
			pair = candidate
	if pair.x < 0:
		return false
	if pair.x == 1:
		_bounce()
		return true
	_crack(pair)
	return true


func is_done() -> bool:
	return _done


func notches() -> Array[Button]:
	return _notches


func pickaxe() -> Control:
	return _pickaxe


func boulder() -> Control:
	return _boulder


func boulder_text() -> String:
	return _boulder_label.text


func message_text() -> String:
	return _message.text


## The pieces after a split (empty before one): each a Control with its number in a Label.
func pieces() -> Array[Control]:
	return _pieces


func _crack(pair: Vector2i) -> void:
	_done = true
	for notch: Button in _notches:
		notch.disabled = true
	_pickaxe.visible = false
	_message.text = Text.get_line(&"z4.split.done", {"n": value, "a": pair.x, "b": pair.y})
	_tween = create_tween()
	_tween.set_speed_scale(speed_scale)
	_tween.tween_property(_boulder, "modulate:a", 0.0, CRACK_SECONDS)
	var centre: Vector2 = _stage.size / 2.0
	var piece_size: Vector2 = _boulder.size * 0.62
	for index: int in 2:
		var number: int = pair.x if index == 0 else pair.y
		var piece: _Rock = _Rock.new()
		piece.name = "Piece%d" % index
		piece.texture = load(PIECE_TEXTURE)
		piece.size = piece_size
		piece.position = centre - piece_size / 2.0
		_stage.add_child(piece)
		var label: Label = _label_in(piece)
		label.text = str(number)
		if reveal_primes and _is_prime(number):
			piece.is_gem = true
			label.tooltip_text = Text.get_line(&"z4.split.piece_prime", {"n": number})
		elif reveal_primes:
			label.tooltip_text = Text.get_line(&"z4.split.piece_rock", {"n": number})
		_pieces.append(piece)
		var target: Vector2 = centre + Vector2((-1.0 if index == 0 else 1.0) * _stage.size.x * 0.22, 0.0) - piece_size / 2.0
		_tween.parallel().tween_property(piece, "position", target, CRACK_SECONDS)
	split_chosen.emit(value, pair.x, pair.y)


## The pickaxe hits a prime and bounces back; the rock becomes a gem.
func _bounce() -> void:
	_message.text = Text.get_line(&"z4.split.prime_bounce", {"n": value})
	_boulder.is_gem = true
	_boulder.queue_redraw()
	_done = true
	for notch: Button in _notches:
		notch.disabled = true
	_tween = create_tween()
	_tween.set_speed_scale(speed_scale)
	var home: Vector2 = _rest
	var hit: Vector2 = _boulder.get_global_rect().get_center()
	_pickaxe.global_position = hit - _pickaxe.size / 2.0
	_tween.tween_property(_pickaxe, "global_position", home + Vector2(0, -UI.min_target_px() * 0.4), BOUNCE_SECONDS)
	_tween.tween_property(_pickaxe, "global_position", home, BOUNCE_SECONDS * 0.6)
	prime_declared.emit(value)


func _drop_pickaxe_back() -> void:
	_dragging = false
	_pickaxe.global_position = _rest


func _layout() -> void:
	if _pickaxe == null or not is_inside_tree():
		return
	_boulder.size = _stage.size.min(UI.target_size(4.0, 3.0))
	_boulder.position = (_stage.size - _boulder.size) / 2.0
	var first: Rect2 = _notches[0].get_global_rect() if not _notches.is_empty() else _rail.get_global_rect()
	_rest = Vector2(first.position.x - _pickaxe.size.x - 24.0, first.get_center().y - _pickaxe.size.y / 2.0)
	if not _dragging and not _done:
		_pickaxe.global_position = _rest


func _accepts_pointer() -> bool:
	return _enabled and not _done and is_visible_in_tree() and can_process()


func _on_pointer_down(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _accepts_pointer():
		return
	var grab: Rect2 = _pickaxe.get_global_rect().grow(UI.min_target_px() * 0.25)
	if grab.has_point(pos):
		_dragging = true
		_grab_offset = _pickaxe.global_position - pos


func _on_pointer_move(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _dragging or not _accepts_pointer():
		return
	_pickaxe.global_position = pos + _grab_offset
	var hot: int = _notch_under(pos)
	for index: int in _notches.size():
		_notches[index].modulate = NOTCH_HOT if index == hot else Color.WHITE


func _on_pointer_up(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _dragging:
		return
	_dragging = false
	for notch: Button in _notches:
		notch.modulate = Color.WHITE
	if not _accepts_pointer():
		_pickaxe.global_position = _rest
		return
	var hit: int = _notch_under(pos)
	if hit >= 0 and choose_pair(_pairs[hit].x):
		return
	_pickaxe.global_position = _rest # dropped on nothing: it goes back, nothing is lost


## The split point nearest `pos` within the snap radius, or -1.
func _notch_under(pos: Vector2) -> int:
	var best: int = -1
	var best_distance: float = float(UI.min_target_px()) * SNAP_RADIUS_MULTIPLE
	for index: int in _notches.size():
		var rect: Rect2 = _notches[index].get_global_rect()
		var distance: float = 0.0 if rect.has_point(pos) else rect.get_center().distance_to(pos) - rect.size.x / 2.0
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _label_in(holder: Control) -> Label:
	var label: Label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.theme_type_variation = &"HeadingLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return label


static func _is_prime(number: int) -> bool:
	if number < 2:
		return false
	var divisor: int = 2
	while divisor * divisor <= number:
		if number % divisor == 0:
			return false
		divisor += 1
	return true


## A rock (the Kenney sprite) or, once it has turned into a gem, an amethyst-colored cut stone.
class _Rock extends Control:
	var texture: Texture2D
	var is_gem: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if is_gem:
			var points: PackedVector2Array = GemArt.shape_points(GemArt.AMETHYST)
			var scaled: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in points:
				scaled.append(point * size)
			draw_colored_polygon(scaled, GemArt.color_for(GemArt.AMETHYST))
			scaled.append(scaled[0])
			draw_polyline(scaled, GemArt.OUTLINE, GemArt.OUTLINE_WIDTH, true)
		elif texture != null:
			var fit: float = minf(size.x / texture.get_width(), size.y / texture.get_height())
			var drawn: Vector2 = Vector2(texture.get_width(), texture.get_height()) * fit
			draw_texture_rect(texture, Rect2((size - drawn) / 2.0, drawn), false)


## The pickaxe the child drags: a handle and a head, drawn from two shapes.
class _Pickaxe extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var unit: float = minf(size.x, size.y)
		draw_line(Vector2(unit * 0.25, unit * 0.9), Vector2(unit * 0.7, unit * 0.3), BoulderSplit.PICKAXE_HANDLE, unit * 0.1, true)
		var head: PackedVector2Array = PackedVector2Array([Vector2(unit * 0.15, unit * 0.35), Vector2(unit * 0.5, unit * 0.1), Vector2(unit * 0.95, unit * 0.25), Vector2(unit * 0.5, unit * 0.3)])
		draw_colored_polygon(head, BoulderSplit.PICKAXE_HEAD)
		head.append(head[0])
		draw_polyline(head, BoulderSplit.INK, 2.0, true)
