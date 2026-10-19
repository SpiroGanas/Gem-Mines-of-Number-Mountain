## Draws a problem's visual: piles of hundred-blocks, ten-bars and one-gems (`gem_piles`),
## ten-frames (`ten_frame`, with an optional second set of dots for the second addend), number
## lines (`number_line`, with optional jump arcs), a balance scale (`balance`), arrays (`array`),
## equal groups (`groups`), gems lined up in pairs (`pairs`) and a number's digits with the part a
## divisibility rule looks at lit up (`digits`, Zone 5), rows of factors, multiples or prime recipes
## (`lists`, Zone 6) and meshing gears (`gears`, Zone 6); Zone 7's crystals, fraction line, crystal
## grids, depth gauge and ore mix are painted by CrystalArt. Gray-box shapes in code; the
## fields of each type are documented in scripts/core/problem.gd.
##
## The geometry lives in static functions that return plain rectangles (pile_layout, frame_cells,
## line_x...), so tests can prove nothing spills outside its box; _draw() only paints them.
## With `tappable` set, each pile is also a big button (skill cmp.to_20.more_less: "tap the pile").
class_name VisualModel
extends Control

## A pile was tapped (only when tappable). `index` is the pile's position, left to right.
signal pile_tapped(index: int)

const GEM_ROW: int = 5
const BLOCK_COLOR: Color = Color("#3E73B8")
const BAR_COLOR: Color = Color("#4F8FDB")
const EDGE_COLOR: Color = Color("#1F2945")
const FRAME_COLOR: Color = Color("#F5F7FF")
const DOT_COLOR: Color = Color("#FFD166")
const LINE_COLOR: Color = Color("#F5F7FF")
const MARKER_COLOR: Color = Color("#FFD166")
const GROUP_COLOR: Color = Color("#FFD166")
const LABEL_SIZE: int = 30
## Height of each kind of picture, in touch-target multiples, so it is sized to its content.
const HEIGHT_MULTIPLE_PILES: float = 6.0
const HEIGHT_MULTIPLE_LINE: float = 3.2
const HEIGHT_MULTIPLE_FRAME: float = 3.6
const HEIGHT_MULTIPLE_BALANCE: float = 4.2
const HEIGHT_MULTIPLE_ARRAY: float = 4.6
const HEIGHT_MULTIPLE_GROUPS: float = 4.0
const HEIGHT_MULTIPLE_PAIRS: float = 3.4
const HEIGHT_MULTIPLE_DIGITS: float = 3.2
const HEIGHT_MULTIPLE_LISTS: float = 3.0
const HEIGHT_MULTIPLE_GEARS: float = 4.0
## List items: the widest box and the font size of the numbers in it.
const LIST_ITEM_MAX: float = 72.0
const LIST_FONT: int = 28
## Zone 7 pictures (CrystalArt): crystals and grids need room to read; the gauge is tall.
const HEIGHT_MULTIPLE_CRYSTALS: float = 4.4
const HEIGHT_MULTIPLE_GAUGE: float = 6.0
const DIGIT_SIZE: int = 56
## The second addend's dots on a ten-frame are squares in another color, so color is never the
## only difference (accessibility rule).
const SECOND_COLOR: Color = Color("#7FC8F8")
const JUMP_COLOR: Color = Color("#7BD88F")
const BEAM_COLOR: Color = Color("#C9D1E8")
const RING_COLOR: Color = Color("#F5F7FF")
## How far the beam leans when one pan is heavier (radians).
const TILT_ANGLE: float = 0.22
const COMPACT_SCALE: float = 0.6
## Below this many pixels a side the model is not laid out yet, so _draw() draws nothing.
const MIN_DRAW_SIDE: float = 32.0

var visual: Dictionary = {}
var tappable: bool = false
## A smaller picture (hint pictures added above an input), COMPACT_SCALE of the normal height.
var compact: bool = false

var _buttons: Array[Button] = []
## One GearArt per gear a `gears` picture can hold (each keeps its own point buffer).
var _gear_arts: Array[GearArt] = [GearArt.new(), GearArt.new(), GearArt.new()]


