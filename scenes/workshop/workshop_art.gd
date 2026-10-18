## Code-drawn pictures for the workshop (Sprint 16): what a recipe makes, and the two build
## projects as machines. Placeholder art in the style of GemArt and IconArt; the Sprint 20 art pass may
## swap in sprites behind the same node. Electric light only (CLAUDE.md content rules): no steam,
## smoke or flame anywhere.
##
##   pickaxe_t2, headlamp_white, hub_lanterns, crystal_lamp   what a recipe makes
##   cart_track         params {a, c, filled}: a rail of a units, a gap to c, filled when solved
##   balance_elevator   params {groups, size, balanced}: crates on one pan, the counterweight on the
##                      other; balanced lifts the cage
## `phase` (0..1) moves the machines; the hub tweens it while the machine is on screen.
class_name WorkshopArt
extends Control

const INK: Color = Color("#1F2945")
const RAIL: Color = Color("#B8C2D9")
const WOOD: Color = Color("#C98B4F")
const STEEL: Color = Color("#8A96B3")
const LIGHT: Color = Color("#FFE9A8")
const GLOW: Color = Color("#8FD3FF")
const GOOD: Color = Color("#7BD88F")
const CRATE: Color = Color("#D9A066")

var kind: StringName = &""
var params: Dictionary = {}
var phase: float = 0.0:
	set(value):
		phase = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_kind(new_kind: StringName, new_params: Dictionary = {}) -> void:
	kind = new_kind
	params = new_params.duplicate()
	queue_redraw()


func _draw() -> void:
	match kind:
		&"pickaxe_t2":
			_draw_pickaxe()
		&"headlamp_white":
			_draw_headlamp(Bolt.lamp_color("white"))
		&"hub_lanterns":
			_draw_lanterns(5)
		&"crystal_lamp":
			_draw_crystal_lamp()
		&"cart_track":
			_draw_cart_track()
		&"balance_elevator":
			_draw_balance_elevator()


func _box() -> Rect2:
	var side: float = minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _draw_pickaxe() -> void:
	var box: Rect2 = _box()
	var s: float = box.size.x
	var handle_from: Vector2 = box.position + Vector2(s * 0.25, s * 0.85)
	var handle_to: Vector2 = box.position + Vector2(s * 0.7, s * 0.3)
	draw_line(handle_from, handle_to, WOOD, s * 0.08)
	var head: PackedVector2Array = PackedVector2Array([
		box.position + Vector2(s * 0.35, s * 0.2), box.position + Vector2(s * 0.75, s * 0.18),
		box.position + Vector2(s * 0.95, s * 0.45), box.position + Vector2(s * 0.75, s * 0.32),
	])
	draw_colored_polygon(head, STEEL)
	draw_polyline(head + PackedVector2Array([head[0]]), INK, 2.0)
	draw_circle(box.position + Vector2(s * 0.62, s * 0.26), s * 0.06, GemArt.color_for(GemArt.GARNET))


func _draw_headlamp(lamp: Color) -> void:
	var box: Rect2 = _box()
	var center: Vector2 = box.get_center()
	var s: float = box.size.x
	draw_circle(center, s * 0.42, Color(lamp, 0.25))
	draw_arc(center, s * 0.36, PI * 0.85, PI * 2.15, 24, STEEL, s * 0.06)
	draw_circle(center + Vector2(0, -s * 0.05), s * 0.16, lamp)
	draw_arc(center + Vector2(0, -s * 0.05), s * 0.16, 0, TAU, 24, INK, 2.0)


func _draw_lanterns(count: int) -> void:
	var y: float = size.y * 0.3
	draw_line(Vector2(0, y - size.y * 0.1), Vector2(size.x, y - size.y * 0.1), STEEL, 2.0)
	for index: int in count:
		var x: float = size.x * (float(index) + 0.5) / float(count)
		var glow: float = 0.75 + 0.25 * sin(TAU * (phase + float(index) / float(count)))
		var center: Vector2 = Vector2(x, y + size.y * 0.12)
		draw_line(Vector2(x, y - size.y * 0.1), center, STEEL, 2.0)
		draw_circle(center, size.y * 0.16, Color(LIGHT, 0.3 * glow))
		draw_rect(Rect2(center - Vector2(size.y * 0.07, size.y * 0.09), Vector2(size.y * 0.14, size.y * 0.18)), Color(LIGHT, glow))
		draw_rect(Rect2(center - Vector2(size.y * 0.07, size.y * 0.09), Vector2(size.y * 0.14, size.y * 0.18)), INK, false, 2.0)


func _draw_crystal_lamp() -> void:
	var box: Rect2 = _box()
	var s: float = box.size.x
	var base: Rect2 = Rect2(box.position + Vector2(s * 0.3, s * 0.78), Vector2(s * 0.4, s * 0.12))
	draw_rect(base, STEEL)
	var glow: float = 0.8 + 0.2 * sin(TAU * phase)
	draw_circle(box.get_center() + Vector2(0, -s * 0.05), s * 0.38, Color(GemArt.color_for(GemArt.AMETHYST), 0.25 * glow))
	var crystal: PackedVector2Array = PackedVector2Array([
		box.position + Vector2(s * 0.5, s * 0.12), box.position + Vector2(s * 0.66, s * 0.4),
		box.position + Vector2(s * 0.58, s * 0.78), box.position + Vector2(s * 0.42, s * 0.78),
		box.position + Vector2(s * 0.34, s * 0.4),
	])
	draw_colored_polygon(crystal, GemArt.color_for(GemArt.AMETHYST).lightened(0.2 * glow))
	draw_polyline(crystal + PackedVector2Array([crystal[0]]), INK, 2.0)


