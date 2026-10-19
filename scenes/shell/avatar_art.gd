## The eight profile avatars (Profile.AVATARS), drawn in code like IconArt: a colored disc with a
## simple Bolt-themed mining picture on it. Never a photo. Each avatar has its own disc color and its
## own shape, so two children can tell their tiles apart without reading a name.
class_name AvatarArt
extends Control

const INK: Color = Color("#1F2945")
## Disc colors, one per avatar (and distinct in shape too, so color is never the only cue).
const DISC_COLORS: Dictionary = {
	&"bolt": Color("#8FD3FF"), &"lamp": Color("#FFD166"), &"gem": Color("#C9A7FF"), &"pickaxe": Color("#F4A261"),
	&"cart": Color("#7BD88F"), &"crystal": Color("#9EE6E0"), &"rocket": Color("#FF9AA2"), &"gear": Color("#D8DEE9"),
}

@export var avatar_id: StringName = Profile.DEFAULT_AVATAR:
	set(value):
		avatar_id = value if Profile.is_valid_avatar(value) else Profile.DEFAULT_AVATAR
		queue_redraw()


## Adds a small avatar at the left edge of `button` (like IconArt.attach) and widens its padding.
static func attach(button: Button, id: StringName) -> AvatarArt:
	var picture: AvatarArt = AvatarArt.new()
	picture.avatar_id = id
	var side: float = float(UI.min_target_px()) * 0.75
	picture.custom_minimum_size = Vector2(side, side)
	picture.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	picture.offset_left = 14.0
	picture.offset_right = 14.0 + side
	picture.offset_top = -side * 0.5
	picture.offset_bottom = side * 0.5
	button.add_child(picture)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		var base: StyleBox = button.get_theme_stylebox(style_name)
		if base == null:
			continue
		var box: StyleBox = base.duplicate()
		box.content_margin_left = maxf(box.content_margin_left, 0.0) + side + 20.0
		button.add_theme_stylebox_override(style_name, box)
	return picture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: Vector2 = Vector2.ONE * minf(size.x, size.y)
	var o: Vector2 = (size - s) * 0.5
	var w: float = maxf(s.x * 0.06, 3.0)
	draw_circle(o + s * 0.5, s.x * 0.48, DISC_COLORS.get(avatar_id, DISC_COLORS[Profile.DEFAULT_AVATAR]))
	draw_arc(o + s * 0.5, s.x * 0.48, 0.0, TAU, 40, INK, w * 0.6)
	match avatar_id:
		&"bolt": # Bolt's head: a rounded box, two eyes, an antenna with a light
			draw_rect(Rect2(o + Vector2(0.28, 0.34) * s, Vector2(0.44, 0.36) * s), INK)
			draw_circle(o + Vector2(0.4, 0.5) * s, s.x * 0.05, DISC_COLORS[&"bolt"])
			draw_circle(o + Vector2(0.6, 0.5) * s, s.x * 0.05, DISC_COLORS[&"bolt"])
			draw_line(o + Vector2(0.5, 0.34) * s, o + Vector2(0.5, 0.22) * s, INK, w)
			draw_circle(o + Vector2(0.5, 0.2) * s, s.x * 0.045, Color("#FFE9A8"))
		&"lamp": # an electric lantern: a glass box with a glowing bulb
			draw_rect(Rect2(o + Vector2(0.34, 0.3) * s, Vector2(0.32, 0.44) * s), INK, false, w)
			draw_line(o + Vector2(0.42, 0.24) * s, o + Vector2(0.58, 0.24) * s, INK, w)
			draw_circle(o + Vector2(0.5, 0.52) * s, s.x * 0.09, Color("#FFF4C2"))
		&"gem": # a cut gem
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.3, 0.4) * s, o + Vector2(0.4, 0.28) * s, o + Vector2(0.6, 0.28) * s, o + Vector2(0.7, 0.4) * s, o + Vector2(0.5, 0.74) * s]), INK)
			draw_line(o + Vector2(0.3, 0.4) * s, o + Vector2(0.7, 0.4) * s, DISC_COLORS[&"gem"], w * 0.5)
		&"pickaxe": # a pickaxe
			draw_line(o + Vector2(0.32, 0.74) * s, o + Vector2(0.66, 0.34) * s, INK, w * 1.2)
			draw_arc(o + Vector2(0.6, 0.42) * s, s.x * 0.24, -2.5, -0.5, 14, INK, w * 1.4)
		&"cart": # a mine cart on a rail
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.26, 0.36) * s, o + Vector2(0.74, 0.36) * s, o + Vector2(0.68, 0.6) * s, o + Vector2(0.32, 0.6) * s]), INK)
			draw_circle(o + Vector2(0.38, 0.66) * s, s.x * 0.06, INK)
			draw_circle(o + Vector2(0.62, 0.66) * s, s.x * 0.06, INK)
			draw_line(o + Vector2(0.18, 0.74) * s, o + Vector2(0.82, 0.74) * s, INK, w * 0.7)
		&"crystal": # three crystal spikes
			for spike: Array in [[0.38, 0.4], [0.5, 0.26], [0.62, 0.4]]:
				draw_colored_polygon(PackedVector2Array([o + Vector2(spike[0] - 0.07, 0.72) * s, o + Vector2(spike[0], spike[1]) * s, o + Vector2(spike[0] + 0.07, 0.72) * s]), INK)
		&"rocket": # a small rocket
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.5, 0.2) * s, o + Vector2(0.6, 0.38) * s, o + Vector2(0.6, 0.66) * s, o + Vector2(0.4, 0.66) * s, o + Vector2(0.4, 0.38) * s]), INK)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.4, 0.56) * s, o + Vector2(0.3, 0.74) * s, o + Vector2(0.4, 0.68) * s]), INK)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.6, 0.56) * s, o + Vector2(0.7, 0.74) * s, o + Vector2(0.6, 0.68) * s]), INK)
			draw_circle(o + Vector2(0.5, 0.44) * s, s.x * 0.05, DISC_COLORS[&"rocket"])
		&"gear": # a gear
			draw_arc(o + s * 0.5, s.x * 0.15, 0.0, TAU, 20, INK, w * 1.2)
			for tooth: int in 8:
				var angle: float = TAU * float(tooth) / 8.0
				var direction: Vector2 = Vector2(cos(angle), sin(angle))
				draw_line(o + s * 0.5 + direction * s.x * 0.18, o + s * 0.5 + direction * s.x * 0.28, INK, w * 1.2)