func _ready() -> void:
	UI.make_touch_target(self, 6.0, HEIGHT_MULTIPLE_LINE)
	resized.connect(_on_resized)


## Shows a visual (an empty Dictionary clears it).
func show_visual(new_visual: Dictionary, make_tappable: bool = false) -> void:
	visual = new_visual
	tappable = make_tappable
	var height: float = HEIGHT_MULTIPLE_LINE
	match visual_type():
		&"gem_piles":
			height = HEIGHT_MULTIPLE_PILES
		&"ten_frame":
			height = HEIGHT_MULTIPLE_FRAME
		&"balance":
			height = HEIGHT_MULTIPLE_BALANCE
		&"array":
			height = HEIGHT_MULTIPLE_ARRAY
		&"groups":
			height = HEIGHT_MULTIPLE_GROUPS
		&"pairs":
			height = HEIGHT_MULTIPLE_PAIRS
		&"digits":
			height = HEIGHT_MULTIPLE_DIGITS
		&"lists":
			height = HEIGHT_MULTIPLE_LISTS
		&"gears":
			height = HEIGHT_MULTIPLE_GEARS
		&"crystals", &"crystal_grid", &"ore_mix":
			height = HEIGHT_MULTIPLE_CRYSTALS
		&"depth_gauge":
			height = HEIGHT_MULTIPLE_GAUGE
	UI.make_touch_target(self, 6.0, height * (COMPACT_SCALE if compact else 1.0))
	_rebuild_buttons()
	queue_redraw()


func visual_type() -> StringName:
	return visual.get("type", &"")


## The buttons laid over the piles (empty unless tappable).
func pile_buttons() -> Array[Button]:
	return _buttons


# --- Geometry (pure) -------------------------------------------------------------------------


## Where each piece of one pile goes inside `box`. Returns [{kind: &"hundred"|&"ten"|&"one",
## rect: Rect2}] with every rect inside `box`. Hundred-blocks first, then ten-bars, then ones in
## rows of five. Sizes shrink together until the whole pile fits.
static func pile_layout(pile: Dictionary, box: Rect2) -> Array[Dictionary]:
	var hundreds: int = pile["hundreds"]
	var tens: int = pile["tens"]
	var ones: int = pile["ones"]
	var gap: float = 8.0
	var unit: float = minf(box.size.y * 0.5, 96.0)
	var pieces: Array[Dictionary] = []
	for attempt: int in 40:
		pieces = _place_pieces(hundreds, tens, ones, unit, gap, box)
		if _fits(pieces, box):
			break
		unit *= 0.9
	return pieces


static func _place_pieces(hundreds: int, tens: int, ones: int, unit: float, gap: float, box: Rect2) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var block: float = unit * 2.0
	var bar: Vector2 = Vector2(unit * 0.45, unit * 2.0)
	var gem: float = unit * 0.5
	var x: float = box.position.x + gap
	var top: float = box.position.y + gap
	for i: int in hundreds:
		pieces.append({"kind": &"hundred", "rect": Rect2(x, top, block, block)})
		x += block + gap
	for i: int in tens:
		pieces.append({"kind": &"ten", "rect": Rect2(x, top, bar.x, bar.y)})
		x += bar.x + gap
	if ones > 0:
		x += gap
		for i: int in ones:
			var column: int = i % GEM_ROW
			var row: int = floori(float(i) / float(GEM_ROW))
			pieces.append({"kind": &"one", "rect": Rect2(x + column * (gem + gap), top + row * (gem + gap), gem, gem)})
	return pieces


## How far to shift a laid-out pile so it sits in the middle of its box (both ways).
static func centering_offset(pieces: Array[Dictionary], box: Rect2) -> Vector2:
	if pieces.is_empty():
		return Vector2.ZERO
	var bounds: Rect2 = pieces[0]["rect"]
	for piece: Dictionary in pieces:
		bounds = bounds.merge(piece["rect"])
	return box.get_center() - bounds.get_center()


static func _fits(pieces: Array[Dictionary], box: Rect2) -> bool:
	for piece: Dictionary in pieces:
		if not box.encloses(piece["rect"]):
			return false
	return true


