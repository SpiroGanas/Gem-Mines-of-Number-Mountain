## A congruence written with its sign: a ≡ b (mod n) (Zone 10). The three-bar sign is drawn in code with lines, so it
## does not depend on the font having the ≡ character (like RootDisplay's √). "(mod n)" comes from the text table.
## Presentation only, never interactive.
class_name CongruenceDisplay
extends HBoxContainer

const STROKE: Color = Color("#F5F7FF")

## 1.0 is the theme's big number size.
@export var size_scale: float = 1.0:
	set(value):
		size_scale = value
		_refresh()

var _left: Label
var _sign: _TripleBar
var _right: Label
var _mod: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 12)
	_left = ExponentDisplay.make_label("Left")
	add_child(_left)
	_sign = _TripleBar.new()
	_sign.name = "Sign"
	add_child(_sign)
	_right = ExponentDisplay.make_label("Right")
	add_child(_right)
	_mod = ExponentDisplay.make_label("Mod")
	add_child(_mod)
	_refresh()


## Shows a ≡ b (mod n).
func show_congruence(a: int, b: int, n: int) -> void:
	_left.text = Text.display_value(a)
	_right.text = Text.display_value(b)
	_mod.text = Text.get_line(&"z10.notation.mod_n", {"n": n})
	queue_redraw()


func left_label() -> Label:
	return _left


func right_label() -> Label:
	return _right


func mod_label() -> Label:
	return _mod


func _refresh() -> void:
	if _left == null:
		return
	var size_now: int = maxi(roundi(ExponentDisplay.BASE_SIZE * size_scale), 12)
	for label: Label in [_left, _right, _mod]:
		label.add_theme_font_size_override(&"font_size", size_now)
	_sign.custom_minimum_size = Vector2(size_now * 0.7, size_now * 0.9)
	_sign.queue_redraw()


## Three bars one above the other.
class _TripleBar:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for row: int in 3:
			var y: float = size.y * (0.3 + 0.2 * row)
			draw_line(Vector2(size.x * 0.05, y), Vector2(size.x * 0.95, y), CongruenceDisplay.STROKE, 5.0, true)
