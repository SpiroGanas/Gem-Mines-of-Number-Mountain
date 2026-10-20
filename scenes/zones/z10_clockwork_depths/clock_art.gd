## Code-drawn art for Zone 10, Clockwork Depths (no artist; Spiro's decision): a loop of stations with a cart on it
## (`clock_track`) and the mixing table of a clock number system (`cayley`). Static painters that draw on any
## CanvasItem inside a Rect2, so the problem picture (VisualModel), the circular track, the clock lock and the mixing
## table all look the same.
##
## The cart and the stop always differ by shape as well as color (a square cart, a round ring on the stop, a
## triangle for a second cart), so color is never the only clue (accessibility rule). Lights are electric, never a
## flame. The picture fields are documented in scripts/core/problem.gd. The geometry (station_point, loop_radius,
## cell_rect, orbit_stations) is pure and tested; the painters only paint it.
class_name ClockArt
extends RefCounted

const OUTLINE: Color = Color("#1F2945")
const TRACK: Color = Color("#C9D1E8")
const STATION: Color = Color("#F5F7FF")
const CART: Color = Color("#FFD166")
const STOP: Color = Color("#7BD88F")
const SECOND: Color = Color("#7FC8F8")
const HOP: Color = Color("#7BD88F")
const DIM: Color = Color(1, 1, 1, 0.25)
const BLANK: Color = Color(1, 1, 1, 0.12)
const HEADER: Color = Color(1, 1, 1, 0.1)
const LIT: Color = Color(1.0, 0.82, 0.4, 0.22)
const OUTSIDE: Color = Color("#FF8A80")
const SIGN_SIZE: int = 40