## The box for pile `index` of `count`, side by side across `area` with a gap between.
static func pile_box(area: Rect2, index: int, count: int) -> Rect2:
	var gap: float = 24.0
	var width: float = (area.size.x - gap * float(count - 1)) / float(count)
	return Rect2(area.position.x + float(index) * (width + gap), area.position.y, width, area.size.y)


## The cells of `frames` ten-frames (two rows of five each) side by side inside `area`:
## [Rect2] in reading order, 10 per frame.
static func frame_cells(frames: int, area: Rect2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var gap: float = 24.0
	var frame_width: float = (area.size.x - gap * float(frames - 1)) / float(frames)
	var cell: float = minf(frame_width / 5.0, area.size.y / 2.0)
	for frame: int in frames:
		var left: float = area.position.x + float(frame) * (frame_width + gap)
		for index: int in 10:
			cells.append(Rect2(left + float(index % 5) * cell, area.position.y + float(floori(index / 5.0)) * cell, cell, cell))
	return cells


## The x position of `value` on a number line from `low` to `high` drawn across `width`
## with `margin` on each side.
static func line_x(value: float, low: float, high: float, width: float, margin: float) -> float:
	return margin + (value - low) / (high - low) * (width - 2.0 * margin)


## How often to draw a small tick: every number on a short line, every 5 or 10 on a long one.
static func minor_tick_step(low: int, high: int) -> int:
	var span: int = high - low
	if span <= 40:
		return 1
	return 5 if span <= 100 else 10


## The cells of a rows x cols array inside `area`: square cells, centred, in reading order.
static func array_cells(rows: int, cols: int, area: Rect2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var side: float = minf(area.size.x / float(maxi(cols, 1)), area.size.y / float(maxi(rows, 1)))
	var origin: Vector2 = area.get_center() - Vector2(side * cols, side * rows) * 0.5
	for row: int in rows:
		for col: int in cols:
			cells.append(Rect2(origin + Vector2(col, row) * side, Vector2(side, side)))
	return cells


## The rings of `groups` equal groups inside `area`: up to 5 to a row, square, centred.
static func group_boxes(groups: int, area: Rect2) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	var per_row: int = mini(groups, 5)
	var rows: int = ceili(float(groups) / 5.0)
	var gap: float = 16.0
	var side: float = minf((area.size.x - gap * (per_row - 1)) / float(per_row), (area.size.y - gap * (rows - 1)) / float(rows))
	for index: int in groups:
		var row: int = floori(index / 5.0)
		var in_row: int = mini(groups - row * 5, 5)
		var left: float = area.get_center().x - (side * in_row + gap * (in_row - 1)) * 0.5
		var top: float = area.get_center().y - (side * rows + gap * (rows - 1)) * 0.5
		boxes.append(Rect2(left + (index % 5) * (side + gap), top + row * (side + gap), side, side))
	return boxes


## Where `count` gems sit when lined up in pairs: column i holds gems 2i (top) and 2i + 1 (bottom),
## so an odd count leaves the last gem alone on top.
static func pair_cells(count: int, area: Rect2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var columns: int = maxi(ceili(count / 2.0), 1)
	var side: float = minf(area.size.x / float(columns), area.size.y / 2.0)
	var origin: Vector2 = area.get_center() - Vector2(side * columns, side * 2.0) * 0.5
	for index: int in count:
		cells.append(Rect2(origin + Vector2(floori(index / 2.0), index % 2) * side, Vector2(side, side)))
	return cells


## How far the beam turns: 0 when level or not yet known, negative (left end down) when the left
## pan is heavier.
static func beam_angle(tilt: String) -> float:
	match tilt:
		"left":
			return -TILT_ANGLE
		"right":
			return TILT_ANGLE
	return 0.0


# --- Drawing ---------------------------------------------------------------------------------


func _draw() -> void:
	if size.x < MIN_DRAW_SIDE or size.y < MIN_DRAW_SIDE:
		return # not laid out yet (or hidden by a tiny container): nothing sensible to draw
	match visual_type():
		&"gem_piles":
			_draw_piles()
		&"ten_frame":
			_draw_ten_frames()
		&"number_line":
			_draw_number_line()
		&"balance":
			_draw_balance()
		&"array":
			_draw_array()
		&"groups":
			_draw_groups()
		&"pairs":
			_draw_pairs()
		&"digits":
			_draw_digits()
		&"lists":
			_draw_lists()
		&"gears":
			_draw_gears()
		_:
			CrystalArt.draw_visual(self, Rect2(Vector2(12, 12), size - Vector2(24, 24)), visual, get_theme_default_font())


func _draw_piles() -> void:
	var piles: Array = visual["piles"]
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	for index: int in piles.size():
		var box: Rect2 = pile_box(area, index, piles.size())
		draw_style_box(_panel_style(), box)
		var inner: Rect2 = box.grow(-6.0)
		var pieces: Array[Dictionary] = pile_layout(piles[index], inner)
		var offset: Vector2 = centering_offset(pieces, inner)
		for piece: Dictionary in pieces:
			_draw_piece(piece["kind"], Rect2(piece["rect"].position + offset, piece["rect"].size))
		_draw_group_outline(pieces, offset)


func _draw_piece(kind: StringName, rect: Rect2) -> void:
	match kind:
		&"hundred":
			draw_rect(rect, BLOCK_COLOR)
			draw_rect(rect, EDGE_COLOR, false, 2.0)
			for step: int in range(1, 10):
				var f: float = float(step) / 10.0
				draw_line(Vector2(rect.position.x + rect.size.x * f, rect.position.y), Vector2(rect.position.x + rect.size.x * f, rect.end.y), EDGE_COLOR.lightened(0.3), 1.0)
				draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y * f), Vector2(rect.end.x, rect.position.y + rect.size.y * f), EDGE_COLOR.lightened(0.3), 1.0)
		&"ten":
			draw_rect(rect, BAR_COLOR)
			draw_rect(rect, EDGE_COLOR, false, 2.0)
			for step: int in range(1, 10):
				var y: float = rect.position.y + rect.size.y * float(step) / 10.0
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), EDGE_COLOR.lightened(0.3), 1.0)
		_:
			var points: PackedVector2Array = GemArt.shape_points(GemArt.QUARTZ)
			var scaled: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in points:
				scaled.append(rect.position + point * rect.size)
			draw_colored_polygon(scaled, GemArt.color_for(GemArt.QUARTZ))
			scaled.append(scaled[0])
			draw_polyline(scaled, EDGE_COLOR, 2.0, true)


