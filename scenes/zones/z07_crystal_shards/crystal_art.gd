## Code-drawn art for Zone 7, Crystal Shards (no artist; Spiro's decision): the round crystal cut into
## wedge shards, the bar, the fraction number line, the ten-strip and the 10 by 10 crystal grid, the
## depth gauge and the copper and tin ore. Static painters that draw on any CanvasItem inside a Rect2,
## so the problem picture (VisualModel), the crystal the child taps, the gauge and the alloy mixer
## all look the same.
##
## Lit shards glow with electric crystal light (CLAUDE.md content rules: no flame anywhere), and a lit
## shard also carries a small gem mark, a second color's shard a small square, so color is never the
## only clue (accessibility rule). The picture fields are documented in scripts/core/problem.gd.
class_name CrystalArt
extends RefCounted

const OUTLINE: Color = Color("#1F2945")
const DARK_SHARD: Color = Color("#3B4A6B")
const LIT_SHARD: Color = Color("#8FE3FF")
const SECOND_SHARD: Color = Color("#C9A6FF")
const GLOW: Color = Color(0.56, 0.89, 1.0, 0.22)
const FACET: Color = Color(1, 1, 1, 0.18)
const LINE: Color = Color("#F5F7FF")
const MARKER: Color = Color("#FFD166")
const COPPER: Color = Color("#D9814A")
const TIN: Color = Color("#B8C2D9")
const CAB: Color = Color("#FFD166")
const GROUND: Color = Color("#7BD88F")
const LABEL_SIZE: int = 26
const GAP: float = 24.0


## Draws any Zone 7 picture inside `rect`. Returns false for a picture type it does not know.
static func draw_visual(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> bool:
	match str(visual.get("type", "")):
		"crystals":
			draw_crystals(canvas, rect, visual, font)
		"fraction_line":
			draw_fraction_line(canvas, rect, visual, font)
		"crystal_grid":
			draw_grids(canvas, rect, visual, font)
		"depth_gauge":
			draw_gauge(canvas, rect, visual, font)
		"ore_mix":
			draw_ore_mix(canvas, rect, visual)
		_:
			return false
	return true


# --- Crystals and bars -------------------------------------------------------------------------


## Whole crystals first (small, fully lit), then each crystal or bar side by side, with "+" or a
## balance-bar mark between two of them.
static func draw_crystals(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var entries: Array = visual.get("crystals", [])
	var wholes: int = int(visual.get("wholes", 0))
	var bar: bool = str(visual.get("shape", "crystal")) == "bar"
	var slots: int = entries.size() + (1 if wholes > 0 else 0)
	if slots == 0:
		return
	var width: float = (rect.size.x - GAP * float(slots - 1)) / float(slots)
	var x: float = rect.position.x
	if wholes > 0:
		var box: Rect2 = Rect2(x, rect.position.y, width, rect.size.y)
		draw_wholes(canvas, box, wholes, int(entries[0].get("den", 1)) if not entries.is_empty() else 1, bar)
		x += width + GAP
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var box: Rect2 = Rect2(x, rect.position.y, width, rect.size.y)
		var lit: Array[bool] = []
		var second: Array[bool] = []
		var den: int = maxi(int(entry.get("den", 1)), 1)
		for shard: int in den:
			lit.append(shard < int(entry.get("lit", 0)))
			second.append(shard >= int(entry.get("lit", 0)) and shard < int(entry.get("lit", 0)) + int(entry.get("second", 0)))
		if bar:
			draw_bar(canvas, _bar_rect(box), den, lit, second)
		else:
			var radius: float = minf(box.size.x, box.size.y) * 0.42
			draw_crystal(canvas, box.get_center(), radius, den, lit, second)
		if index == 0 and entries.size() == 2:
			var mid: Vector2 = Vector2(x + width + GAP * 0.5, rect.get_center().y)
			_draw_joiner(canvas, mid, str(visual.get("joiner", "")), font)
		x += width + GAP


## One round crystal of `den` wedge shards around `center`.
static func draw_crystal(canvas: CanvasItem, center: Vector2, radius: float, den: int, lit: Array[bool], second: Array[bool] = []) -> void:
	canvas.draw_circle(center, radius * 1.12, GLOW)
	var outlines: Array = CrystalShards.wedges(den)
	for index: int in den:
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in outlines[index]:
			points.append(center + point * radius)
		var on: bool = index < lit.size() and lit[index]
		var other: bool = index < second.size() and second[index]
		var fill: Color = LIT_SHARD if on else (SECOND_SHARD if other else DARK_SHARD)
		canvas.draw_colored_polygon(points, fill)
		var edge: PackedVector2Array = points.duplicate()
		edge.append(points[0])
		canvas.draw_polyline(edge, OUTLINE, 3.0, true)
		var middle: Vector2 = center + Vector2.from_angle(CrystalShards.start_angle(index, den) + PI / float(den)) * radius * 0.62
		if on:
			_draw_gem_mark(canvas, middle, radius * 0.09)
		elif other:
			_draw_square_mark(canvas, middle, radius * 0.08)
	# A facet highlight on the top left, so it reads as a crystal, not a pie.
	canvas.draw_circle(center + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.12, FACET)


## One bar of `den` equal strips, left to right.
static func draw_bar(canvas: CanvasItem, box: Rect2, den: int, lit: Array[bool], second: Array[bool] = []) -> void:
	var strip: float = box.size.x / float(maxi(den, 1))
	for index: int in den:
		var cell: Rect2 = Rect2(box.position.x + strip * index, box.position.y, strip, box.size.y)
		var on: bool = index < lit.size() and lit[index]
		var other: bool = index < second.size() and second[index]
		canvas.draw_rect(cell, LIT_SHARD if on else (SECOND_SHARD if other else DARK_SHARD))
		canvas.draw_rect(cell, OUTLINE, false, 3.0)
		if on:
			_draw_gem_mark(canvas, cell.get_center(), minf(strip, box.size.y) * 0.18)
		elif other:
			_draw_square_mark(canvas, cell.get_center(), minf(strip, box.size.y) * 0.15)


## `count` whole crystals (or bars), all lit, in a small row or grid.
static func draw_wholes(canvas: CanvasItem, box: Rect2, count: int, den: int, bar: bool) -> void:
	var columns: int = mini(count, 3)
	var rows: int = ceili(count / 3.0)
	var cell: Vector2 = Vector2(box.size.x / float(columns), box.size.y / float(rows))
	var all_lit: Array[bool] = []
	for index: int in den:
		all_lit.append(true)
	for index: int in count:
		var spot: Rect2 = Rect2(box.position + Vector2(cell.x * (index % columns), cell.y * floori(index / 3.0)), cell)
		if bar:
			draw_bar(canvas, _bar_rect(spot.grow(-6.0)), den, all_lit)
		else:
			draw_crystal(canvas, spot.get_center(), minf(cell.x, cell.y) * 0.4, den, all_lit)


static func _bar_rect(box: Rect2) -> Rect2:
	var height: float = minf(box.size.y * 0.5, box.size.x * 0.35)
	return Rect2(box.position.x, box.get_center().y - height * 0.5, box.size.x, height)


## "+" between two addends, a small balance beam between two to compare.
static func _draw_joiner(canvas: CanvasItem, at: Vector2, joiner: String, _font: Font) -> void:
	if joiner == "plus":
		canvas.draw_line(at + Vector2(-10, 0), at + Vector2(10, 0), LINE, 4.0)
		canvas.draw_line(at + Vector2(0, -10), at + Vector2(0, 10), LINE, 4.0)
	elif joiner == "versus":
		canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(-9, 8), at + Vector2(9, 8)]), LINE)


