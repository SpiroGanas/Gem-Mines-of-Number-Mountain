## Draws a problem's visual: piles of hundred-blocks, ten-bars and one-gems (`gem_piles`),
## ten-frames (`ten_frame`) and number lines (`number_line`). Gray-box shapes in code.
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
const COMPACT_SCALE: float = 0.6

var visual: Dictionary = {}
var tappable: bool = false
## A smaller picture (hint pictures added above an input), COMPACT_SCALE of the normal height.
var compact: bool = false

var _buttons: Array[Button] = []


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


# --- Drawing ---------------------------------------------------------------------------------


func _draw() -> void:
	match visual_type():
		&"gem_piles":
			_draw_piles()
		&"ten_frame":
			_draw_ten_frames()
		&"number_line":
			_draw_number_line()


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
	for index: int in cells.size():
		draw_rect(cells[index], FRAME_COLOR, false, 3.0)
		if index < count:
			draw_circle(cells[index].get_center(), cells[index].size.x * 0.34, DOT_COLOR)


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
