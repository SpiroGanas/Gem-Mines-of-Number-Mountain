## Code-drawn art for Zone 8, Power Tower (no artist; Spiro's decision): the power tower (a ground floor
## of 1 and a floor for each multiplication), the big cube of blocks, the vault lamps, dials and digit
## columns of numbers in other bases, the counterweight lever and the elevator cab. Static painters that
## draw on any CanvasItem inside a Rect2, so the problem picture (VisualModel), the vault lock, the tower
## elevator and the counterweight all look the same.
##
## Light is electric only (CLAUDE.md content rules): lit lamps are bulbs with a soft glow and a filament
## mark, never a flame. A lit lamp also carries its 1 and an unlit one its 0, so color is never the only
## clue (accessibility rule). The picture fields are documented in scripts/core/problem.gd.
class_name PowerArt
extends RefCounted

const INK: Color = Color("#1F2945")
const LINE: Color = Color("#F5F7FF")
const STEEL: Color = Color("#8A96B3")
const FLOOR: Color = Color("#4A5A82")
const FLOOR_TOP: Color = Color("#6C7FB0")
const GROUND: Color = Color("#7BD88F")
const LAMP_ON: Color = Color("#FFE27A")
const LAMP_OFF: Color = Color("#3B4A6B")
const GLOW: Color = Color(1.0, 0.89, 0.48, 0.28)
const DIAL: Color = Color("#2C3A5E")
const CRYSTAL: Color = Color("#8FE3FF")
const WEIGHT: Color = Color("#B8C2D9")
const MARK: Color = Color("#FFD166")
const LABEL_SIZE: int = 28
const SMALL_SIZE: int = 22
## How far the lever beam leans when one side is heavier (radians).
const LEVER_TILT: float = 0.16


