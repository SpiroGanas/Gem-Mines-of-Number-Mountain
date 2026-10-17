## Shows how to write a digit: the strokes draw themselves one after the other, like a teacher's chalk.
## Bolt shows it (once per digit per session) when a child keeps writing a digit backwards and a
## grown-up has turned numeral coaching on. It never blocks anything: "Got it" closes it, and the
## slate under it is not enabled for answers while it shows only so a stray tap cannot write on it.
class_name StrokeDemo
extends PanelContainer

signal closed

const DRAW_SECONDS_PER_STROKE: float = 1.2
const PICTURE_MULTIPLE: float = 3.0

## Tests set this high to finish the animation at once.
var speed_scale: float = 1.0
var digit: int = -1

var _title: Label
var _canvas: _Canvas
var _close: Button
var _tween: Tween


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"HeadingLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_canvas = _Canvas.new()
	_canvas.name = "Canvas"
	UI.make_touch_target(_canvas, PICTURE_MULTIPLE, PICTURE_MULTIPLE)
	_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_canvas)
	_close = Button.new()
	_close.name = "CloseButton"
	_close.text = Text.get_line(&"input.slate.coach_close")
	_close.theme_type_variation = &"GoButton"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_close, 3.0, 1.5)
	_close.pressed.connect(close)
	column.add_child(_close)
	visible = false


## Plays the strokes of `for_digit` from the start.
func play(for_digit: int) -> void:
	digit = for_digit
	_title.text = Text.get_line(&"input.slate.coach_title", {"n": for_digit})
	_canvas.strokes = DigitPaths.strokes_for(for_digit)
	_canvas.progress = 0.0
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_speed_scale(speed_scale)
	var seconds: float = DRAW_SECONDS_PER_STROKE * float(maxi(_canvas.strokes.size(), 1))
	_tween.tween_property(_canvas, "progress", 1.0, seconds)


func close() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	closed.emit()


func close_button() -> Button:
	return _close


## 0..1: how much of the digit has been drawn so far.
func progress() -> float:
	return _canvas.progress


func title_text() -> String:
	return _title.text


## The drawing area. `progress` runs 0..1 over all strokes; a dot rides the end of the chalk.
class _Canvas extends Control:
	const CHALK: Color = Color("#F5F7FF")
	const BOARD: Color = Color("#2B3A42")
	const DOT: Color = Color("#FFD166")
	var strokes: Array[PackedVector2Array] = []
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BOARD)
		if strokes.is_empty():
			return
		var width: float = maxf(6.0, size.y * 0.04)
		var share: float = 1.0 / float(strokes.size())
		var tip: Vector2 = Vector2.ZERO
		for index: int in strokes.size():
			var done: float = clampf((progress - share * index) / share, 0.0, 1.0)
			if done <= 0.0:
				continue
			var line: PackedVector2Array = PackedVector2Array()
			var count: int = maxi(ceili(done * float(strokes[index].size() - 1)), 1)
			for point_index: int in count + 1:
				line.append(strokes[index][mini(point_index, strokes[index].size() - 1)] * size)
			if done < 1.0:
				var exact: float = done * float(strokes[index].size() - 1)
				var whole: int = mini(floori(exact), strokes[index].size() - 2)
				line[line.size() - 1] = strokes[index][whole].lerp(strokes[index][whole + 1], exact - float(whole)) * size
			draw_polyline(line, CHALK, width, true)
			tip = line[line.size() - 1]
		if progress < 1.0:
			draw_circle(tip, width * 1.2, DOT)
