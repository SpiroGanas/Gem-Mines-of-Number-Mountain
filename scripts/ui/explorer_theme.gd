## Builds the Explorer-mode theme: large text in Andika, high contrast, chunky buttons.
##
## Built in code instead of a hand-edited .tres so every size derives from one
## place (and from UI.min_target_px()), and so a diff shows exactly what changed.
## The buttons are Kenney's CC0 UI Pack textures (yellow for most, green for "go" buttons, grey
## when disabled) as nine-slice StyleBoxTextures, so they stretch to any touch-target size
## without blurring; the Word Gem chips keep a flat lavender box the pack has no color for.
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
## Andika (SIL International, SIL Open Font License 1.1): drawn for beginning readers, with
## unambiguous letter shapes. Regular for everything, Bold for the highlighted numbers in Bolt's
## bubble. See docs/sdk-audit.md and assets/CREDITS.md.
const FONT_REGULAR_PATH: String = "res://assets/fonts/andika/Andika-Regular.ttf"
const FONT_BOLD_PATH: String = "res://assets/fonts/andika/Andika-Bold.ttf"
## Smallest acceptable contrast between text and its background (WCAG AAA for normal text).
const MIN_TEXT_CONTRAST: float = 7.0

# Palette. The mine background is deep navy; text on it is off-white; buttons are Kenney's warm
# yellow with navy text. Colour is never the only clue: states also change shape/outline.
const NAVY: Color = Color("#1F2945")
const NAVY_LIGHT: Color = Color("#2E3C66")
const OFF_WHITE: Color = Color("#F5F7FF")
const GREY_DISABLED: Color = Color("#A9B0C6")
## Kenney UI Pack button textures (192x64, assets/CREDITS.md), by theme type and state.
const BUTTON_TEXTURE_DIR: String = "res://assets/art/kenney/ui"
const BUTTON_TEXTURES: Dictionary = {
	&"Button": {"normal": "button_yellow_normal", "hover": "button_yellow_hover", "pressed": "button_yellow_pressed"},
	&"GoButton": {"normal": "button_green_normal", "hover": "button_green_hover", "pressed": "button_green_pressed"},
}
const DISABLED_TEXTURE: String = "button_grey_disabled"
## The textures' rounded corners; the bottom edge of a raised button also carries its depth shadow.
const TEXTURE_MARGIN: int = 12
const TEXTURE_MARGIN_DEPTH: int = 18
## Kenney's green is lifted a little so navy text keeps AAA contrast on it (the theme test samples
## the texture's pixels to prove it); the yellow needs no lift.
const GREEN_LIFT: Color = Color(1.2, 1.2, 1.2)
## Word Gem chips: light amethyst (the mastery gem's color), navy text.
const LAVENDER: Color = Color("#C9B3F0")
const LAVENDER_HOVER: Color = Color("#D9C8F5")
const LAVENDER_PRESSED: Color = Color("#B39AE6")
const WORD_GEM_SIZE: int = 40
const FOCUS_OUTLINE: Color = Color("#FFFFFF")