static func _draw_gem_mark(canvas: CanvasItem, at: Vector2, size: float) -> void:
	var s: float = maxf(size, 4.0)
	var gem: PackedVector2Array = PackedVector2Array([at + Vector2(0, -s), at + Vector2(s * 0.8, 0), at + Vector2(0, s), at + Vector2(-s * 0.8, 0)])
	canvas.draw_colored_polygon(gem, MARKER)
	var edge: PackedVector2Array = gem.duplicate()
	edge.append(gem[0])
	canvas.draw_polyline(edge, OUTLINE, 2.0)


static func _draw_square_mark(canvas: CanvasItem, at: Vector2, size: float) -> void:
	var s: float = maxf(size, 4.0)
	canvas.draw_rect(Rect2(at - Vector2(s, s), Vector2(s, s) * 2.0), Color("#5B3FA6"))


# --- The fraction number line ------------------------------------------------------------------


## A line from 0 to `wholes` with a tick at every 1/den, the whole numbers labeled, and a gem at the
## marker.
static func draw_fraction_line(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var den: int = maxi(int(visual.get("den", 1)), 1)
	var wholes: int = maxi(int(visual.get("wholes", 1)), 1)
	var margin: float = 40.0
	var y: float = rect.get_center().y
	var left: float = rect.position.x + margin
	var right: float = rect.end.x - margin
	canvas.draw_line(Vector2(left, y), Vector2(right, y), LINE, 4.0)
	var ticks: int = den * wholes
	for tick: int in ticks + 1:
		var x: float = lerpf(left, right, float(tick) / float(ticks))
		var big: bool = tick % den == 0
		canvas.draw_line(Vector2(x, y - (22.0 if big else 14.0)), Vector2(x, y + (22.0 if big else 14.0)), LINE, 4.0 if big else 3.0)
		if big and font != null:
			var text: String = str(floori(tick / float(den)))
			var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
			canvas.draw_string(font, Vector2(x - size.x * 0.5, y + 28.0 + LABEL_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LINE)
	var marker: Dictionary = visual.get("marker", {})
	if not marker.is_empty():
		var at: float = lerpf(left, right, float(int(marker["num"])) / float(ticks))
		var gem: Vector2 = Vector2(at, y - 44.0)
		_draw_gem_mark(canvas, gem, 14.0)
		canvas.draw_line(gem + Vector2(0, 14), Vector2(at, y - 6), MARKER, 3.0)


# --- Ten-strips and hundred grids --------------------------------------------------------------


## For each number: its whole grids (small, all lit) and then one strip of 10 or grid of 100 with
## `lit` cells lit, left to right and top to bottom.
static func draw_grids(canvas: CanvasItem, rect: Rect2, visual: Dictionary, _font: Font) -> void:
	var grids: Array = visual.get("grids", [])
	var cells: int = int(visual.get("cells", 100))
	if grids.is_empty():
		return
	var width: float = (rect.size.x - GAP * float(grids.size() - 1)) / float(grids.size())
	for index: int in grids.size():
		var entry: Dictionary = grids[index]
		var box: Rect2 = Rect2(rect.position.x + index * (width + GAP), rect.position.y, width, rect.size.y)
		var wholes: int = int(entry.get("wholes", 0))
		var parts: int = wholes + 1
		var part_width: float = (box.size.x - 12.0 * float(parts - 1)) / float(parts)
		for part: int in parts:
			var spot: Rect2 = Rect2(box.position.x + part * (part_width + 12.0), box.position.y, part_width, box.size.y)
			var lit: int = cells if part < wholes else int(entry.get("lit", 0))
			if cells == 10:
				draw_ten_strip(canvas, spot, lit)
			else:
				draw_hundred_grid(canvas, spot, lit)
		if index == 0 and grids.size() == 2:
			_draw_joiner(canvas, Vector2(box.end.x + GAP * 0.5, box.get_center().y), "versus", null)


static func draw_ten_strip(canvas: CanvasItem, box: Rect2, lit: int) -> void:
	var lit_flags: Array[bool] = []
	for index: int in 10:
		lit_flags.append(index < lit)
	draw_bar(canvas, _bar_rect(box), 10, lit_flags)


static func draw_hundred_grid(canvas: CanvasItem, box: Rect2, lit: int) -> void:
	var side: float = minf(box.size.x, box.size.y)
	var cell: float = side / 10.0
	var origin: Vector2 = box.get_center() - Vector2(side, side) * 0.5
	canvas.draw_rect(Rect2(origin, Vector2(side, side)), DARK_SHARD)
	for index: int in mini(lit, 100):
		var at: Vector2 = origin + Vector2(cell * (index % 10), cell * floori(index / 10.0))
		canvas.draw_rect(Rect2(at, Vector2(cell, cell)), LIT_SHARD)
	for line: int in 11:
		var width: float = 3.0 if line % 5 == 0 else 1.0
		canvas.draw_line(origin + Vector2(cell * line, 0), origin + Vector2(cell * line, side), OUTLINE, width)
		canvas.draw_line(origin + Vector2(0, cell * line), origin + Vector2(side, cell * line), OUTLINE, width)
	if lit > 0 and lit < 100: # the last lit cell carries the gem mark: color is not the only clue
		var last: Vector2 = origin + Vector2(cell * ((lit - 1) % 10) + cell * 0.5, cell * floori((lit - 1) / 10.0) + cell * 0.5)
		_draw_gem_mark(canvas, last, cell * 0.32)


# --- The depth gauge ---------------------------------------------------------------------------


## The vertical depth gauge: the mountain's base (0) as a green ground line, labels every
## `labeled_every`, small ticks every meter, a gem marker at each value, and an elevator trip as a
## curved arrow from `from` to `to`. `cab` (optional) draws the elevator cab at that level.
static func draw_gauge(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font, cab: Variant = null) -> void:
	var low: int = int(visual.get("min", -10))
	var high: int = int(visual.get("max", 10))
	var every: int = maxi(int(visual.get("labeled_every", 5)), 1)
	var x: float = rect.position.x + rect.size.x * 0.45
	var top: float = rect.position.y + 16.0
	var bottom: float = rect.end.y - 16.0
	canvas.draw_line(Vector2(x, top), Vector2(x, bottom), LINE, 5.0)
	for value: int in range(low, high + 1):
		var y: float = gauge_y(value, low, high, top, bottom)
		var labeled: bool = value % every == 0
		var half: float = 16.0 if labeled else 7.0
		canvas.draw_line(Vector2(x - half, y), Vector2(x + half, y), GROUND if value == 0 else LINE, 6.0 if value == 0 else (3.0 if labeled else 1.5))
		if labeled and font != null:
			var text: String = Text.display_value(value)
			var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
			canvas.draw_string(font, Vector2(x - 26.0 - size.x, y + LABEL_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, GROUND if value == 0 else LINE)
	# The mountain's base: rock above the line is the mountain, below is the deep mine.
	var base_y: float = gauge_y(0, low, high, top, bottom)
	canvas.draw_line(Vector2(rect.position.x + 8.0, base_y), Vector2(rect.end.x - 8.0, base_y), Color(GROUND, 0.45), 3.0)
	for marker: Variant in visual.get("markers", []):
		_draw_gem_mark(canvas, Vector2(x + 34.0, gauge_y(int(marker), low, high, top, bottom)), 12.0)
	for jump: Dictionary in visual.get("jumps", []):
		var from_y: float = gauge_y(int(jump["from"]), low, high, top, bottom)
		var to_y: float = gauge_y(int(jump["to"]), low, high, top, bottom)
		var bulge: float = 60.0
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in 13:
			var t: float = float(step) / 12.0
			points.append(Vector2(x + 34.0 + sin(t * PI) * bulge, lerpf(from_y, to_y, t)))
		canvas.draw_polyline(points, MARKER, 3.0, true)
		var tip: Vector2 = points[points.size() - 1]
		var direction: float = 1.0 if to_y > from_y else -1.0
		canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(10, -12 * direction), tip + Vector2(-8, -10 * direction)]), MARKER)
	if cab != null:
		draw_cab(canvas, Vector2(x, gauge_y(int(cab), low, high, top, bottom)))


