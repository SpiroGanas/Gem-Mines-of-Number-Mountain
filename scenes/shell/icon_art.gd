## Small pictures for buttons: every workshop button has a picture as well as its word (GDD
## section 3), so a child who cannot read a label yet can still find Dig, the Museum or the Garage.
## attach() puts one at the left of a button. The gear, the padlock, the wrench and the back arrow
## are Kenney's CC0 Game Icons (white glyphs tinted navy); the pickaxe and the museum case, which
## the pack does not have, are drawn in code in the same flat style.
class_name IconArt
extends Control

const KINDS: Array[StringName] = [&"dig", &"museum", &"garage", &"settings", &"grownups", &"back", &"workshop", &"build"]
const INK: Color = Color("#1F2945")
## Kenney Game Icons (assets/CREDITS.md) for the kinds the pack covers.
const TEXTURE_PATHS: Dictionary = {
	&"settings": "res://assets/art/kenney/icons/gear.png",
	&"grownups": "res://assets/art/kenney/icons/locked.png",
	&"garage": "res://assets/art/kenney/icons/wrench.png",
	&"back": "res://assets/art/kenney/icons/return.png",
}

static var _textures: Dictionary = {}

@export var kind: StringName = &"dig":
	set(value):
		kind = value
		queue_redraw()


## Adds an icon at the left edge of `button` and widens the button's left padding to fit it.
static func attach(button: Button, icon_kind: StringName) -> IconArt:
	var icon: IconArt = IconArt.new()
	icon.kind = icon_kind
	var side: float = float(UI.min_target_px()) * 0.7
	icon.custom_minimum_size = Vector2(side, side)
	icon.size = Vector2(side, side)
	icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 18.0
	icon.offset_right = 18.0 + side
	icon.offset_top = -side * 0.5
	icon.offset_bottom = side * 0.5
	button.add_child(icon)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var base: StyleBox = button.get_theme_stylebox(style_name)
		if base == null:
			continue
		var box: StyleBox = base.duplicate()
		box.content_margin_left = maxf(box.content_margin_left, 0.0) + side + 24.0
		button.add_theme_stylebox_override(style_name, box)
	return icon


## The pack glyph for a kind, loaded once, or null for a drawn kind.
static func texture_for(icon_kind: StringName) -> Texture2D:
	if not TEXTURE_PATHS.has(icon_kind):
		return null
	if not _textures.has(icon_kind):
		_textures[icon_kind] = load(TEXTURE_PATHS[icon_kind])
	return _textures[icon_kind]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: Vector2 = size
	var glyph: Texture2D = texture_for(kind)
	if glyph != null:
		draw_texture_rect(glyph, Rect2(Vector2.ZERO, s), false, INK) # a white glyph tinted navy
		return
	var w: float = maxf(s.x * 0.09, 3.0)
	match kind:
		&"dig": # a pickaxe
			draw_line(Vector2(0.25, 0.85) * s, Vector2(0.7, 0.3) * s, INK, w * 1.2)
			draw_arc(Vector2(0.62, 0.42) * s, s.x * 0.36, -2.4, -0.6, 12, INK, w * 1.4)
		&"museum": # a gem in a display case
			draw_rect(Rect2(Vector2(0.1, 0.12) * s, Vector2(0.8, 0.76) * s), INK, false, w)
			draw_colored_polygon(PackedVector2Array([Vector2(0.5, 0.25) * s, Vector2(0.7, 0.45) * s, Vector2(0.5, 0.75) * s, Vector2(0.3, 0.45) * s]), INK)
		&"garage": # a wrench
			draw_line(Vector2(0.25, 0.8) * s, Vector2(0.62, 0.42) * s, INK, w * 1.4)
			draw_arc(Vector2(0.68, 0.34) * s, s.x * 0.18, 0.0, TAU * 0.8, 14, INK, w)
		&"settings": # a gear
			draw_arc(s * 0.5, s.x * 0.22, 0.0, TAU, 20, INK, w)
			for tooth: int in 8:
				var angle: float = TAU * float(tooth) / 8.0
				draw_line(s * 0.5 + Vector2(cos(angle), sin(angle)) * s.x * 0.28, s * 0.5 + Vector2(cos(angle), sin(angle)) * s.x * 0.42, INK, w)
		&"grownups": # a padlock
			draw_rect(Rect2(Vector2(0.22, 0.45) * s, Vector2(0.56, 0.42) * s), INK)
			draw_arc(Vector2(0.5, 0.45) * s, s.x * 0.18, PI, TAU, 12, INK, w)
		&"workshop": # a hammer over a gem
			draw_line(Vector2(0.2, 0.8) * s, Vector2(0.6, 0.4) * s, INK, w * 1.2)
			draw_rect(Rect2(Vector2(0.48, 0.14) * s, Vector2(0.36, 0.2) * s), INK)
			draw_colored_polygon(PackedVector2Array([Vector2(0.72, 0.55) * s, Vector2(0.86, 0.7) * s, Vector2(0.72, 0.88) * s, Vector2(0.58, 0.7) * s]), INK)
		&"build": # a rail on two sleepers with a cart
			draw_line(Vector2(0.08, 0.78) * s, Vector2(0.92, 0.78) * s, INK, w)
			draw_line(Vector2(0.25, 0.78) * s, Vector2(0.25, 0.9) * s, INK, w)
			draw_line(Vector2(0.75, 0.78) * s, Vector2(0.75, 0.9) * s, INK, w)
			draw_rect(Rect2(Vector2(0.28, 0.36) * s, Vector2(0.44, 0.3) * s), INK)
			draw_circle(Vector2(0.36, 0.7) * s, s.x * 0.06, INK)
			draw_circle(Vector2(0.64, 0.7) * s, s.x * 0.06, INK)
		&"back": # an arrow pointing left
			draw_line(Vector2(0.8, 0.5) * s, Vector2(0.25, 0.5) * s, INK, w * 1.2)
			draw_colored_polygon(PackedVector2Array([Vector2(0.15, 0.5) * s, Vector2(0.4, 0.28) * s, Vector2(0.4, 0.72) * s]), INK)