## Builds a fresh theme. target_px is the minimum touch-target size (UI.min_target_px()); it sizes
## the buttons' padding so a plain button is about one target tall. layout_px (UI.layout_unit_px(),
## the target or, on a phone, the design canvas's 64 px; 0 means target_px) sizes panel padding.
static func build(target_px: int, layout_px: int = 0) -> Theme:
	if layout_px <= 0:
		layout_px = target_px
	var theme: Theme = Theme.new()
	theme.default_font_size = BODY_SIZE
	var regular: Font = load(FONT_REGULAR_PATH)
	var bold: Font = load(FONT_BOLD_PATH)
	if regular == null or bold == null:
		push_warning("ExplorerTheme: the Andika font is missing; using the engine font")
	else:
		theme.default_font = regular # every Label and Button reads in Andika
		theme.set_font(&"normal_font", &"RichTextLabel", regular)
		theme.set_font(&"bold_font", &"RichTextLabel", bold)
		theme.set_font(&"italics_font", &"RichTextLabel", regular)
		theme.set_font(&"bold_italics_font", &"RichTextLabel", bold)

	theme.set_font_size(&"font_size", &"Label", BODY_SIZE)
	theme.set_color(&"font_color", &"Label", OFF_WHITE)
	theme.set_font_size(&"font_size", &"HeadingLabel", HEADING_SIZE)
	theme.set_type_variation(&"HeadingLabel", &"Label")
	theme.set_color(&"font_color", &"HeadingLabel", OFF_WHITE)
	theme.set_font_size(&"font_size", &"NumberLabel", NUMBER_SIZE)
	theme.set_type_variation(&"NumberLabel", &"Label")
	theme.set_color(&"font_color", &"NumberLabel", OFF_WHITE)
	# Bolt's speech bubble is a RichTextLabel (highlighted numbers, tappable Word Gems).
	for size_name: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
		theme.set_font_size(size_name, &"RichTextLabel", BODY_SIZE)
	theme.set_color(&"default_color", &"RichTextLabel", OFF_WHITE)

	_style_textured_button(theme, &"Button", target_px, Color.WHITE)
	# "Go" and other confirm buttons: green; the label still says what they do.
	theme.set_type_variation(&"GoButton", &"Button")
	_style_textured_button(theme, &"GoButton", target_px, GREEN_LIFT)

	theme.set_type_variation(&"WordGemButton", &"Button")
	_style_button(theme, &"WordGemButton", target_px, LAVENDER, LAVENDER_HOVER, LAVENDER_PRESSED)
	theme.set_font_size(&"font_size", &"WordGemButton", WORD_GEM_SIZE)

	var panel: StyleBoxFlat = _box(NAVY_LIGHT, OFF_WHITE, CORNER_RADIUS, int(layout_px * 0.33))
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


## A Kenney-textured button type: raised at rest and hovered, flat (pushed down) while pressed,
## grey when disabled, and a white outline for keyboard focus.
static func _style_textured_button(theme: Theme, type: StringName, target_px: int, lift: Color) -> void:
	var margin: int = maxi(int(target_px * 0.25), 12)
	var names: Dictionary = BUTTON_TEXTURES[type]
	theme.set_font_size(&"font_size", type, BUTTON_SIZE)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		theme.set_color(color_name, type, NAVY)
	theme.set_stylebox(&"normal", type, _textured(names["normal"], TEXTURE_MARGIN_DEPTH, margin, lift))
	theme.set_stylebox(&"hover", type, _textured(names["hover"], TEXTURE_MARGIN_DEPTH, margin, lift))
	theme.set_stylebox(&"pressed", type, _textured(names["pressed"], TEXTURE_MARGIN, margin, lift))
	theme.set_stylebox(&"disabled", type, _textured(DISABLED_TEXTURE, TEXTURE_MARGIN_DEPTH, margin, Color.WHITE))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), FOCUS_OUTLINE, CORNER_RADIUS, margin)
	focus.set_border_width_all(BORDER_WIDTH + 2)
	theme.set_stylebox(&"focus", type, focus)


## A nine-slice box from one of the button textures. `bottom_margin` is larger for the raised
## textures, whose bottom edge is the depth shadow; the text then sits above the shadow.
static func _textured(name: String, bottom_margin: int, content_margin: int, lift: Color) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load("%s/%s.png" % [BUTTON_TEXTURE_DIR, name])
	box.texture_margin_left = TEXTURE_MARGIN
	box.texture_margin_right = TEXTURE_MARGIN
	box.texture_margin_top = TEXTURE_MARGIN
	box.texture_margin_bottom = bottom_margin
	box.set_content_margin_all(content_margin)
	box.content_margin_bottom = content_margin + (bottom_margin - TEXTURE_MARGIN)
	box.modulate_color = lift
	return box


## A flat button type (the Word Gem chips): a filled, outlined, rounded box per state.
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