## The regroup hint circles the group of ten gems (or the one ten-bar) that gets traded.
func _draw_group_outline(pieces: Array[Dictionary], offset: Vector2) -> void:
	var group: Rect2 = Rect2()
	var found: bool = false
	if visual.has("group_ones"):
		var count: int = 0
		for piece: Dictionary in pieces:
			if piece["kind"] == &"one" and count < int(visual["group_ones"]):
				group = piece["rect"] if not found else group.merge(piece["rect"])
				found = true
				count += 1
	elif visual.has("group_tens"):
		for piece: Dictionary in pieces:
			if piece["kind"] == &"ten":
				group = piece["rect"]
				found = true
				break
	if found:
		draw_rect(Rect2(group.position + offset, group.size).grow(6.0), GROUP_COLOR, false, 4.0)


func _draw_ten_frames() -> void:
	var cells: Array[Rect2] = frame_cells(int(visual["frames"]), Rect2(Vector2.ZERO, size).grow(-8.0))
	var count: int = int(visual["count"])
	var second: int = int(visual.get("second", 0))
	for index: int in cells.size():
		draw_rect(cells[index], FRAME_COLOR, false, 3.0)
		if index < count:
			draw_circle(cells[index].get_center(), cells[index].size.x * 0.34, DOT_COLOR)
		elif index < count + second:
			draw_rect(cells[index].grow(-cells[index].size.x * 0.2), SECOND_COLOR)


