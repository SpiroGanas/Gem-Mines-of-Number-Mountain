## Builds the Explorer-mode theme: large text, high contrast, rounded chunky buttons.
##
## Built in code instead of a hand-edited .tres so every size derives from one
## place (and from UI.min_target_px()), and so a diff shows exactly what changed.
## Pure: no nodes, no globals. UI.theme() caches the result.
##
## Godot note: a Theme is a resource that holds fonts, colors, font sizes and
## StyleBoxes per control type. Assigning one to a root Control restyles every
## child, so scenes never set fonts or colors one by one.
class_name ExplorerTheme
extends RefCounted

## Text sizes in canvas pixels on the 1920x1080 design canvas.
const BODY_SIZE: int = 44
const BUTTON_SIZE: int = 48
const HEADING_SIZE: int = 72
const NUMBER_SIZE: int = 96

const CORNER_RADIUS: int = 28
const BORDER_WIDTH: int = 4
## Smallest acceptable contrast between text and its background (WCAG AAA for normal text).
const MIN_TEXT_CONTRAST: float = 7.0

# Palette. The mine background is deep navy; text on it is off-white; buttons are warm
# yellow with navy text. Colour is never the only clue: states also change shape/outline.
const NAVY: Color = Color("#1F2945")
const NAVY_LIGHT: Color = Color("#2E3C66")
const OFF_WHITE: Color = Color("#F5F7FF")
const YELLOW: Color = Color("#FFD166")
const YELLOW_PRESSED: Color = Color("#E8B23C")
const YELLOW_HOVER: Color = Color("#FFDE8A")
const GREEN: Color = Color("#7BD88F")
const GREEN_HOVER: Color = Color("#99E3A9")
const GREEN_PRESSED: Color = Color("#55B96C")
const GREY_DISABLED: Color = Color("#A9B0C6")
const FOCUS_OUTLINE: Color = Color("#FFFFFF")


## Builds a fresh theme. target_px is the minimum touch-target size (UI.min_target_px()).
static func build(target_px: int) -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = BODY_SIZE

	theme.set_font_size(&"font_size", &"Label", BODY_SIZE)
	theme.set_color(&"font_color", &"Label", OFF_WHITE)
	theme.set_font_size(&"font_size", &"HeadingLabel", HEADING_SIZE)
	theme.set_type_variation(&"HeadingLabel", &"Label")
	theme.set_color(&"font_color", &"HeadingLabel", OFF_WHITE)
	theme.set_font_size(&"font_size", &"NumberLabel", NUMBER_SIZE)
	theme.set_type_variation(&"NumberLabel", &"Label")
	theme.set_color(&"font_color", &"NumberLabel", OFF_WHITE)

	_style_button(theme, &"Button", target_px, YELLOW, YELLOW_HOVER, YELLOW_PRESSED)
	# "Go" and other confirm buttons: green fill; the label still says what they do.
	theme.set_type_variation(&"GoButton", &"Button")
	_style_button(theme, &"GoButton", target_px, GREEN, GREEN_HOVER, GREEN_PRESSED)

	var panel: StyleBoxFlat = _box(NAVY_LIGHT, OFF_WHITE, CORNER_RADIUS, int(target_px * 0.33))
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	return theme


## WCAG relative-luminance contrast ratio between two colours, from 1.0 (identical) to 21.0.
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


static func _linear(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)


static func _style_button(theme: Theme, type: StringName, target_px: int, fill: Color, hover: Color, pressed: Color) -> void:
	var margin: int = maxi(int(target_px * 0.25), 12)
	theme.set_font_size(&"font_size", type, BUTTON_SIZE)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		theme.set_color(color_name, type, NAVY)
	theme.set_stylebox(&"normal", type, _box(fill, NAVY, CORNER_RADIUS, margin))
	theme.set_stylebox(&"hover", type, _box(hover, NAVY, CORNER_RADIUS, margin))
	theme.set_stylebox(&"pressed", type, _box(pressed, NAVY, CORNER_RADIUS, margin))
	theme.set_stylebox(&"disabled", type, _box(GREY_DISABLED, NAVY_LIGHT, CORNER_RADIUS, margin))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), FOCUS_OUTLINE, CORNER_RADIUS, margin)
	focus.set_border_width_all(BORDER_WIDTH + 2)
	theme.set_stylebox(&"focus", type, focus)


static func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
