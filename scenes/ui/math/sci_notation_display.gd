## Scientific notation written out: the first number, "×", and 10 with its power raised (3.4 × 10⁵).
## The "10⁵" is an ExponentDisplay. Values are exact ({mantissa, scale, exp} from Notation); nothing is
## ever turned into a float. Presentation only, never interactive.
class_name SciNotationDisplay
extends HBoxContainer

## 1.0 is the theme's big number size.
@export var size_scale: float = 1.0:
	set(value):
		size_scale = value
		_refresh()

var _mantissa: Label
var _times: Label
var _power: ExponentDisplay
var _value: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 8)
	_mantissa = ExponentDisplay.make_label("Mantissa")
	_mantissa.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_mantissa)
	_times = ExponentDisplay.make_label("Times")
	_times.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_times)
	_power = ExponentDisplay.new()
	_power.name = "Power"
	_power.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_power)
	_refresh()


## Shows {mantissa, scale, exp}: mantissa / 10^scale × 10^exp.
func show_value(value: Dictionary) -> void:
	_value = value.duplicate()
	_refresh()


## The first number's text ("3.4").
func mantissa_text() -> String:
	return _mantissa.text


func power() -> ExponentDisplay:
	return _power


func _refresh() -> void:
	if _power == null:
		return
	var size_now: int = maxi(roundi(ExponentDisplay.BASE_SIZE * size_scale), 12)
	_mantissa.add_theme_font_size_override(&"font_size", size_now)
	_times.add_theme_font_size_override(&"font_size", size_now)
	_power.size_scale = size_scale
	_times.text = "×"
	_power.base_text = "10"
	if _value.is_empty():
		_mantissa.text = ""
		_power.exponent_text = ""
		return
	_mantissa.text = Text.format_decimal({"mantissa": int(_value["mantissa"]), "scale": int(_value["scale"])})
	_power.exponent_text = Text.display_value(int(_value["exp"]))
