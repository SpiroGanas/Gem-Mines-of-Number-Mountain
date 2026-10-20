## A mathematician badge (Sprint 19): Kenney's CC0 medal glyph tinted gold, with the badge's emblem
## drawn in code on it. No portraits: each badge shows the idea the mathematician is known for.
##   pairs       Gauss: two arcs joining the ends of a row (1 + 100, 2 + 99...)
##   factors     Euclid: a rectangle of blocks
##   sieve       Eratosthenes: a grid with crossed-out squares
##   prime_star  Sophie Germain: a four-pointed prime star
##   staircase   Gauss's staircases (Zone 9): two staircases of blocks fitted into a rectangle
## A badge not earned yet is drawn dim and grey, so the shape still shows what to look forward to.
class_name BadgeArt
extends Control

const MEDAL_PATH: String = "res://assets/art/kenney/icons/medal_ribbon.png"
const GOLD: Color = Color("#FFD166")
const INK: Color = Color("#1F2945")
const LOCKED: Color = Color(0.45, 0.5, 0.62, 1.0)

static var _medal: Texture2D

var emblem: StringName = &"pairs":
	set(value):
		emblem = value
		queue_redraw()
var earned: bool = true:
	set(value):
		earned = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if _medal == null and ResourceLoader.exists(MEDAL_PATH):
		_medal = load(MEDAL_PATH)
	var side: float = minf(size.x, size.y)
	var box: Rect2 = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var tint: Color = GOLD if earned else LOCKED
	if _medal != null:
		draw_texture_rect(_medal, box, false, tint)
	else:
		draw_circle(box.get_center(), side * 0.4, tint)
	# the medal's disc sits in the lower part of the glyph
	var center: Vector2 = box.position + Vector2(side * 0.5, side * 0.62)
	var r: float = side * 0.2
	var ink: Color = INK if earned else Color(INK, 0.6)
	match emblem:
		&"pairs":
			for i: int in 3:
				var spread: float = r * (1.0 - 0.3 * float(i))
				draw_arc(center + Vector2(0, r * 0.4), spread, PI, TAU, 12, ink, 2.5)
			draw_line(center + Vector2(-r, r * 0.4), center + Vector2(r, r * 0.4), ink, 2.5)
		&"factors":
			var cell: float = r * 0.5
			for row: int in 3:
				for col: int in 4:
					draw_rect(Rect2(center + Vector2(-2 * cell + col * cell, -1.5 * cell + row * cell), Vector2(cell - 2, cell - 2)), ink)
		&"sieve":
			var cell: float = r * 0.5
			for row: int in 3:
				for col: int in 3:
					var spot: Rect2 = Rect2(center + Vector2(-1.5 * cell + col * cell, -1.5 * cell + row * cell), Vector2(cell - 2, cell - 2))
					draw_rect(spot, ink, false, 1.5)
					if (row * 3 + col) % 2 == 1:
						draw_line(spot.position, spot.end, ink, 1.5)
		&"prime_star":
			var star: PackedVector2Array = PackedVector2Array()
			for i: int in 8:
				var angle: float = TAU * float(i) / 8.0 - PI / 2.0
				var reach: float = r if i % 2 == 0 else r * 0.4
				star.append(center + Vector2(cos(angle), sin(angle)) * reach)
			draw_colored_polygon(star, ink)
		&"staircase":
			# Rows of 1 to 4 solid blocks and the turned staircase as outlines: a 4 by 5 rectangle.
			var cell: float = r * 0.42
			for row: int in 4:
				for col: int in 5:
					var spot: Rect2 = Rect2(center + Vector2(-2.5 * cell + col * cell, -2.0 * cell + row * cell), Vector2(cell - 2, cell - 2))
					if col <= row:
						draw_rect(spot, ink)
					else:
						draw_rect(spot, ink, false, 1.5)