func _draw_number_line() -> void:
	var low: int = visual["min"]
	var high: int = visual["max"]
	var margin: float = 36.0
	var y: float = size.y * 0.62
	var font: Font = get_theme_default_font()
	draw_line(Vector2(margin, y), Vector2(size.x - margin, y), LINE_COLOR, 4.0)
	var minor: int = minor_tick_step(low, high)
	var every: int = maxi(int(visual["labeled_every"]), 1)
	var blanks: Array = visual["blanks"]
	for value: int in range(low, high + 1):
		var x: float = line_x(value, low, high, size.x, margin)
		var labeled: bool = value % every == 0
		if labeled:
			draw_line(Vector2(x, y - 18.0), Vector2(x, y + 18.0), LINE_COLOR, 3.0)
		elif value % minor == 0:
			draw_line(Vector2(x, y - 9.0), Vector2(x, y + 9.0), LINE_COLOR, 2.0)
		if not labeled:
			continue
		if blanks.has(value):
			draw_rect(Rect2(x - 26.0, y + 24.0, 52.0, 44.0), LINE_COLOR, false, 3.0) # an empty box to fill in
		else:
			var text: String = str(value)
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
			draw_string(font, Vector2(x - width * 0.5, y + 58.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LINE_COLOR)
	for marker: int in visual["markers"]:
		var mx: float = line_x(marker, low, high, size.x, margin)
		draw_colored_polygon(PackedVector2Array([Vector2(mx, y - 8.0), Vector2(mx - 16.0, y - 44.0), Vector2(mx + 16.0, y - 44.0)]), MARKER_COLOR)
	for jump: Dictionary in visual.get("jumps", []):
		_draw_jump(line_x(jump["from"], low, high, size.x, margin), line_x(jump["to"], low, high, size.x, margin), y)


## An arc above the line from one value to another, with an arrowhead where it lands.
func _draw_jump(from_x: float, to_x: float, y: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var rise: float = clampf(absf(to_x - from_x) * 0.35, 24.0, size.y * 0.45)
	for step: int in 17:
		var t: float = float(step) / 16.0
		points.append(Vector2(lerpf(from_x, to_x, t), y - 14.0 - sin(t * PI) * rise))
	draw_polyline(points, JUMP_COLOR, 4.0, true)
	var tip: Vector2 = points[points.size() - 1]
	var back: float = -12.0 if to_x > from_x else 12.0
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(back, -14.0), tip + Vector2(back * 1.3, 2.0)]), JUMP_COLOR)


