## Code-drawn art for Zone 11, Cipher Vault (no artist; Spiro's decision): letters on cards (`cipher`, with a
## cipher wheel when the shift is known), the bars and steps of the Euclid machine (`euclid`) and the coins and
## total of a coin puzzle (`coins`). Static painters that draw on any CanvasItem inside a Rect2, so the problem
## picture (VisualModel), the cipher wheel, the coin puzzle and the Euclid machine all look the same.
##
## Letters are on cards and the wheel's two rings differ in position, size and color, so color is never the only clue
## (accessibility rule). Lights are electric, never a flame. The picture fields are documented in
## scripts/core/problem.gd. The geometry (wheel_point, bar_lengths, ladder_lines) is pure and tested.
class_name VaultArt
extends RefCounted

const OUTLINE: Color = Color("#1F2945")
const CARD: Color = Color("#F5F7FF")
const OUTER: Color = Color("#F5F7FF")
const INNER: Color = Color("#FFD166")
const NUMBER: Color = Color("#7FC8F8")
const BAR_A: Color = Color("#FFD166")
const BAR_B: Color = Color("#7FC8F8")
const STEP: Color = Color("#7BD88F")
const DIM: Color = Color(1, 1, 1, 0.25)
const COIN_A: Color = Color("#FFD166")
const COIN_B: Color = Color("#B79CFF")
const ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## Draws any Zone 11 picture inside `rect`. Returns false for a picture type it does not know.
static func draw_visual(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> bool:
	match str(visual.get("type", "")):
		"cipher":
			draw_cipher(canvas, rect, visual, font)
		"euclid":
			draw_euclid(canvas, rect, visual, font)
		"coins":
			draw_coins(canvas, rect, visual, font)
		_:
			return false
	return true


static func _text(canvas: CanvasItem, font: Font, text: String, at: Vector2, size_px: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	canvas.draw_string(font, Vector2(at.x - text_size.x / 2.0, at.y + size_px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


# --- Cipher cards and wheel ----------------------------------------------------------------------


## Where letter `index` of a wheel ring sits: A at the top, the rest clockwise.
static func wheel_point(center: Vector2, radius: float, index: int) -> Vector2:
	var angle: float = -PI / 2.0 + TAU * float(index) / 26.0
	return center + Vector2(cos(angle), sin(angle)) * radius


## The letter on the inner ring at position `index` when the wheel is set to `shift`: the plain letter under it is
## `index`, the code letter is `index + shift`.
static func inner_letter(index: int, shift: int) -> String:
	return ALPHABET[posmod(index + shift, 26)]


## The wheel: plain letters on the outer ring, code letters on the inner ring turned by `shift` places.
static func draw_wheel(canvas: CanvasItem, center: Vector2, radius: float, shift: int, font: Font) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, 64, DIM, 2.0)
	canvas.draw_arc(center, radius * 0.7, 0.0, TAU, 64, DIM, 2.0)
	var outer_size: int = maxi(roundi(radius * 0.13), 8)
	var inner_size: int = maxi(roundi(radius * 0.11), 7)
	for index: int in 26:
		_text(canvas, font, ALPHABET[index], wheel_point(center, radius * 0.86, index), outer_size, OUTER)
		_text(canvas, font, inner_letter(index, shift), wheel_point(center, radius * 0.58, index), inner_size, INNER)
	canvas.draw_line(center + Vector2(0.0, -radius * 0.72), center + Vector2(0.0, -radius * 1.02), STEP, 3.0) # the A mark


static func draw_cipher(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var text: String = str(visual.get("text", ""))
	var shift: int = int(visual.get("shift", -1))
	var numbers: bool = bool(visual.get("numbers", false))
	var cards_rect: Rect2 = rect
	if shift >= 0:
		var side: float = minf(rect.size.y, rect.size.x * 0.5)
		draw_wheel(canvas, Vector2(rect.position.x + side / 2.0, rect.get_center().y), side / 2.0 - 4.0, shift, font)
		cards_rect = Rect2(rect.position + Vector2(side + 8.0, 0.0), rect.size - Vector2(side + 8.0, 0.0))
	var count: int = maxi(text.length(), 1)
	var card: float = minf(minf(cards_rect.size.y * (0.5 if numbers else 0.6), (cards_rect.size.x - 8.0 * count) / float(count)), 72.0)
	var row_width: float = count * (card + 8.0) - 8.0
	var left: float = cards_rect.get_center().x - row_width / 2.0
	var top: float = cards_rect.get_center().y - card / 2.0 - (card * 0.2 if numbers else 0.0)
	for index: int in text.length():
		var box: Rect2 = Rect2(left + index * (card + 8.0), top, card, card)
		canvas.draw_rect(box, Color(1, 1, 1, 0.1), true)
		canvas.draw_rect(box, CARD, false, 3.0)
		_text(canvas, font, text[index], box.get_center(), maxi(roundi(card * 0.6), 12), CARD)
		if numbers:
			_text(canvas, font, str(ALPHABET.find(text[index])), Vector2(box.get_center().x, box.end.y + card * 0.3), maxi(roundi(card * 0.34), 10), NUMBER)


# --- The Euclid machine --------------------------------------------------------------------------


## The two bar lengths in pixels for a bar of `a` and a bar of `b` units when the long bar is `longest` pixels.
static func bar_lengths(a: int, b: int, longest: float) -> Vector2:
	var most: float = float(maxi(maxi(a, b), 1))
	return Vector2(longest * float(a) / most, longest * float(b) / most)


## The steps written out, "48 = 2 × 18 + 12", for the first `upto` steps (-1: all). Empty when upto is 0.
static func ladder_lines(a: int, b: int, upto: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var rows: Array[Dictionary] = EuclidGenerator.steps(a, b)
	var shown: int = rows.size() if upto < 0 else mini(upto, rows.size())
	for index: int in shown:
		var row: Dictionary = rows[index]
		lines.append("%d = %d × %d + %d" % [row["a"], row["q"], row["b"], row["r"]])
	return lines


static func draw_euclid(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var a: int = int(visual.get("a", 2))
	var b: int = int(visual.get("b", 2))
	var upto: int = int(visual.get("upto", -1))
	var lines: PackedStringArray = ladder_lines(a, b, upto)
	var bars_width: float = rect.size.x * (0.46 if not lines.is_empty() else 0.8)
	var lengths: Vector2 = bar_lengths(a, b, bars_width)
	var bar_h: float = minf(rect.size.y * 0.16, 30.0)
	var left: float = rect.position.x + (rect.size.x * (0.0 if not lines.is_empty() else 0.1))
	var top: float = rect.get_center().y - bar_h * 1.4
	canvas.draw_rect(Rect2(left, top, lengths.x, bar_h), BAR_A, true)
	canvas.draw_rect(Rect2(left, top, lengths.x, bar_h), OUTLINE, false, 2.0)
	canvas.draw_rect(Rect2(left, top + bar_h * 1.6, lengths.y, bar_h), BAR_B, true)
	canvas.draw_rect(Rect2(left, top + bar_h * 1.6, lengths.y, bar_h), OUTLINE, false, 2.0)
	var label_size: int = maxi(roundi(bar_h * 0.8), 12)
	_text(canvas, font, str(a), Vector2(left + lengths.x / 2.0, top + bar_h / 2.0), label_size, OUTLINE)
	_text(canvas, font, str(b), Vector2(left + lengths.y / 2.0, top + bar_h * 2.1), label_size, OUTLINE)
	if not lines.is_empty():
		var line_h: float = minf(rect.size.y / float(lines.size() + 1), 40.0)
		var text_size: int = maxi(roundi(line_h * 0.6), 11)
		var x: float = rect.position.x + rect.size.x * 0.74
		var y: float = rect.get_center().y - line_h * float(lines.size() - 1) / 2.0
		for index: int in lines.size():
			_text(canvas, font, lines[index], Vector2(x, y + index * line_h), text_size, STEP if index == lines.size() - 1 else CARD)


# --- Coins ---------------------------------------------------------------------------------------


static func draw_coins(canvas: CanvasItem, rect: Rect2, visual: Dictionary, font: Font) -> void:
	var radius: float = minf(rect.size.y * 0.3, 44.0)
	var y: float = rect.get_center().y
	var x: float = rect.get_center().x - radius * 4.2
	for entry: Array in [[int(visual.get("a", 2)), COIN_A, 0], [int(visual.get("b", 2)), COIN_B, 1]]:
		var at: Vector2 = Vector2(x + radius * 2.6 * float(entry[2]), y)
		canvas.draw_circle(at, radius, entry[1])
		canvas.draw_arc(at, radius, 0.0, TAU, 32, OUTLINE, 3.0)
		_text(canvas, font, str(entry[0]), at, maxi(roundi(radius * 0.9), 12), OUTLINE)
	_text(canvas, font, "=", Vector2(x + radius * 5.2, y), maxi(roundi(radius * 0.9), 12), CARD)
	var total_box: Rect2 = Rect2(x + radius * 6.0, y - radius, radius * 3.0, radius * 2.0)
	canvas.draw_rect(total_box, Color(1, 1, 1, 0.1), true)
	canvas.draw_rect(total_box, CARD, false, 3.0)
	_text(canvas, font, str(int(visual.get("c", 0))), total_box.get_center(), maxi(roundi(radius * 0.9), 12), CARD)
