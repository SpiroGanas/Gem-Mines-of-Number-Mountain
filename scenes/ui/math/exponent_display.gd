## A power written the way a math book writes it: the base, and the exponent smaller and raised (2⁵).
## Composed from two Labels in a row (Spiro's decision, Phase 4 plan decision 2): the exponent Label
## shrinks to the top of the row, so it sits raised beside the base whatever the font. BBCode is not
## used: Godot 4.7's RichTextLabel has no superscript tag, and two Labels lay out predictably.
## Also used for the "10⁵" of scientific notation (SciNotationDisplay) and the scientific-notation pad.
##
## Presentation only and never interactive (mouse_filter IGNORE), so it can sit inside a Button.
## Godot note: a *scene* here is a tiny .tscn whose root runs this script; other scenes instance it.
class_name ExponentDisplay
extends HBoxContainer

## Font sizes at size_scale 1.0: the theme's number size for the base, a bit over half for the exponent.
const BASE_SIZE: int = 96
const EXPONENT_SHARE: float = 0.55

## The base's text ("2"); empty shows nothing.
@export var base_text: String = "":
	set(value):
		base_text = value
		_refresh()
## The exponent's text ("5"); empty draws an empty raised slot (the pad's box shows there instead).
@export var exponent_text: String = "":
	set(value):
		exponent_text = value
		_refresh()
## 1.0 is the theme's big number size; answer buttons and picture cards use less.
@export var size_scale: float = 1.0:
	set(value):
		size_scale = value
		_refresh()

var _base: Label
var _exponent: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 2)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_base = make_label("Base")
	_base.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_base)
	_exponent = make_label("Exponent")
	_exponent.size_flags_vertical = Control.SIZE_SHRINK_BEGIN # raised: the top of the row
	add_child(_exponent)
	_refresh()


## Shows base^exponent from whole numbers.
func show_power(base: int, exponent: int) -> void:
	base_text = Text.display_value(base)
	exponent_text = Text.display_value(exponent)


func base_label() -> Label:
	return _base


func exponent_label() -> Label:
	return _exponent


## The exponent's font size over the base's: below 1, so the exponent is smaller.
func exponent_ratio() -> float:
	return float(_exponent.get_theme_font_size(&"font_size")) / float(maxi(_base.get_theme_font_size(&"font_size"), 1))


static func make_label(node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _refresh() -> void:
	if _base == null:
		return
	var size_now: int = maxi(roundi(BASE_SIZE * size_scale), 12)
	_base.add_theme_font_size_override(&"font_size", size_now)
	_exponent.add_theme_font_size_override(&"font_size", maxi(roundi(size_now * EXPONENT_SHARE), 10))
	_base.text = base_text
	_exponent.text = exponent_text