func _draw_balance() -> void:
	var font: Font = get_theme_default_font()
	var pivot: Vector2 = Vector2(size.x * 0.5, size.y * 0.42)
	var half: float = size.x * 0.36
	var angle: float = beam_angle(str(visual.get("tilt", "unknown")))
	var left_end: Vector2 = pivot + Vector2(-half, 0).rotated(angle)
	var right_end: Vector2 = pivot + Vector2(half, 0).rotated(angle)
	# Stand and pivot.
	draw_colored_polygon(PackedVector2Array([pivot, pivot + Vector2(-40, size.y * 0.5), pivot + Vector2(40, size.y * 0.5)]), BEAM_COLOR.darkened(0.3))
	draw_line(left_end, right_end, BEAM_COLOR, 10.0)
	draw_circle(pivot, 12.0, MARKER_COLOR)
	if str(visual.get("tilt", "unknown")) == "unknown":
		var mark: String = "?"
		draw_string(font, pivot + Vector2(-12, -24), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE + 8, MARKER_COLOR)
	for side: Array in [[left_end, visual.get("left", [])], [right_end, visual.get("right", [])]]:
		var end: Vector2 = side[0]
		var pan: Rect2 = Rect2(end + Vector2(-size.x * 0.13, size.y * 0.16), Vector2(size.x * 0.26, size.y * 0.2))
		draw_line(end, pan.position, BEAM_COLOR, 3.0)
		draw_line(end, Vector2(pan.end.x, pan.position.y), BEAM_COLOR, 3.0)
		draw_style_box(_panel_style(), pan)
		var parts: PackedStringArray = PackedStringArray()
		for term: Variant in side[1]:
			parts.append(str(term))
		var label: String = " + ".join(parts)
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(font, Vector2(pan.get_center().x - width * 0.5, pan.get_center().y + LABEL_SIZE * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LINE_COLOR)


func _draw_gem(rect: Rect2) -> void:
	var points: PackedVector2Array = GemArt.shape_points(GemArt.PYRITE)
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(rect.position + point * rect.size)
	draw_colored_polygon(scaled, GemArt.color_for(GemArt.PYRITE))
	scaled.append(scaled[0])
	draw_polyline(scaled, EDGE_COLOR, 2.0, true)


func _draw_array() -> void:
	var rows: int = int(visual["rows"])
	var cols: int = int(visual["cols"])
	var cells: Array[Rect2] = array_cells(rows, cols, Rect2(Vector2.ZERO, size).grow(-12.0))
	for cell: Rect2 in cells:
		_draw_gem(cell.grow(-cell.size.x * 0.14))
	if visual.get("outline_rows", false):
		for row: int in rows:
			var first: Rect2 = cells[row * cols]
			var band: Rect2 = first.merge(cells[row * cols + cols - 1]).grow(-2.0)
			draw_rect(band, GROUP_COLOR, false, 3.0)


func _draw_groups() -> void:
	var boxes: Array[Rect2] = group_boxes(int(visual["groups"]), Rect2(Vector2.ZERO, size).grow(-8.0))
	var per_group: int = int(visual["size"])
	var columns: int = ceili(sqrt(float(per_group)))
	var rows: int = ceili(float(per_group) / float(columns))
	for box: Rect2 in boxes:
		draw_circle(box.get_center(), box.size.x * 0.5, RING_COLOR, false, 3.0, true)
		var inner: Rect2 = Rect2(box.get_center() - box.size * 0.33, box.size * 0.66)
		var cells: Array[Rect2] = array_cells(rows, columns, inner)
		for index: int in per_group:
			_draw_gem(cells[index].grow(-cells[index].size.x * 0.12))


func _draw_pairs() -> void:
	var count: int = int(visual["count"])
	var cells: Array[Rect2] = pair_cells(count, Rect2(Vector2.ZERO, size).grow(-10.0))
	for cell: Rect2 in cells:
		_draw_gem(cell.grow(-cell.size.x * 0.16))
	if not visual.get("show_pairs", false):
		return
	for pair: int in floori(count / 2.0):
		draw_rect(cells[pair * 2].merge(cells[pair * 2 + 1]).grow(-3.0), GROUP_COLOR, false, 3.0)
	if count % 2 == 1:
		draw_circle(cells[count - 1].get_center(), cells[count - 1].size.x * 0.5, MARKER_COLOR, false, 4.0, true) # the one left over


## Which digits a `digits` picture lights up (indexes into its digits), by its focus: "last" (2, 5,
## 10), "last_two" (4), "sum" and "recipe" (every digit), "sum_and_last" (6). Pure.
static func lit_digits(count: int, focus: String) -> Array[int]:
	var lit: Array[int] = []
	match focus:
		"last":
			lit.append(count - 1)
		"last_two":
			for index: int in range(maxi(count - 2, 0), count):
				lit.append(index)
		_:
			for index: int in count:
				lit.append(index)
	return lit


## The line under a `digits` picture: "1 + 2 + 6 = 9" for a digit sum, "= 2 × 2 × 3" for a recipe,
## nothing for the last-digit rules. Numerals and signs only. Pure.
static func digits_caption(picture: Dictionary) -> String:
	var digits: Array = picture.get("digits", [])
	var focus: String = str(picture.get("focus", "last"))
	if focus == "sum" or focus == "sum_and_last":
		var parts: PackedStringArray = PackedStringArray()
		var total: int = 0
		for digit: Variant in digits:
			parts.append(str(int(digit)))
			total += int(digit)
		return "%s = %d" % [" + ".join(parts), total]
	if focus == "recipe":
		var factors: PackedStringArray = PackedStringArray()
		for factor: Variant in picture.get("recipe", []):
			factors.append(str(int(factor)))
		return "= " + " × ".join(factors)
	return ""


## A row of digit boxes; the lit ones get a thick headlamp-yellow border and a pointer above (so the
## color is never the only clue), and the caption goes underneath.
func _draw_digits() -> void:
	var digits: Array = visual.get("digits", [])
	if digits.is_empty():
		return
	var font: Font = get_theme_default_font()
	var caption: String = digits_caption(visual)
	var box_side: float = minf(size.y * (0.5 if caption != "" else 0.7), (size.x - 24.0) / float(digits.size()) - 12.0)
	var row_width: float = digits.size() * (box_side + 12.0) - 12.0
	var top: float = size.y * (0.12 if caption != "" else 0.18)
	var left: float = (size.x - row_width) / 2.0
	var lit: Array[int] = lit_digits(digits.size(), str(visual.get("focus", "last")))
	for index: int in digits.size():
		var box: Rect2 = Rect2(left + index * (box_side + 12.0), top, box_side, box_side)
		var on: bool = lit.has(index)
		draw_rect(box, Color(1, 1, 1, 0.08), true)
		draw_rect(box, MARKER_COLOR if on else LINE_COLOR, false, 6.0 if on else 2.0)
		var text: String = str(int(digits[index]))
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, DIGIT_SIZE)
		draw_string(font, Vector2(box.get_center().x - text_size.x / 2.0, box.get_center().y + DIGIT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, DIGIT_SIZE, LINE_COLOR)
		if on and box.position.y > 14.0:
			var mx: float = box.get_center().x
			draw_colored_polygon(PackedVector2Array([Vector2(mx, box.position.y - 2.0), Vector2(mx - 10.0, box.position.y - 14.0), Vector2(mx + 10.0, box.position.y - 14.0)]), MARKER_COLOR)
	if caption != "":
		var caption_size: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		draw_string(font, Vector2((size.x - caption_size.x) / 2.0, top + box_side + 24.0 + LABEL_SIZE), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, MARKER_COLOR)


## Where each item of a `lists` picture goes: one row per number, a label box for the number and one
## box per item, all inside `box` and sized to the longest row. Returns [{row, index (-1 for the
## label), rect}]. Pure.
static func list_cells(rows: Array, box: Rect2) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	if rows.is_empty():
		return cells
	var longest: int = 1
	for row: Variant in rows:
		longest = maxi(longest, row.get("items", []).size())
	var gap: float = 8.0
	var height: float = minf((box.size.y - gap * (rows.size() - 1)) / float(rows.size()), LIST_ITEM_MAX)
	var width: float = minf((box.size.x - gap * longest) / float(longest + 1.5), LIST_ITEM_MAX)
	var label_width: float = width * 1.5
	var total_width: float = label_width + (width + gap) * longest
	var left: float = box.position.x + (box.size.x - total_width) / 2.0
	var top: float = box.position.y + (box.size.y - (height + gap) * rows.size() + gap) / 2.0
	for row_index: int in rows.size():
		var y: float = top + row_index * (height + gap)
		cells.append({"row": row_index, "index": -1, "rect": Rect2(left, y, label_width, height)})
		for index: int in rows[row_index].get("items", []).size():
			cells.append({"row": row_index, "index": index, "rect": Rect2(left + label_width + gap + index * (width + gap), y, width, height)})
	return cells


## Rows such as "12: 1 2 3 4 6 12". A marked value (or a lit position) gets a thick headlamp-yellow
## ring and a dot above it, so color is never the only clue. A recipe row puts × between its primes.
func _draw_lists() -> void:
	var rows: Array = visual.get("rows", [])
	var marked: Array = visual.get("marked", [])
	var recipe: bool = str(visual.get("kind", "")) == "recipe"
	var font: Font = get_theme_default_font()
	for cell: Dictionary in list_cells(rows, Rect2(Vector2.ZERO, size).grow(-8.0)):
		var rect: Rect2 = cell["rect"]
		var row: Dictionary = rows[cell["row"]]
		var index: int = cell["index"]
		var font_size: int = clampi(int(rect.size.y * 0.5), 14, LIST_FONT)
		var text: String
		var on: bool = false
		if index < 0:
			text = ("%d =" if recipe else "%d:") % int(row["n"])
		else:
			var value: int = int(row["items"][index])
			text = str(value)
			on = marked.has(value) or row.get("lit", []).has(index)
			draw_rect(rect, Color(1, 1, 1, 0.08), true)
			draw_rect(rect, MARKER_COLOR if on else Color(LINE_COLOR, 0.4), false, 5.0 if on else 1.5)
			if on:
				draw_circle(Vector2(rect.get_center().x, rect.position.y + 5.0), 4.0, MARKER_COLOR)
			if recipe and index > 0:
				var sign_size: Vector2 = font.get_string_size("×", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				draw_string(font, Vector2(rect.position.x - sign_size.x / 2.0 - 4.0, rect.get_center().y + font_size * 0.35), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LINE_COLOR)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(rect.get_center().x - text_size.x / 2.0, rect.get_center().y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, MARKER_COLOR if on else LINE_COLOR)


## The centers and radii of a `gears` picture's gears in a row, meshing, scaled to fit `box`. Pure.
static func gear_layout(teeth: Array, box: Rect2) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	if teeth.is_empty():
		return placed
	var scales: Array[float] = []
	var span: float = 0.0
	var tallest: float = 0.0
	for count: Variant in teeth:
		var scale: float = GearArt.radius_for(int(count), 1.0)
		scales.append(scale)
		span += scale * 2.0
		tallest = maxf(tallest, scale * 2.0)
	span -= 0.16 * (teeth.size() - 1) * scales.min() # neighbours' teeth overlap where they mesh
	var unit: float = minf(box.size.x / span, box.size.y / tallest)
	var x: float = box.position.x + (box.size.x - span * unit) / 2.0
	for index: int in teeth.size():
		var radius: float = scales[index] * unit
		if index > 0:
			x -= 0.16 * scales.min() * unit
		placed.append({"center": Vector2(x + radius, box.get_center().y), "radius": radius})
		x += radius * 2.0
	return placed


## Meshing gears with their tooth counts; the marked teeth face each other where the gears meet.
func _draw_gears() -> void:
	var teeth: Array = visual.get("teeth", [])
	var layout: Array[Dictionary] = gear_layout(teeth, Rect2(Vector2.ZERO, size).grow(-10.0))
	var marks: bool = bool(visual.get("marks", false))
	for index: int in mini(layout.size(), _gear_arts.size()):
		var count: int = int(teeth[index])
		var step: float = TAU / float(GearArt.drawn_teeth(count))
		var facing: float = (0.0 if index % 2 == 0 else PI) - step * 0.36
		var shaded: int = int(visual.get("shaded", 0)) if index == 0 else 0
		_gear_arts[index].draw(self, layout[index]["center"], layout[index]["radius"] * 0.95, count, facing, str(count), shaded, marks)


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.border_color = Color(1, 1, 1, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style


# --- Tappable piles ---------------------------------------------------------------------------


func _rebuild_buttons() -> void:
	for button: Button in _buttons:
		button.queue_free()
		remove_child(button)
	_buttons.clear()
	if not tappable or visual_type() != &"gem_piles":
		return
	var count: int = visual["piles"].size()
	for index: int in count:
		var button: Button = Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(pile_tapped.emit.bind(index))
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.12) if style_name in [&"hover", &"pressed"] else Color(0, 0, 0, 0)
			style.border_color = Color("#FFD166") if style_name in [&"hover", &"focus", &"pressed"] else Color(0, 0, 0, 0)
			style.set_border_width_all(6)
			style.set_corner_radius_all(16)
			button.add_theme_stylebox_override(style_name, style)
		add_child(button)
		_buttons.append(button)
	_layout_buttons()


func _layout_buttons() -> void:
	for index: int in _buttons.size():
		var box: Rect2 = pile_box(Rect2(Vector2.ZERO, size), index, _buttons.size())
		_buttons[index].position = box.position
		_buttons[index].size = box.size


func _on_resized() -> void:
	_layout_buttons()
	queue_redraw()