## Draws a Zone 10 picture inside `rect`. Returns false for a picture type it does not know.
static func draw_visual(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> bool:
	match str(visual.get("type", "")):
		"clock_track":
			draw_track(canvas, rect, visual, font)
		"cayley":
			draw_table(canvas, rect, visual, font)
		_:
			return false
	return true


# --- The loop ------------------------------------------------------------------------------------


## The radius of the loop of stations that fits `rect`: leaves room for the station discs.
static func loop_radius(rect: Rect2, n: int) -> float:
	var side: float = minf(rect.size.x, rect.size.y)
	return maxf(side * 0.5 - station_radius(side * 0.5, n) - 4.0, 8.0)


## The radius of a station disc on a loop of `radius` (shrinks as the loop gets crowded).
static func station_radius(radius: float, n: int) -> float:
	return clampf(minf(radius * 0.22, TAU * radius / (float(n) * 2.6)), 8.0, 30.0)


## Where station `index` of a loop of n stations sits: station 0 at the top, the rest clockwise.
static func station_point(center: Vector2, radius: float, n: int, index: int) -> Vector2:
	var angle: float = -PI / 2.0 + TAU * float(index) / float(n)
	return center + Vector2(cos(angle), sin(angle)) * radius


## Where a (fractional) place on the loop sits: place 3.5 is half way between stations 3 and 4.
static func place_point(center: Vector2, radius: float, n: int, place: float) -> Vector2:
	var angle: float = -PI / 2.0 + TAU * place / float(n)
	return center + Vector2(cos(angle), sin(angle)) * radius


## The stations an `orbit` picture visits, in order: 0, then every `step` stops, until it is back at 0 (the
## last entry is the first one again).
static func orbit_stations(n: int, step: int) -> Array[int]:
	var visited: Array[int] = [0]
	var at: int = posmod(step, n)
	while at != 0 and visited.size() <= n:
		visited.append(at)
		at = posmod(at + step, n)
	visited.append(0)
	return visited


static func draw_track(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var n: int = int(visual.get("n", 2))
	var start: int = int(visual.get("start", 0))
	var steps: int = int(visual.get("steps", 0))
	var direction: int = int(visual.get("direction", 1))
	var center: Vector2 = rect.get_center()
	var radius: float = loop_radius(rect, n)
	var disc: float = station_radius(radius + 1.0, n)
	canvas.draw_arc(center, radius, 0.0, TAU, 64, TRACK, 3.0)
	if bool(visual.get("orbit", false)):
		var visited: Array[int] = orbit_stations(n, steps)
		for index: int in range(1, visited.size()):
			canvas.draw_line(station_point(center, radius, n, visited[index - 1]), station_point(center, radius, n, visited[index]), HOP, 4.0)
	var stop: int = posmod(start + direction * steps, n)
	var second_stop: int = -1
	if visual.has("also"):
		second_stop = posmod(int(visual["also"]), n)
	if bool(visual.get("show_stop", false)) and not bool(visual.get("orbit", false)):
		_draw_ride_arc(canvas, center, radius * 0.72, n, start, steps, direction)
	for index: int in n:
		var at: Vector2 = station_point(center, radius, n, index)
		var visiting: bool = bool(visual.get("orbit", false)) and orbit_stations(n, steps).has(index)
		canvas.draw_circle(at, disc, STATION if not visiting else HOP)
		canvas.draw_arc(at, disc, 0.0, TAU, 24, OUTLINE, 2.0)
		_draw_centered(canvas, font, str(index), at, maxi(roundi(disc * 1.15), 10), OUTLINE)
	# The cart waits on its start station (or, while it rides, at the place `cart` in stops from station 0).
	var cart_at: Vector2 = place_point(center, radius, n, float(visual["cart"])) if visual.has("cart") else station_point(center, radius, n, start)
	_draw_cart(canvas, cart_at, disc, CART)
	if visual.has("also"):
		_draw_second_cart(canvas, station_point(center, radius, n, 0), disc)
	if bool(visual.get("show_stop", false)):
		canvas.draw_arc(station_point(center, radius, n, stop), disc + 6.0, 0.0, TAU, 32, STOP, 5.0)
		if second_stop >= 0:
			canvas.draw_arc(station_point(center, radius, n, second_stop), disc + 11.0, 0.0, TAU, 32, SECOND, 4.0)
	if not bool(visual.get("orbit", false)):
		var sign_text: String = ("+%d" if direction > 0 else "−%d") % steps
		_draw_centered(canvas, font, sign_text, center, SIGN_SIZE, CART)
		if visual.has("also"):
			_draw_centered(canvas, font, "+%d" % int(visual["also"]), center + Vector2(0.0, SIGN_SIZE * 1.1), SIGN_SIZE, SECOND)


## A dial: the loop of marks with a pointer from the middle to `pointer` (a fractional mark while it swings).
static func draw_dial(canvas: CanvasItem, rect: Rect2, n: int, pointer: float, font: Font) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = loop_radius(rect, n)
	var disc: float = station_radius(radius + 1.0, n)
	canvas.draw_arc(center, radius, 0.0, TAU, 64, TRACK, 3.0)
	for index: int in n:
		var at: Vector2 = station_point(center, radius, n, index)
		canvas.draw_circle(at, disc, STATION)
		canvas.draw_arc(at, disc, 0.0, TAU, 24, OUTLINE, 2.0)
		_draw_centered(canvas, font, str(index), at, maxi(roundi(disc * 1.15), 10), OUTLINE)
	var tip: Vector2 = place_point(center, radius - disc * 1.3, n, pointer)
	canvas.draw_line(center, tip, CART, 5.0, true)
	canvas.draw_circle(tip, disc * 0.6, CART)
	canvas.draw_circle(center, 7.0, CART)


static func _draw_ride_arc(canvas: CanvasItem, center: Vector2, radius: float, n: int, start: int, steps: int, direction: int) -> void:
	var from_angle: float = -PI / 2.0 + TAU * float(start) / float(n)
	var sweep: float = TAU * float(posmod(steps, n)) / float(n)
	if sweep == 0.0 and steps > 0:
		sweep = TAU
	if sweep == 0.0:
		return
	var to_angle: float = from_angle + direction * sweep
	canvas.draw_arc(center, radius, minf(from_angle, to_angle), maxf(from_angle, to_angle), 48, HOP, 4.0)
	var tip: Vector2 = center + Vector2(cos(to_angle), sin(to_angle)) * radius
	var tangent: Vector2 = Vector2(-sin(to_angle), cos(to_angle)) * direction
	var normal: Vector2 = Vector2(cos(to_angle), sin(to_angle))
	canvas.draw_colored_polygon(PackedVector2Array([tip + tangent * 12.0, tip - tangent * 4.0 + normal * 9.0, tip - tangent * 4.0 - normal * 9.0]), HOP)


static func _draw_cart(canvas: CanvasItem, at: Vector2, disc: float, color: Color) -> void:
	var half: float = disc * 1.2
	canvas.draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), color, false, 4.0)
	canvas.draw_circle(at + Vector2(-half * 0.55, half), half * 0.22, color)
	canvas.draw_circle(at + Vector2(half * 0.55, half), half * 0.22, color)


