## Code-drawn art for Zone 12, The Infinite Core (no artist; Spiro's decision): the numbered cards of a proof
## (`statements`) and a number written on a card with the three nested number rings behind it (`number_card`). Static
## painters that draw on any CanvasItem inside a Rect2, so the problem picture (VisualModel), the proof builder, the
## number rings room and the mysteries room all look the same.
##
## A lit card or ring differs by an outline and a mark, never by color alone (accessibility rule). Lights are electric,
## never a flame. The picture fields are documented in scripts/core/problem.gd. The geometry (card_rect, ring_radii,
## decimal_text) is pure and tested; the painters only paint it.
class_name CoreArt
extends RefCounted

const OUTLINE: Color = Color("#1F2945")
const CARD: Color = Color("#F5F7FF")
const LIT: Color = Color("#FFD166")
const ARROW: Color = Color("#7BD88F")
const NUMBER: Color = Color("#7FC8F8")
const RING_INTEGER: Color = Color(0.48, 0.85, 0.56, 0.35)
const RING_RATIONAL: Color = Color(0.5, 0.78, 0.97, 0.25)
const RING_REAL: Color = Color(0.72, 0.62, 1.0, 0.2)
const DIM: Color = Color(1, 1, 1, 0.25)
const MAX_CARDS: int = 8
const BADGE: float = 0.7


