## Code-drawn art for Zone 9, Pattern Grotto (no artist; Spiro's decision): rows of crystal tiles with
## their steps, gems stacked into triangles and squares, Gauss's pairing rows, Fibonacci squares in a
## golden rectangle with its spiral, the proof-without-words pictures and a Fib poem's beat dots. Static
## painters that draw on any CanvasItem inside a Rect2, so the problem picture (VisualModel), the pattern
## wall, the proof board and the poem maker all look the same.
##
## Two pieces of a picture always differ by shape as well as color (round gems and square blocks), so
## color is never the only clue (accessibility rule). Crystals glow with electric light, never a flame.
## The picture fields are documented in scripts/core/problem.gd. The geometry (proof_pieces,
## fib_square_rects, figure_cells) is pure and tested; the painters only paint it.
class_name PatternArt
extends RefCounted

const OUTLINE: Color = Color("#1F2945")
const TILE: Color = Color("#F5F7FF")
const CRYSTAL: Color = Color("#B79CFF")
const CRYSTAL_GLOW: Color = Color(0.72, 0.61, 1.0, 0.25)
const BLANK: Color = Color(1, 1, 1, 0.12)
const PIECE_A: Color = Color("#FFD166")
const PIECE_B: Color = Color("#7FC8F8")
const LINE: Color = Color("#F5F7FF")
const STEP: Color = Color("#7BD88F")
const DIM: Color = Color(1, 1, 1, 0.25)
const LABEL_SIZE: int = 28
const SMALL_LABEL: int = 20
const GAP: float = 16.0
## A pairing row longer than this shows its first and last PAIRING_ENDS columns with a gap between.
const PAIRING_ALL_UP_TO: int = 10
const PAIRING_ENDS: int = 3
## Where a loose proof piece waits, in cells to the right of the fitted shape.
const APART_GAP: float = 1.5


## Draws any Zone 9 picture inside `rect`. Returns false for a picture type it does not know.
static func draw_visual(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> bool:
	match str(visual.get("type", "")):
		"pattern":
			draw_pattern(canvas, rect, visual, font)
		"figurate":
			var kind: String = str(visual.get("kind", "triangle"))
			if kind == "two_triangles":
				draw_pieces(canvas, rect, proof_pieces("two_triangles", int(visual.get("n", 3)), bool(visual.get("fitted", true))), 1.0)
			else:
				draw_pieces(canvas, rect, figure_cells(kind, int(visual.get("n", 3))), 1.0)
		"pairing":
			draw_pairing(canvas, rect, int(visual.get("n", 2)), font)
		"fib_squares":
			draw_fib_squares(canvas, rect, visual.get("terms", []), font)
		"proof":
			draw_pieces(canvas, rect, proof_pieces(str(visual.get("diagram", "")), int(visual.get("n", 3)), bool(visual.get("fitted", true))), 1.0)
		"poem_shape":
			draw_poem_shape(canvas, rect, visual, font)
		_:
			return false
	return true


# --- Pattern rows ----------------------------------------------------------------------------------


## A row of tiles left to right, "?" on the blanks, steps written between them, figures above.
static func draw_pattern(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var terms: Array = visual.get("terms", [])
	var count: int = terms.size()
	if count == 0:
		return
	var blanks: Array = visual.get("blanks", [])
	var crystals: bool = str(visual.get("style", "numbers")) == "crystals"
	var figure: String = str(visual.get("figure", ""))
	var steps: Array = visual.get("steps", [])
	var width: float = minf((rect.size.x - GAP * float(count - 1)) / float(count), rect.size.y * (0.9 if figure.is_empty() else 0.6))
	var tile_h: float = minf(width, rect.size.y * (0.55 if figure.is_empty() else 0.4))
	var total: float = width * count + GAP * float(count - 1)
	var x: float = rect.position.x + (rect.size.x - total) * 0.5
	# With figures the tiles sit at the bottom under their gems; without, in the middle under the steps.
	var tile_y: float = rect.end.y - tile_h if not figure.is_empty() else rect.get_center().y - tile_h * 0.5 + SMALL_LABEL * 0.5
	var first_index: int = int(visual.get("first_index", 1))
	for index: int in count:
		var box: Rect2 = Rect2(x, tile_y, width, tile_h)
		var blank: bool = blanks.has(index)
		if blank:
			canvas.draw_rect(box, BLANK)
			canvas.draw_rect(box, LINE, false, 3.0)
		elif crystals:
			draw_crystal_tile(canvas, box)
		else:
			canvas.draw_rect(box, TILE)
			canvas.draw_rect(box, OUTLINE, false, 3.0)
		if font != null:
			var text: String = "?" if blank else str(int(terms[index]))
			_centered(canvas, font, box.get_center(), text, LABEL_SIZE if width > 70.0 else SMALL_LABEL, LINE if blank else OUTLINE)
		if not figure.is_empty():
			var above: Rect2 = Rect2(x, rect.position.y, width, tile_y - rect.position.y - 6.0)
			var cells: Array[Dictionary] = figure_cells(figure, first_index + index)
			draw_pieces(canvas, above, cells, 0.0 if blank else 1.0)
		if index < steps.size() and font != null:
			var sign: String = "×" if str(visual.get("step_op", "plus")) == "times" else "+"
			var mid: Vector2 = Vector2(x + width + GAP * 0.5, tile_y - 4.0)
			canvas.draw_arc(Vector2(mid.x, tile_y), width * 0.5 + GAP * 0.5, PI * 1.15, PI * 1.85, 12, STEP, 2.5)
			_centered(canvas, font, mid - Vector2(0, width * 0.32), sign + str(int(steps[index])), SMALL_LABEL, STEP)
		x += width + GAP


## A crystal tile: a faceted glowing gem shape behind the number, lit by electric light.
static func draw_crystal_tile(canvas: CanvasItem, box: Rect2) -> void:
	var c: Vector2 = box.get_center()
	var w: float = box.size.x * 0.5
	var h: float = box.size.y * 0.5
	canvas.draw_rect(box.grow(4.0), CRYSTAL_GLOW)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-w * 0.6, -h), c + Vector2(w * 0.6, -h), c + Vector2(w, -h * 0.3),
		c + Vector2(w, h * 0.3), c + Vector2(w * 0.6, h), c + Vector2(-w * 0.6, h),
		c + Vector2(-w, h * 0.3), c + Vector2(-w, -h * 0.3)]), CRYSTAL)
	canvas.draw_rect(box, OUTLINE, false, 2.0)