static func _draw_second_cart(canvas: CanvasItem, at: Vector2, disc: float) -> void:
	var half: float = disc * 1.35
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -half), at + Vector2(half, half * 0.8), at + Vector2(-half, half * 0.8)]), Color(SECOND, 0.35))
	canvas.draw_polyline(PackedVector2Array([at + Vector2(0.0, -half), at + Vector2(half, half * 0.8), at + Vector2(-half, half * 0.8), at + Vector2(0.0, -half)]), SECOND, 3.0)


static func _draw_centered(canvas: CanvasItem, font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, Vector2(at.x - text_size.x / 2.0, at.y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- The mixing table ----------------------------------------------------------------------------


## The square cell at (row, col) of an n by n table with a header row and column, centered in `rect`. Row and
## column -1 are the headers; (-1, -1) is the corner that shows + or ×.
static func cell_rect(rect: Rect2, n: int, row: int, col: int) -> Rect2:
	var side: float = floorf(minf(rect.size.x, rect.size.y) / float(n + 1))
	var origin: Vector2 = rect.get_center() - Vector2(side, side) * float(n + 1) / 2.0
	return Rect2(origin + Vector2(float(col + 1), float(row + 1)) * side, Vector2(side, side))


static func draw_table(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var n: int = int(visual.get("n", 2))
	var op: StringName = StringName(str(visual.get("op", "add")))
	var wrap: bool = bool(visual.get("wrap", true))
	var blank: Array = visual.get("blank", [])
	var ring: Array = visual.get("ring", [])
	var lit_value: int = GroupGenerator.identity_of(op) if str(visual.get("focus", "")) == "identity" else -1
	var lit_row: int = int(visual.get("row", -1))
	var side: float = cell_rect(rect, n, 0, 0).size.x
	var font_size: int = maxi(roundi(side * 0.5), 8)
	canvas.draw_rect(Rect2(cell_rect(rect, n, -1, -1).position, Vector2(side, side) * float(n + 1)), OUTLINE, false, 2.0)
	_draw_centered(canvas, font, "+" if op == &"add" else "×", cell_rect(rect, n, -1, -1).get_center(), font_size, CART)
	for index: int in n:
		for header: Rect2 in [cell_rect(rect, n, -1, index), cell_rect(rect, n, index, -1)]:
			canvas.draw_rect(header, HEADER, true)
			_draw_centered(canvas, font, str(index), header.get_center(), font_size, STATION)
	for row: int in n:
		for col: int in n:
			var box: Rect2 = cell_rect(rect, n, row, col)
			var raw: int = GroupGenerator.mix(row, col, op)
			var value: int = posmod(raw, n) if wrap else raw
			var lit: bool = (lit_value >= 0 and (row == lit_value or col == lit_value)) or row == lit_row
			canvas.draw_rect(box, LIT if lit else BLANK, true)
			canvas.draw_rect(box, DIM, false, 1.0)
			if blank == [row, col]:
				_draw_centered(canvas, font, "?", box.get_center(), font_size, CART)
			else:
				var outside: bool = value >= n
				_draw_centered(canvas, font, str(value), box.get_center(), font_size, OUTSIDE if outside else STATION)
				if outside: # a corner mark as well as the color: this answer falls off the loop
					canvas.draw_colored_polygon(PackedVector2Array([box.position + Vector2(box.size.x, 0.0), box.position + Vector2(box.size.x - side * 0.3, 0.0), box.position + Vector2(box.size.x, side * 0.3)]), OUTSIDE)
			if ring == [row, col]:
				canvas.draw_rect(box.grow(-1.0), CART, false, 4.0)