## Draws any Zone 12 picture inside `rect`. Returns false for a picture type it does not know.
static func draw_visual(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> bool:
	match str(visual.get("type", "")):
		"statements":
			draw_statements(canvas, rect, visual, font)
		"number_card":
			draw_number_card(canvas, rect, visual, font)
		_:
			return false
	return true


static func _text(canvas: CanvasItem, font: Font, text: String, at: Vector2, size_px: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	canvas.draw_string(font, Vector2(at.x - text_size.x / 2.0, at.y + size_px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


# --- Proof cards ---------------------------------------------------------------------------------


## The box of card `index` (0 is the top one) of `count` cards stacked in `rect`, with a small gap between them.
static func card_rect(rect: Rect2, count: int, index: int) -> Rect2:
	var gap: float = 6.0 if count > 1 else 0.0
	var height: float = (rect.size.y - gap * float(count - 1)) / float(maxi(count, 1))
	return Rect2(rect.position.x, rect.position.y + float(index) * (height + gap), rect.size.x, height)


static func draw_statements(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var cards: Array = visual.get("cards", [])
	var lit: int = int(visual.get("lit", 0))
	var arrows: bool = bool(visual.get("arrows", false))
	for index: int in cards.size():
		var entry: Dictionary = cards[index]
		var box: Rect2 = card_rect(rect, cards.size(), index)
		var is_lit: bool = int(entry["n"]) == lit
		canvas.draw_rect(box, Color(1, 1, 1, 0.16 if is_lit else 0.08), true)
		canvas.draw_rect(box, LIT if is_lit else CARD, false, 4.0 if is_lit else 2.0)
		var badge: float = minf(box.size.y * BADGE, 44.0)
		var badge_center: Vector2 = Vector2(box.position.x + badge * 0.8, box.get_center().y)
		canvas.draw_circle(badge_center, badge / 2.0, LIT if is_lit else NUMBER)
		_text(canvas, font, str(int(entry["n"])), badge_center, maxi(roundi(badge * 0.7), 10), OUTLINE)
		var size_px: int = clampi(roundi(box.size.y * 0.42), 12, 28)
		var text_left: float = box.position.x + badge * 1.6
		var line: String = Text.get_line(StringName(str(entry["line_id"])))
		canvas.draw_multiline_string(font, Vector2(text_left, box.get_center().y - size_px * 0.35), line, HORIZONTAL_ALIGNMENT_LEFT,
			maxf(box.end.x - text_left - 8.0, 20.0), size_px, 2, CARD)
		if arrows and index < cards.size() - 1:
			var tip: Vector2 = Vector2(badge_center.x, box.end.y + 5.0)
			canvas.draw_line(Vector2(tip.x, box.end.y), tip, ARROW, 3.0)
			canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, -1), tip + Vector2(5, -1), tip + Vector2(0, 4)]), ARROW)


# --- Numbers and rings ---------------------------------------------------------------------------


## The radii of the integer, rational and real rings of a picture whose rings fit a circle of `radius`.
static func ring_radii(radius: float) -> Array[float]:
	return [radius * 0.38, radius * 0.7, radius]


## A decimal card's text: mantissa / 10^scale written with exactly `scale` digits after the point (0.05, not 0.5).
static func decimal_text(mantissa: int, scale: int) -> String:
	var digits: String = str(absi(mantissa))
	while digits.length() <= scale:
		digits = "0" + digits
	var text: String = digits.substr(0, digits.length() - scale) + "." + digits.substr(digits.length() - scale)
	return ("−" if mantissa < 0 else "") + text


## The word under a ring: which ring a `lit` name belongs to.
static func ring_line(ring: String) -> StringName:
	return StringName("z12.sets.ring_" + ring)


static func draw_number_card(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var rings: bool = bool(visual.get("rings", false))
	var card_area: Rect2 = rect
	if rings:
		var side: float = minf(rect.size.y, rect.size.x * 0.55)
		var center: Vector2 = Vector2(rect.end.x - side / 2.0 - 4.0, rect.get_center().y)
		var radii: Array[float] = ring_radii(side / 2.0 - 4.0)
		var colors: Array[Color] = [RING_INTEGER, RING_RATIONAL, RING_REAL]
		var names: Array[String] = ["integer", "rational", "real"]
		var lit: String = str(visual.get("lit", ""))
		for order: int in [2, 1, 0]:
			canvas.draw_circle(center, radii[order], colors[order])
			var is_lit: bool = names[order] == lit
			canvas.draw_arc(center, radii[order], 0.0, TAU, 48, LIT if is_lit else DIM, 4.0 if is_lit else 2.0)
		if lit != "":
			var index: int = names.find(lit)
			var inner: float = radii[index - 1] if index > 0 else 0.0
			var dot: Vector2 = center + Vector2(0.0, -(inner + radii[index]) / 2.0) if index > 0 else center
			canvas.draw_circle(dot, 9.0, LIT)
			canvas.draw_arc(dot, 9.0, 0.0, TAU, 16, OUTLINE, 2.0)
		card_area = Rect2(rect.position, Vector2(rect.size.x - side - 12.0, rect.size.y))
	var card: Vector2 = Vector2(minf(card_area.size.x - 8.0, 220.0), minf(card_area.size.y * 0.7, 120.0))
	var box: Rect2 = Rect2(card_area.get_center() - card / 2.0, card)
	canvas.draw_rect(box, Color(1, 1, 1, 0.1), true)
	canvas.draw_rect(box, CARD, false, 3.0)
	_draw_number(canvas, box, visual, font)


static func _draw_number(canvas: CanvasItem, box: Rect2, visual: Dictionary, font: Font) -> void:
	var a: int = int(visual.get("a", 0))
	var size_px: int = maxi(roundi(box.size.y * 0.5), 14)
	var center: Vector2 = box.get_center()
	match str(visual.get("form", "int")):
		"int":
			_text(canvas, font, ("−%d" % absi(a)) if a < 0 else str(a), center, size_px, CARD)
		"decimal":
			_text(canvas, font, decimal_text(a, int(visual.get("scale", 1))), center, size_px, CARD)
		"frac":
			var small: int = maxi(roundi(size_px * 0.8), 12)
			var width: float = maxf(font.get_string_size(str(absi(a)), HORIZONTAL_ALIGNMENT_LEFT, -1, small).x, font.get_string_size(str(visual.get("b", 2)), HORIZONTAL_ALIGNMENT_LEFT, -1, small).x) + 12.0
			_text(canvas, font, ("−%d" % absi(a)) if a < 0 else str(a), center + Vector2(0.0, -small * 0.65), small, CARD)
			canvas.draw_line(center + Vector2(-width / 2.0, 0.0), center + Vector2(width / 2.0, 0.0), CARD, 3.0)
			_text(canvas, font, str(int(visual.get("b", 2))), center + Vector2(0.0, small * 0.75), small, CARD)
		"root":
			var text: String = str(a)
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			var left: float = center.x - width / 2.0 - size_px * 0.5
			var top: float = center.y - size_px * 0.62
			var bottom: float = center.y + size_px * 0.55
			# The radical: a short tick, a long stroke down, a stroke up and the bar over the number.
			canvas.draw_polyline(PackedVector2Array([Vector2(left - size_px * 0.3, center.y + size_px * 0.1), Vector2(left, center.y + size_px * 0.2), Vector2(left + size_px * 0.18, bottom), Vector2(left + size_px * 0.42, top), Vector2(center.x + width / 2.0 + 4.0, top)]), CARD, 3.0)
			_text(canvas, font, text, Vector2(center.x + size_px * 0.2, center.y + size_px * 0.05), size_px, CARD)