## Draws any Zone 8 picture inside `rect` (not `notation`: VisualModel shows that with MathNotation).
## Returns false for a picture type it does not know.
static func draw_visual(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> bool:
	match str(visual.get("type", "")):
		"power_tower":
			draw_tower(canvas, rect, int(visual.get("base", 2)), int(visual.get("exp", 0)), bool(visual.get("values", false)), font)
		"cube_blocks":
			draw_cube(canvas, rect, int(visual.get("n", 2)))
		"lamps":
			draw_lamps(canvas, rect, visual, font)
		"lever":
			var left: Dictionary = visual.get("left", {})
			var right: Dictionary = visual.get("right", {})
			draw_lever(canvas, rect, int(left.get("w", 0)), int(left.get("d", 1)), int(right.get("w", 0)), int(right.get("d", 1)),
				tilt_angle(str(visual.get("tilt", "unknown"))), bool(visual.get("products", false)), font)
		_:
			return false
	return true


# --- The power tower ---------------------------------------------------------------------------


## The rectangles of a tower's floors, ground (index 0) at the bottom: `floors` + 1 boxes stacked inside
## `rect`, each narrower than the one below. Pure geometry, so tests can check it fits.
static func tower_floors(rect: Rect2, floors: int) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	var count: int = floors + 1
	var height: float = minf(rect.size.y / float(count), rect.size.y * 0.3)
	var widest: float = minf(rect.size.x * 0.6, height * 6.0)
	for index: int in count:
		var width: float = widest * (1.0 - 0.04 * float(index))
		var top: float = rect.end.y - height * float(index + 1)
		boxes.append(Rect2(rect.get_center().x - width * 0.5, top, width, height * 0.9))
	return boxes


## The tower: a green ground floor marked 1, then `exp` floors each marked "× base"; with `values`,
## each floor's height (base, base², ...) is written beside it.
static func draw_tower(canvas: CanvasItem, rect: Rect2, base: int, exp: int, values: bool, font: Font) -> void:
	var boxes: Array[Rect2] = tower_floors(rect, clampi(exp, 0, 10))
	var height: int = 1
	for index: int in boxes.size():
		var box: Rect2 = boxes[index]
		canvas.draw_rect(box, GROUND.darkened(0.35) if index == 0 else FLOOR)
		canvas.draw_rect(Rect2(box.position, Vector2(box.size.x, box.size.y * 0.18)), GROUND if index == 0 else FLOOR_TOP)
		canvas.draw_rect(box, INK, false, 2.0)
		# A lit window (an electric lamp) on every floor.
		canvas.draw_circle(Vector2(box.position.x + box.size.y * 0.5, box.get_center().y), box.size.y * 0.18, LAMP_ON)
		var size: int = clampi(roundi(box.size.y * 0.55), 12, LABEL_SIZE)
		var mark: String = "1" if index == 0 else "× " + str(base)
		_text(canvas, font, box, mark, size, LINE)
		if index > 0:
			height *= base
		if values:
			var beside: Rect2 = Rect2(Vector2(box.end.x + 8.0, box.position.y), Vector2(rect.end.x - box.end.x - 8.0, box.size.y))
			if beside.size.x > 24.0:
				_text(canvas, font, beside, "= " + Text.display_value(height), size, MARK, HORIZONTAL_ALIGNMENT_LEFT)


## Bolt's elevator cab (the tower elevator and the counterweight elevator): a box with a window and a
## headlamp glow.
static func draw_cab(canvas: CanvasItem, center: Vector2, side: float) -> void:
	var box: Rect2 = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	canvas.draw_rect(box, MARK)
	canvas.draw_rect(box, INK, false, 2.0)
	canvas.draw_rect(Rect2(box.position + box.size * Vector2(0.2, 0.2), box.size * Vector2(0.6, 0.35)), CRYSTAL)
	canvas.draw_circle(box.get_center() + Vector2(0, side * 0.25), side * 0.08, LAMP_ON)


# --- Cubes ---------------------------------------------------------------------------------------


## A big cube of n blocks on each edge, drawn in three faces (front, top, side) with the block lines,
## so a child can count n along each edge.
static func draw_cube(canvas: CanvasItem, rect: Rect2, n: int) -> void:
	var count: int = clampi(n, 1, 8)
	var side: float = minf(rect.size.x, rect.size.y) * 0.62
	var depth: Vector2 = Vector2(side * 0.45, -side * 0.35)
	var front: Rect2 = Rect2(rect.get_center() - Vector2(side + depth.x, side - depth.y) * 0.5 + Vector2(0, -depth.y * 0.2), Vector2(side, side))
	var step: float = side / float(count)
	var top: PackedVector2Array = PackedVector2Array([front.position, front.position + depth, front.position + depth + Vector2(side, 0), front.position + Vector2(side, 0)])
	var right: PackedVector2Array = PackedVector2Array([front.position + Vector2(side, 0), front.position + Vector2(side, 0) + depth, front.end + depth, front.end])
	canvas.draw_rect(front, FLOOR)
	canvas.draw_colored_polygon(top, FLOOR_TOP)
	canvas.draw_colored_polygon(right, FLOOR.darkened(0.25))
	for index: int in range(1, count):
		var offset: float = step * float(index)
		var share: float = float(index) / float(count)
		canvas.draw_line(front.position + Vector2(offset, 0), front.position + Vector2(offset, side), INK, 1.5)
		canvas.draw_line(front.position + Vector2(0, offset), front.position + Vector2(side, offset), INK, 1.5)
		canvas.draw_line(front.position + Vector2(offset, 0), front.position + Vector2(offset, 0) + depth, INK, 1.5)
		canvas.draw_line(front.position + depth * share, front.position + depth * share + Vector2(side, 0), INK, 1.5)
		canvas.draw_line(front.position + Vector2(side, offset), front.position + Vector2(side, offset) + depth, INK, 1.5)
		canvas.draw_line(front.position + Vector2(side, 0) + depth * share, front.end + depth * share, INK, 1.5)
	canvas.draw_rect(front, INK, false, 2.5)
	canvas.draw_polyline(PackedVector2Array([top[0], top[1], top[2], right[2], right[3]]), INK, 2.5)
	canvas.draw_line(top[3], top[2], INK, 2.5)


# --- Lamps, dials and digit columns ------------------------------------------------------------


## The worth of each of `places` places in `base`, left (biggest) to right (1).
static func place_values(base: int, places: int) -> Array[int]:
	var values: Array[int] = []
	var worth: int = 1
	for index: int in places:
		values.push_front(worth)
		worth *= base
	return values


## The cells of `places` places across `rect`, left to right, each a square at most `rect` high.
static func place_cells(rect: Rect2, places: int) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var gap: float = 10.0
	var side: float = minf((rect.size.x - gap * float(places - 1)) / float(maxi(places, 1)), rect.size.y)
	var total: float = side * float(places) + gap * float(places - 1)
	var left: float = rect.get_center().x - total * 0.5
	for index: int in places:
		cells.append(Rect2(left + float(index) * (side + gap), rect.position.y + (rect.size.y - side) * 0.5, side, side))
	return cells


## One to three numbers in a base, right-aligned in their places: lit and unlit lamps, dials showing a
## digit, or digit columns; each place's worth under the last row when show_places is set, and a "+"
## and a line above the sum when `plus` is set (binary addition).
static func draw_lamps(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var base: int = int(visual.get("base", 2))
	var places: int = clampi(int(visual.get("places", 1)), 1, 8)
	var rows: Array = visual.get("rows", [])
	var style: String = str(visual.get("style", "lamps"))
	var bands: int = rows.size() + (1 if bool(visual.get("show_places", false)) else 0)
	if bands == 0:
		return
	var band: float = rect.size.y / float(bands)
	var inner: Rect2 = Rect2(rect.position + Vector2(rect.size.x * 0.08, 0), Vector2(rect.size.x * 0.84, rect.size.y))
	for row_index: int in rows.size():
		var digits: Array = rows[row_index]
		var row_rect: Rect2 = Rect2(Vector2(inner.position.x, rect.position.y + band * row_index), Vector2(inner.size.x, band * 0.9))
		var cells: Array[Rect2] = place_cells(row_rect, places)
		for index: int in places:
			var at: int = index - (places - digits.size())
			var digit: int = int(digits[at]) if at >= 0 else -1
			draw_place(canvas, cells[index], style, digit, font)
		if bool(visual.get("plus", false)) and row_index == 1:
			_text(canvas, font, Rect2(Vector2(rect.position.x, row_rect.position.y), Vector2(inner.position.x - rect.position.x, row_rect.size.y)), "+", LABEL_SIZE, LINE)
		if bool(visual.get("plus", false)) and row_index == 2:
			canvas.draw_line(Vector2(inner.position.x, row_rect.position.y - 4.0), Vector2(inner.end.x, row_rect.position.y - 4.0), LINE, 3.0)
	if bool(visual.get("show_places", false)):
		var label_rect: Rect2 = Rect2(Vector2(inner.position.x, rect.position.y + band * rows.size()), Vector2(inner.size.x, band))
		var cells: Array[Rect2] = place_cells(Rect2(label_rect.position, Vector2(label_rect.size.x, minf(label_rect.size.y, rect.size.y))), places)
		var worths: Array[int] = place_values(base, places)
		for index: int in places:
			var cell: Rect2 = Rect2(Vector2(cells[index].position.x, label_rect.position.y), Vector2(cells[index].size.x, label_rect.size.y))
			_text(canvas, font, cell, Text.display_value(worths[index]), clampi(roundi(cell.size.x * 0.32), 10, SMALL_SIZE), MARK)


## One place: a lamp (lit for 1, with "1" or "0" on it), a dial (its digit, with tick marks for the
## base's positions) or a digit column. `digit` -1 is an empty place (left of the number). `text` is the
## digit's text when the caller already has it (an animated picture draws without making strings).
static func draw_place(canvas: CanvasItem, cell: Rect2, style: String, digit: int, font: Font, text: String = "") -> void:
	var shown: String = text if not text.is_empty() else str(digit)
	var center: Vector2 = cell.get_center()
	var radius: float = minf(cell.size.x, cell.size.y) * 0.42
	var size: int = clampi(roundi(radius * 0.9), 10, LABEL_SIZE + 8)
	match style:
		"lamps":
			var lit: bool = digit == 1
			if lit:
				canvas.draw_circle(center, radius * 1.25, GLOW)
			canvas.draw_circle(center, radius, LAMP_ON if lit else LAMP_OFF)
			canvas.draw_arc(center, radius, 0.0, TAU, 32, INK, 2.0)
			if digit >= 0:
				_text(canvas, font, cell, "1" if lit else "0", size, INK if lit else LINE)
		"dials":
			canvas.draw_circle(center, radius, DIAL)
			canvas.draw_arc(center, radius, 0.0, TAU, 32, CRYSTAL, 3.0)
			if digit >= 0:
				_text(canvas, font, cell, shown, size, LINE)
		_:
			canvas.draw_rect(cell.grow(-2.0), Color(1, 1, 1, 0.08))
			canvas.draw_rect(cell.grow(-2.0), Color(1, 1, 1, 0.35), false, 2.0)
			if digit >= 0:
				_text(canvas, font, cell, shown, size, LINE)


# --- The counterweight lever -------------------------------------------------------------------


## The beam's lean for a tilt name: the heavier side goes down.
static func tilt_angle(tilt: String) -> float:
	match tilt:
		"left":
			return -LEVER_TILT
		"right":
			return LEVER_TILT
	return 0.0


## Where hook `distance` (1 to 8 steps from the middle) is on a beam of half-length `half` around
## `pivot`, leaning `angle`; negative distances are on the left.
static func hook_point(pivot: Vector2, half: float, distance: int, angle: float) -> Vector2:
	return pivot + Vector2(cos(angle), sin(angle)) * (half * float(distance) / 8.0)


## The lever: a triangle pivot, a beam with eight hook marks a side, and a weight on each side (a box
## with its weight; 0 is an empty hook with "?"). With `products` the weight × distance is written
## under each loaded side.
static func draw_lever(canvas: CanvasItem, rect: Rect2, left_w: int, left_d: int, right_w: int, right_d: int, angle: float, products: bool, font: Font) -> void:
	var pivot: Vector2 = Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.42)
	var half: float = rect.size.x * 0.44
	var base_y: float = rect.position.y + rect.size.y * 0.62
	canvas.draw_colored_polygon(PackedVector2Array([pivot, Vector2(pivot.x - 22.0, base_y), Vector2(pivot.x + 22.0, base_y)]), STEEL)
	var left_end: Vector2 = hook_point(pivot, half, -8, angle)
	var right_end: Vector2 = hook_point(pivot, half, 8, angle)
	canvas.draw_line(left_end, right_end, LINE, 8.0)
	for step: int in range(1, 9):
		for sign: int in [-1, 1]:
			var at: Vector2 = hook_point(pivot, half, step * sign, angle)
			canvas.draw_line(at, at + Vector2(0, 10.0), LINE, 2.0)
	var box: float = clampf(rect.size.y * 0.26, 24.0, 72.0)
	_draw_weight(canvas, hook_point(pivot, half, -left_d, angle), box, left_w, font)
	_draw_weight(canvas, hook_point(pivot, half, right_d, angle), box, right_w, font)
	if products:
		var under: float = rect.end.y - LABEL_SIZE
		if left_w > 0:
			_text(canvas, font, Rect2(Vector2(rect.position.x, under), Vector2(rect.size.x * 0.5, LABEL_SIZE)), "%d × %d = %d" % [left_w, left_d, left_w * left_d], SMALL_SIZE, MARK)
		if right_w > 0:
			_text(canvas, font, Rect2(Vector2(rect.get_center().x, under), Vector2(rect.size.x * 0.5, LABEL_SIZE)), "%d × %d = %d" % [right_w, right_d, right_w * right_d], SMALL_SIZE, MARK)


static func _draw_weight(canvas: CanvasItem, hook: Vector2, side: float, weight: int, font: Font) -> void:
	canvas.draw_line(hook, hook + Vector2(0, side * 0.5), LINE, 2.0)
	var box: Rect2 = Rect2(hook + Vector2(-side * 0.5, side * 0.5), Vector2(side, side))
	if weight <= 0:
		canvas.draw_rect(box, LINE, false, 2.0)
		_text(canvas, font, box, "?", clampi(roundi(side * 0.5), 12, LABEL_SIZE), LINE)
		return
	canvas.draw_rect(box, WEIGHT)
	canvas.draw_rect(box, INK, false, 2.0)
	_text(canvas, font, box, str(weight), clampi(roundi(side * 0.5), 12, LABEL_SIZE), INK)


# --- Text --------------------------------------------------------------------------------------


static func _text(canvas: CanvasItem, font: Font, box: Rect2, text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if font == null or text.is_empty():
		return
	var baseline: float = box.get_center().y + font.get_ascent(size) * 0.35
	canvas.draw_string(font, Vector2(box.position.x, baseline), text, align, box.size.x, size, color)