## Bolt's elevator cab, centred on the gauge at `at`: a box with an electric lamp on top.
static func draw_cab(canvas: CanvasItem, at: Vector2) -> void:
	var cab: Rect2 = Rect2(at - Vector2(26, 18), Vector2(52, 36))
	canvas.draw_rect(cab, CAB)
	canvas.draw_rect(cab, OUTLINE, false, 3.0)
	canvas.draw_rect(Rect2(cab.position + Vector2(10, 8), Vector2(32, 16)), Color("#2B3A42"))
	canvas.draw_circle(at + Vector2(0, -24), 6.0, Color("#FFE9A8"))


## The y of `value` on a gauge from low (bottom) to high (top).
static func gauge_y(value: int, low: int, high: int, top: float, bottom: float) -> float:
	return lerpf(top, bottom, DepthRide.height_share(value, low, high))


# --- Copper and tin ore ------------------------------------------------------------------------


## a copper ores (round, orange) and b tin ores (square, silver), in `groups` equal mixes each ringed.
static func draw_ore_mix(canvas: CanvasItem, rect: Rect2, visual: Dictionary) -> void:
	var a: int = int(visual.get("a", 0))
	var b: int = int(visual.get("b", 0))
	var groups: int = maxi(int(visual.get("groups", 1)), 1)
	var per_a: int = floori(a / float(groups))
	var per_b: int = floori(b / float(groups))
	var width: float = (rect.size.x - 16.0 * float(groups - 1)) / float(groups)
	var lumps: int = maxi(per_a + per_b, 1)
	var columns: int = mini(lumps, 4 if groups > 1 else 8)
	var rows: int = ceili(lumps / float(columns))
	var side: float = minf(width / float(columns), rect.size.y / float(rows)) * 0.8
	for group: int in groups:
		var box: Rect2 = Rect2(rect.position.x + group * (width + 16.0), rect.position.y, width, rect.size.y)
		var origin: Vector2 = box.get_center() - Vector2(columns * side, rows * side) / 0.8 * 0.5
		for index: int in per_a + per_b:
			var spot: Vector2 = origin + Vector2((index % columns) + 0.5, floori(index / float(columns)) + 0.5) * side / 0.8
			if index < per_a:
				canvas.draw_circle(spot, side * 0.45, COPPER)
				canvas.draw_arc(spot, side * 0.45, 0.0, TAU, 16, OUTLINE, 2.0)
			else:
				var lump: Rect2 = Rect2(spot - Vector2(side, side) * 0.42, Vector2(side, side) * 0.84)
				canvas.draw_rect(lump, TIN)
				canvas.draw_rect(lump, OUTLINE, false, 2.0)
		if groups > 1:
			canvas.draw_rect(box.grow(-4.0), Color(MARKER, 0.8), false, 3.0)