## Rails across the picture; the first `a` units are laid, the gap runs to `c`. When `filled`, a bright
## new rail closes the gap and the cart rolls along it with `phase`.
func _draw_cart_track() -> void:
	var total: int = maxi(int(params.get("c", 10)), 1)
	var laid: int = clampi(int(params.get("a", 0)), 0, total)
	var filled: bool = bool(params.get("filled", false))
	var left: float = size.x * 0.06
	var width: float = size.x * 0.88
	var unit: float = width / float(total)
	var y: float = size.y * 0.62
	var thickness: float = maxf(size.y * 0.04, 3.0)
	# ground on both banks, the gap between them
	draw_rect(Rect2(0, y + thickness, left + unit * laid, size.y - y), Color("#3A4466"))
	draw_rect(Rect2(left + width, y + thickness, size.x - left - width, size.y - y), Color("#3A4466"))
	for index: int in total:
		var x: float = left + unit * index
		var placed: bool = index < laid
		var color: Color = RAIL if placed else (GOOD if filled else Color(RAIL, 0.18))
		draw_rect(Rect2(x + 1.0, y, unit - 2.0, thickness), color)
		draw_rect(Rect2(x + unit * 0.4, y + thickness, unit * 0.2, thickness * 1.5), WOOD if placed or filled else Color(WOOD, 0.15))
	var cart_x: float = left + (width - unit) * (phase if filled else 0.0)
	_draw_cart(Vector2(cart_x, y), minf(unit * 1.6, size.y * 0.3))


func _draw_cart(at: Vector2, width: float) -> void:
	var height: float = width * 0.6
	var body: Rect2 = Rect2(at + Vector2(0, -height - width * 0.12), Vector2(width, height))
	draw_rect(body, STEEL)
	draw_rect(body, INK, false, 2.0)
	draw_circle(body.position + Vector2(width * 0.5, -height * 0.1), height * 0.35, GemArt.color_for(GemArt.QUARTZ))
	for x: float in [width * 0.25, width * 0.75]:
		draw_circle(at + Vector2(x, -width * 0.1), width * 0.11, INK)


## A beam on a post. The left pan holds `groups` crates of `size` gems each; the right pan holds the
## counterweight. Unbalanced, the beam tips toward the crates; balanced, it is level and the elevator
## cage beside it rides up and down with `phase`.
func _draw_balance_elevator() -> void:
	var groups: int = clampi(int(params.get("groups", 2)), 1, 10)
	var each: int = clampi(int(params.get("size", 2)), 1, 10)
	var balanced: bool = bool(params.get("balanced", false))
	var shaft: Rect2 = Rect2(size.x * 0.82, size.y * 0.05, size.x * 0.12, size.y * 0.9)
	draw_rect(shaft, Color("#2A3352"))
	draw_rect(shaft, STEEL, false, 2.0)
	var lift: float = (0.5 - 0.5 * cos(TAU * phase)) if balanced else 0.0
	var cage: Rect2 = Rect2(shaft.position + Vector2(shaft.size.x * 0.1, shaft.size.y * (0.72 - 0.6 * lift)), Vector2(shaft.size.x * 0.8, shaft.size.y * 0.2))
	draw_rect(cage, LIGHT if balanced else STEEL)
	draw_rect(cage, INK, false, 2.0)
	var pivot: Vector2 = Vector2(size.x * 0.4, size.y * 0.35)
	draw_line(pivot, Vector2(pivot.x, size.y * 0.92), STEEL, maxf(size.x * 0.015, 3.0))
	var tilt: float = 0.0 if balanced else 0.18
	var reach: float = size.x * 0.3
	var left_end: Vector2 = pivot + Vector2(-reach, 0).rotated(-tilt)
	var right_end: Vector2 = pivot + Vector2(reach, 0).rotated(-tilt)
	draw_line(left_end, right_end, WOOD, maxf(size.y * 0.025, 3.0))
	draw_circle(pivot, size.y * 0.025, INK)
	var pan_width: float = reach * 0.9
	var crate: float = minf(pan_width / float(mini(groups, 5)) - 4.0, size.y * 0.14)
	for index: int in groups:
		var row: int = floori(index / 5.0)
		var column: int = index % 5
		var corner: Vector2 = left_end + Vector2(-pan_width * 0.5 + column * (crate + 4.0), size.y * 0.05 - (row + 1) * (crate + 4.0) + size.y * 0.12)
		draw_rect(Rect2(corner, Vector2(crate, crate)), CRATE)
		draw_rect(Rect2(corner, Vector2(crate, crate)), INK, false, 2.0)
		_draw_dots(Rect2(corner, Vector2(crate, crate)), each)
	var weight: Rect2 = Rect2(right_end + Vector2(-crate * 0.8, size.y * 0.17 - crate * 1.6), Vector2(crate * 1.6, crate * 1.6))
	draw_rect(weight, GOOD if balanced else Color(STEEL, 0.4))
	draw_rect(weight, INK, false, 2.0)


## `count` small dots inside a crate, so the number of gems in each can be counted.
func _draw_dots(box: Rect2, count: int) -> void:
	var columns: int = mini(count, 5)
	var rows: int = ceili(float(count) / 5.0)
	var step: Vector2 = Vector2(box.size.x / float(columns + 1), box.size.y / float(rows + 1))
	for index: int in count:
		var spot: Vector2 = box.position + Vector2(step.x * float(index % 5 + 1), step.y * float(floori(index / 5.0) + 1))
		draw_circle(spot, minf(step.x, step.y) * 0.3, INK)