# --- Gems in shapes ---------------------------------------------------------------------------------


## The cells of a triangle (rows 1..n, a left-aligned staircase) or a square (n by n), all one piece.
## Each cell is {rect: Rect2 in cell units, piece: 0}.
static func figure_cells(kind: String, n: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for r: int in n:
		var width: int = n if kind == "square" else r + 1
		for c: int in width:
			cells.append({"rect": Rect2(c, r, 1, 1), "piece": 0})
	return cells


## The two pieces of a proof picture, in cell units: piece 0 stays, piece 1 is the loose piece; `fitted`
## puts it in place, otherwise it waits APART_GAP cells to the right. Grid diagrams give 1 by 1 cells;
## fib_squares gives whole squares (side = the Fibonacci number). Pure, so tests can check that the
## fitted pieces never overlap and fill the shape the fact names.
##   staircases     rows 1..n (piece 0) and n..1 (piece 1): an n by (n + 1) rectangle
##   two_triangles  rows 1..n and 0..n - 1: an n by n square
##   odd_layers     L-shaped layers 1, 3, 5, ... of an n by n square; the outer layer is the loose piece
##   array_turn     an n by (n + 2) array and the same array turned a quarter turn
##   fib_squares    squares F(1)..F(n) in a golden rectangle; the biggest square is the loose piece
static func proof_pieces(diagram: String, n: int, fitted: bool) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	match diagram:
		"staircases", "two_triangles":
			var cols: int = n + 1 if diagram == "staircases" else n
			for r: int in n:
				for c: int in cols:
					pieces.append({"rect": Rect2(c, r, 1, 1), "piece": 0 if c <= r else 1})
		"odd_layers":
			for r: int in n:
				for c: int in n:
					pieces.append({"rect": Rect2(c, r, 1, 1), "piece": 1 if maxi(r, c) == n - 1 else 0, "layer": maxi(r, c)})
		"array_turn":
			for r: int in n:
				for c: int in n + 2:
					pieces.append({"rect": Rect2(c, r, 1, 1), "piece": 0})
			# The turned copy: (n + 2) rows of n. Fitted, it is turned back onto the first array.
			for r: int in n + 2:
				for c: int in n:
					var spot: Rect2 = Rect2(r, c, 1, 1) if fitted else Rect2(c, r, 1, 1)
					pieces.append({"rect": spot, "piece": 1, "overlay": true})
		"fib_squares":
			var rects: Array[Rect2] = fib_square_rects(n)
			for index: int in rects.size():
				pieces.append({"rect": rects[index], "piece": 1 if index == rects.size() - 1 else 0, "square": true})
	if not fitted:
		var right: float = 0.0
		for entry: Dictionary in pieces:
			if int(entry["piece"]) == 0:
				right = maxf(right, (entry["rect"] as Rect2).end.x)
		var left: float = INF
		for entry: Dictionary in pieces:
			if int(entry["piece"]) == 1:
				left = minf(left, (entry["rect"] as Rect2).position.x)
		for entry: Dictionary in pieces:
			if int(entry["piece"]) == 1 and left < INF:
				var spot: Rect2 = entry["rect"]
				entry["rect"] = Rect2(spot.position + Vector2(right - left + APART_GAP, 0.0), spot.size)
	return pieces


## The squares of sides F(1)..F(n) laid out in a spiral (right, down, left, up...), each new square on
## the long side of the rectangle so far: a golden rectangle of F(n) by F(n + 1). Cell units, from 0.
static func fib_square_rects(n: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var bounds: Rect2 = Rect2()
	var before: int = 0
	var side: int = 1
	for index: int in maxi(n, 1):
		var spot: Rect2
		if index == 0:
			spot = Rect2(0, 0, 1, 1)
		else:
			match index % 4:
				1:
					spot = Rect2(bounds.end.x, bounds.position.y, side, side) # to the right
				2:
					spot = Rect2(bounds.end.x - side, bounds.end.y, side, side) # below
				3:
					spot = Rect2(bounds.position.x - side, bounds.end.y - side, side, side) # to the left
				_:
					spot = Rect2(bounds.position.x, bounds.position.y - side, side, side) # above
		rects.append(spot)
		bounds = spot if index == 0 else bounds.merge(spot)
		var next: int = before + side
		before = side
		side = next
	# Move everything so the top left corner is at (0, 0).
	for index: int in rects.size():
		rects[index] = Rect2(rects[index].position - bounds.position, rects[index].size)
	return rects


## The bounding box of some pieces, in their units.
static func pieces_bounds(pieces: Array[Dictionary]) -> Rect2:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for entry: Dictionary in pieces:
		var spot: Rect2 = entry["rect"]
		bounds = spot if first else bounds.merge(spot)
		first = false
	return bounds


## Paints pieces scaled to fit `rect`: piece 0 as round gems (gold), piece 1 as square blocks (blue);
## whole squares (fib_squares) as outlined squares with a quarter arc of the spiral. `alpha` dims the
## picture (a blank figure on the pattern wall).
## The proof board slides piece 1 by `shift_b` (cell units) inside a fixed `frame` (the bounds of both the
## apart and the fitted picture), so the picture does not rescale while the piece moves.
static func draw_pieces(canvas: CanvasItem, rect: Rect2, pieces: Array[Dictionary], alpha: float, shift_b: Vector2 = Vector2.ZERO, frame: Rect2 = Rect2()) -> void:
	if pieces.is_empty() or alpha <= 0.0:
		return
	var bounds: Rect2 = frame if frame.has_area() else pieces_bounds(pieces)
	var unit: float = minf(rect.size.x / maxf(bounds.size.x, 1.0), rect.size.y / maxf(bounds.size.y, 1.0))
	var origin: Vector2 = rect.position + (rect.size - bounds.size * unit) * 0.5 - bounds.position * unit
	for entry: Dictionary in pieces:
		var spot: Rect2 = entry["rect"]
		var moved: Vector2 = shift_b if int(entry["piece"]) == 1 else Vector2.ZERO
		var box: Rect2 = Rect2(origin + (spot.position + moved) * unit, spot.size * unit)
		var color: Color = PIECE_A if int(entry["piece"]) == 0 else PIECE_B
		color.a = alpha * (0.85 if entry.get("overlay", false) else 1.0)
		if entry.get("square", false):
			canvas.draw_rect(box.grow(-1.0), Color(color, 0.35 * alpha))
			canvas.draw_rect(box.grow(-1.0), Color(OUTLINE, alpha), false, 2.0)
			canvas.draw_arc(box.position + Vector2(box.size.x, box.size.y), box.size.x * 0.95, PI, PI * 1.5, 10, Color(LINE, alpha), 2.0)
		elif int(entry["piece"]) == 0:
			canvas.draw_circle(box.get_center(), box.size.x * 0.4, color)
		else:
			canvas.draw_rect(box.grow(-box.size.x * 0.12), color)
		if entry.has("layer") and int(entry["layer"]) % 2 == 1 and int(entry["piece"]) == 0:
			canvas.draw_circle(box.get_center(), box.size.x * 0.15, Color(OUTLINE, alpha)) # odd layers carry a dot


# --- Gauss's pairs ----------------------------------------------------------------------------------


## The columns shown for a pairing of n: every column up to PAIRING_ALL_UP_TO, else the first and last
## PAIRING_ENDS with -1 for the gap between them.
static func pairing_columns(n: int) -> Array[int]:
	var columns: Array[int] = []
	if n <= PAIRING_ALL_UP_TO:
		for value: int in range(1, n + 1):
			columns.append(value)
		return columns
	for value: int in range(1, PAIRING_ENDS + 1):
		columns.append(value)
	columns.append(-1)
	for value: int in range(n - PAIRING_ENDS + 1, n + 1):
		columns.append(value)
	return columns


## 1..n on top, n..1 below, each column joined by a line and its sum (n + 1) underneath.
static func draw_pairing(canvas: CanvasItem, rect: Rect2, n: int, font: Font) -> void:
	var columns: Array[int] = pairing_columns(n)
	var width: float = rect.size.x / float(columns.size())
	var size: int = LABEL_SIZE if width > 56.0 else SMALL_LABEL
	for index: int in columns.size():
		var x: float = rect.position.x + width * (index + 0.5)
		var top: Vector2 = Vector2(x, rect.position.y + rect.size.y * 0.2)
		var bottom: Vector2 = Vector2(x, rect.position.y + rect.size.y * 0.55)
		if columns[index] < 0:
			if font != null:
				_centered(canvas, font, (top + bottom) * 0.5, "…", size, LINE)
			continue
		canvas.draw_line(top + Vector2(0, size * 0.6), bottom - Vector2(0, size * 0.6), STEP, 2.0)
		if font != null:
			_centered(canvas, font, top, str(columns[index]), size, PIECE_A)
			_centered(canvas, font, bottom, str(n + 1 - columns[index]), size, PIECE_B)
			_centered(canvas, font, Vector2(x, rect.position.y + rect.size.y * 0.85), str(n + 1), size, STEP)


# --- Fibonacci squares and the poem's shape ------------------------------------------------------------


## The golden rectangle of squares with sides `terms` (consecutive Fibonacci numbers from F(1) or
## later), each big square labeled with its side.
static func draw_fib_squares(canvas: CanvasItem, rect: Rect2, terms: Array, font: Font) -> void:
	if terms.is_empty():
		return
	# Rebuild the whole run from F(1) so the spiral is right, then draw the last terms.size() squares.
	var count: int = 1
	while FibGenerator.fib(count) < int(terms.back()) or (count < 2 and terms.size() > 1):
		count += 1
	var rects: Array[Rect2] = fib_square_rects(count)
	var shown: Array[Dictionary] = []
	for index: int in range(maxi(rects.size() - terms.size(), 0), rects.size()):
		shown.append({"rect": rects[index], "piece": index % 2, "square": true})
	draw_pieces(canvas, rect, shown, 1.0)
	if font == null:
		return
	var bounds: Rect2 = pieces_bounds(shown)
	var unit: float = minf(rect.size.x / maxf(bounds.size.x, 1.0), rect.size.y / maxf(bounds.size.y, 1.0))
	var origin: Vector2 = rect.position + (rect.size - bounds.size * unit) * 0.5 - bounds.position * unit
	for entry: Dictionary in shown:
		var spot: Rect2 = entry["rect"]
		if spot.size.x * unit >= SMALL_LABEL * 1.6:
			_centered(canvas, font, origin + spot.get_center() * unit, str(int(spot.size.x)), SMALL_LABEL, LINE)


## One row of beat dots per poem line; the lit line glows; with `counts` each row's count is written.
static func draw_poem_shape(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var lines: Array = visual.get("lines", [])
	if lines.is_empty():
		return
	var highlight: int = int(visual.get("highlight", -1))
	var most: int = 1
	for count: Variant in lines:
		most = maxi(most, int(count))
	var row_h: float = rect.size.y / float(lines.size())
	var dot: float = minf(row_h * 0.32, rect.size.x / float(most + 3) * 0.32)
	for row: int in lines.size():
		var y: float = rect.position.y + row_h * (row + 0.5)
		var lit: bool = row == highlight
		if lit:
			canvas.draw_rect(Rect2(rect.position.x, y - row_h * 0.45, rect.size.x, row_h * 0.9), CRYSTAL_GLOW)
		for beat: int in int(lines[row]):
			var at: Vector2 = Vector2(rect.position.x + dot * 3.0 + beat * dot * 3.0, y)
			canvas.draw_circle(at, dot, CRYSTAL if lit else DIM)
		if bool(visual.get("counts", false)) and font != null:
			_centered(canvas, font, Vector2(rect.end.x - dot * 3.0, y), str(int(lines[row])), SMALL_LABEL, CRYSTAL if lit else LINE)


static func _centered(canvas: CanvasItem, font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, center + Vector2(-width * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
