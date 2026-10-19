## A square root written with its sign: the radical (a short tick, a long stroke up) and a bar over the
## number (√49). The sign is drawn in code with lines, so it does not depend on the font having the
## √ character. Presentation only, never interactive.
class_name RootDisplay
extends HBoxContainer

const STROKE: Color = Color("#F5F7FF")

## 1.0 is the theme's big number size.
@export var size_scale: float = 1.0:
	set(value):
		size_scale = value
		_refresh()

var _sign: _RadicalSign
var _number: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 0)
	_sign = _RadicalSign.new()
	_sign.name = "Sign"
	add_child(_sign)
	_number = ExponentDisplay.make_label("Number")
	add_child(_number)
	sort_children.connect(queue_redraw)
	_refresh()


## Shows the root of n.
func show_root(n: int) -> void:
	_number.text = Text.display_value(n)
	queue_redraw()


func number_label() -> Label:
	return _number


func _refresh() -> void:
	if _number == null:
		return
	var size_now: int = maxi(roundi(ExponentDisplay.BASE_SIZE * size_scale), 12)
	_number.add_theme_font_size_override(&"font_size", size_now)
	_sign.custom_minimum_size = Vector2(size_now * 0.55, size_now * 1.1)
	_sign.queue_redraw()
	queue_redraw()


## The bar over the number, from the top of the sign's long stroke to the number's right edge.
func _draw() -> void:
	if _number == null or _number.size.x <= 0.0:
		return
	var y: float = _number.position.y + 4.0
	draw_line(Vector2(_sign.position.x + _sign.size.x, y), Vector2(_number.position.x + _number.size.x + 4.0, y), STROKE, 4.0)


## The radical sign itself: a small tick down, then a long stroke up to the top right corner.
class _RadicalSign:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(w * 0.05, h * 0.6), Vector2(w * 0.25, h * 0.52), Vector2(w * 0.5, h * 0.95), Vector2(w, h * 0.0 + 4.0)])
		draw_polyline(points, RootDisplay.STROKE, 4.0, true)
