## The title picture (placeholder art pass): Number Mountain with a gem on its peak and an electric
## lamp at the mine door. Drawn in code until the commissioned logo (Phase 2).
class_name TitleArt
extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: Vector2 = size
	draw_colored_polygon(PackedVector2Array([Vector2(0.1, 0.95) * s, Vector2(0.42, 0.25) * s, Vector2(0.55, 0.45) * s, Vector2(0.68, 0.32) * s, Vector2(0.92, 0.95) * s]), Color("#4A5679"))
	draw_colored_polygon(PackedVector2Array([Vector2(0.36, 0.38) * s, Vector2(0.42, 0.25) * s, Vector2(0.48, 0.36) * s]), Color("#F5F7FF"))
	var gem: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in GemArt.shape_points(GemArt.AMETHYST):
		gem.append(Vector2(0.42, 0.04) * s + point * Vector2(0.06, 0.2) * s)
	draw_colored_polygon(gem, GemArt.color_for(GemArt.AMETHYST))
	draw_rect(Rect2(Vector2(0.46, 0.76) * s, Vector2(0.08, 0.19) * s), Color("#1F2945"))
	draw_circle(Vector2(0.5, 0.72) * s, s.y * 0.05, Color(1.0, 0.86, 0.45, 0.4))
	draw_circle(Vector2(0.5, 0.72) * s, s.y * 0.02, Color("#FFE9A8"))
