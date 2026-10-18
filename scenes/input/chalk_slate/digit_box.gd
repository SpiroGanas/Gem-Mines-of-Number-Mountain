## One box of the chalk slate: the child writes one digit in it with a finger, a stylus or a mouse.
##
## Listens to InputRouter's stroke signals (which already drop a resting palm, so the box never has
## to), draws the strokes like chalk in _draw(), and hands them out normalized to the box (0..1) for
## a Recognizer. Points are kept normalized, so a posture change that resizes the box mid-stroke only
## rescales the drawing; it never distorts or loses it. The strokes live only in memory, only so the child can see what they wrote; they are
## never saved, and clear() (or freeing the box) discards them (CLAUDE.md rule 2).
##
## Godot note: _draw() is called by the engine whenever queue_redraw() has been asked for; it draws
## with draw_polyline() and friends instead of using child nodes, which is cheap for a few lines.
class_name DigitBox
extends Control

## A stroke was added or the box was cleared.
signal strokes_changed

## Box size as multiples of the 64 dp minimum: roomy enough for a child's whole hand movement.
const WIDTH_MULTIPLE: float = 2.5
const HEIGHT_MULTIPLE: float = 3.5
## A new point is kept only when it is this far (px) from the last one, so a stroke stays light.
const MIN_POINT_DISTANCE: float = 3.0
## A stroke keeps at most this many points; the last one is replaced after that.
const MAX_POINTS_PER_STROKE: int = 256
## A stroke whose marks fit inside this many px is a touch, not a digit stroke, and is dropped.
const MIN_STROKE_SIZE: float = 5.0

const BOARD: Color = Color("#2B3A42")
const BOARD_EDGE: Color = Color("#4A5D68")
const CHALK: Color = Color("#F5F7FF")
const GUIDE: Color = Color(1, 1, 1, 0.22)
## Where the guide lines sit (fractions of the box's height): the top, the middle and the baseline.
const GUIDE_FRACTIONS: PackedFloat32Array = [0.2, 0.5, 0.8]
const FLAGGED_EDGE: Color = Color("#FFD166")

## The stroke source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node

## Points normalized to the box (0..1, y down).
var _strokes: Array[PackedVector2Array] = []
var _current: PackedVector2Array = PackedVector2Array()
var _drawing: bool = false
var _enabled: bool = true
var _flagged: bool = false
var _board_style: StyleBoxFlat


func _ready() -> void:
	UI.make_touch_target(self, WIDTH_MULTIPLE, HEIGHT_MULTIPLE)
	_board_style = StyleBoxFlat.new()
	_board_style.bg_color = BOARD
	_board_style.set_corner_radius_all(24)
	_board_style.set_border_width_all(4)
	_board_style.border_color = BOARD_EDGE
	if router == null:
		router = InputRouter
	router.stroke_started.connect(_on_stroke_started)
	router.stroke_moved.connect(_on_stroke_moved)
	router.stroke_ended.connect(_on_stroke_ended)
	router.stroke_cancelled.connect(_on_stroke_cancelled)


func _exit_tree() -> void:
	_discard()
	if router != null and router.stroke_started.is_connected(_on_stroke_started):
		router.stroke_started.disconnect(_on_stroke_started)
		router.stroke_moved.disconnect(_on_stroke_moved)
		router.stroke_ended.disconnect(_on_stroke_ended)
		router.stroke_cancelled.disconnect(_on_stroke_cancelled)


## A paused game ends the stroke in progress (the pause menu is on top).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_drop_current()


func has_ink() -> bool:
	return not _strokes.is_empty()


## The strokes normalized to the box: x and y from 0 to 1, y down. A copy; the box keeps its own.
func strokes() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for stroke: PackedVector2Array in _strokes:
		result.append(stroke.duplicate())
	return result


## The box in whole pixels (what a Recognizer is told).
func box_size() -> Vector2i:
	return Vector2i(maxi(roundi(size.x), 1), maxi(roundi(size.y), 1))


func clear() -> void:
	_discard()
	_flagged = false
	queue_redraw()
	strokes_changed.emit()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_drop_current()


## Marks the box (a yellow edge) as the one to write again.
func set_flagged(flagged: bool) -> void:
	_flagged = flagged
	queue_redraw()


func is_flagged() -> bool:
	return _flagged


func is_drawing() -> bool:
	return _drawing


func _accepts_pointer() -> bool:
	return _enabled and is_visible_in_tree() and can_process()


## `pos` (a point on the screen) in box pixels.
func _local(pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * pos


## A box-pixel point as a fraction of the box.
func _normalized(local: Vector2) -> Vector2:
	return local / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))


func _on_stroke_started(pos: Vector2, _pressure: float, _is_pen: bool) -> void:
	if not _accepts_pointer():
		return
	var local: Vector2 = _local(pos)
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return
	_drawing = true
	_current = PackedVector2Array([_normalized(local)])
	queue_redraw()


func _on_stroke_moved(pos: Vector2, _pressure: float) -> void:
	if not _drawing or not _accepts_pointer():
		return
	var local: Vector2 = _local(pos).clamp(Vector2.ZERO, size) # sliding out of the box does not end the stroke
	var point: Vector2 = _normalized(local)
	if _current.size() >= MAX_POINTS_PER_STROKE:
		_current[_current.size() - 1] = point
	elif local.distance_to(_current[_current.size() - 1] * size) >= MIN_POINT_DISTANCE:
		_current.append(point)
	else:
		return
	queue_redraw()


func _on_stroke_ended() -> void:
	if not _drawing:
		return
	_drawing = false
	var bounds: Rect2 = Rect2(_current[0] * size, Vector2.ZERO)
	for point: Vector2 in _current:
		bounds = bounds.expand(point * size)
	if maxf(bounds.size.x, bounds.size.y) >= MIN_STROKE_SIZE:
		_strokes.append(_current)
		_flagged = false
		strokes_changed.emit()
	_current = PackedVector2Array()
	queue_redraw()


func _on_stroke_cancelled() -> void:
	_drop_current()


func _drop_current() -> void:
	if _drawing or not _current.is_empty():
		_drawing = false
		_current = PackedVector2Array()
		queue_redraw()


func _discard() -> void:
	_strokes.clear()
	_current = PackedVector2Array()
	_drawing = false


func _draw() -> void:
	_board_style.border_color = FLAGGED_EDGE if _flagged else BOARD_EDGE
	draw_style_box(_board_style, Rect2(Vector2.ZERO, size))
	# guide lines: where the digit sits (top, middle and bottom), dashed so they are not ink
	for fraction: float in GUIDE_FRACTIONS:
		draw_dashed_line(Vector2(size.x * 0.1, size.y * fraction), Vector2(size.x * 0.9, size.y * fraction), GUIDE, 2.0, 10.0)
	var width: float = maxf(6.0, size.y * 0.035)
	for stroke: PackedVector2Array in _strokes:
		_draw_stroke(stroke, width)
	if _drawing:
		_draw_stroke(_current, width)


func _draw_stroke(stroke: PackedVector2Array, width: float) -> void:
	if stroke.size() >= 2:
		draw_polyline(Transform2D(Vector2(size.x, 0.0), Vector2(0.0, size.y), Vector2.ZERO) * stroke, CHALK, width, true) # scales every point from 0..1 to pixels
	if not stroke.is_empty():
		draw_circle(stroke[0] * size, width / 2.0, CHALK)
		draw_circle(stroke[stroke.size() - 1] * size, width / 2.0, CHALK)
