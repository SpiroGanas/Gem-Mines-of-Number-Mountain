## Code-drawn gears for Zone 6 (Sprint 31 art pass, no artist): a toothed steel wheel with a hub, its
## tooth count in the middle, an optional marked tooth (the "marks" that line up again) and shaded teeth
## (simplest form). The gear bench, the problem pictures (VisualModel `gears`) and the Conveyor Sync
## machine (WorkshopArt) all draw through this, so a gear looks the same everywhere.
##
## One GearArt per drawing node: it keeps its point buffers and refills them in place, so a gear that
## spins (redrawn every frame by a tween) never allocates while it draws. The motor is electric: there is
## no steam or smoke anywhere (CLAUDE.md content rules).
##
## Accessibility: gears differ by their tooth-count label, not by color alone; the marked tooth is a
## ringed dot and the shaded teeth are filled and outlined.
class_name GearArt
extends RefCounted

const BODY: Color = Color("#B8C2D9")
const EDGE: Color = Color("#1F2945")
const HUB: Color = Color("#8A96B3")
const MARK: Color = Color("#FFD166")
const SHADE: Color = Color("#7BD88F")
const LABEL: Color = Color("#1F2945")
## A gear with more teeth than this is drawn with this many (its label still says how many it has).
const MAX_DRAWN_TEETH: int = 60
## A 12-tooth gear has radius `unit`; others grow with the square root of their teeth, within these.
const MIN_RADIUS_SCALE: float = 0.6
const MAX_RADIUS_SCALE: float = 2.4
## The four corners of one tooth, as fractions of the angle between teeth.
const TOOTH_RISE: float = 0.12
const TOOTH_TOP_START: float = 0.22
const TOOTH_TOP_END: float = 0.5
const TOOTH_FALL: float = 0.6

var _outline: PackedVector2Array = PackedVector2Array()
var _tooth: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## The radius of a gear with `teeth` teeth when a 12-tooth gear has radius `unit`. Pure.
static func radius_for(teeth: int, unit: float) -> float:
	return unit * clampf(sqrt(float(maxi(teeth, 1)) / 12.0), MIN_RADIUS_SCALE, MAX_RADIUS_SCALE)


## How many teeth are drawn for a gear of `teeth`. Pure.
static func drawn_teeth(teeth: int) -> int:
	return clampi(teeth, 2, MAX_DRAWN_TEETH)


## The outline of a gear centered at `center`, turned by `angle`: four points per tooth, refilled in
## place. Returns the buffer (owned by this GearArt).
func outline(center: Vector2, radius: float, teeth: int, angle: float) -> PackedVector2Array:
	var drawn: int = drawn_teeth(teeth)
	if _outline.size() != drawn * 4:
		_outline.resize(drawn * 4) # only when the gear changes, never while it spins
	var step: float = TAU / float(drawn)
	var depth: float = minf(radius * 0.2, radius * step * 0.6)
	for index: int in drawn:
		var base: float = angle + step * float(index)
		_outline[index * 4] = center + Vector2.from_angle(base + step * TOOTH_RISE) * (radius - depth)
		_outline[index * 4 + 1] = center + Vector2.from_angle(base + step * TOOTH_TOP_START) * radius
		_outline[index * 4 + 2] = center + Vector2.from_angle(base + step * TOOTH_TOP_END) * radius
		_outline[index * 4 + 3] = center + Vector2.from_angle(base + step * TOOTH_FALL) * (radius - depth)
	return _outline


## Draws one gear on `canvas` (call from its _draw). `label` is the tooth count as text (cached by the
## caller, so drawing a spinning gear makes no new strings); `shaded` fills that many teeth; `marked`
## draws the marked tooth (tooth 0).
func draw(canvas: CanvasItem, center: Vector2, radius: float, teeth: int, angle: float, label: String, shaded: int = 0, marked: bool = false, body: Color = BODY) -> void:
	var points: PackedVector2Array = outline(center, radius, teeth, angle)
	canvas.draw_colored_polygon(points, body)
	var drawn: int = drawn_teeth(teeth)
	for index: int in mini(shaded, drawn):
		_tooth[0] = points[index * 4]
		_tooth[1] = points[index * 4 + 1]
		_tooth[2] = points[index * 4 + 2]
		_tooth[3] = points[index * 4 + 3]
		canvas.draw_colored_polygon(_tooth, SHADE)
		canvas.draw_polyline(_tooth, EDGE, 2.0)
	canvas.draw_polyline(points, EDGE, 2.0, true)
	canvas.draw_line(points[points.size() - 1], points[0], EDGE, 2.0, true)
	var hub: float = radius * 0.42
	canvas.draw_circle(center, hub, HUB)
	canvas.draw_arc(center, hub, 0.0, TAU, 24, EDGE, 2.0, true)
	if marked:
		var step: float = TAU / float(drawn)
		var spot: Vector2 = center + Vector2.from_angle(angle + step * 0.36) * (radius * 0.72)
		canvas.draw_circle(spot, maxf(radius * 0.1, 4.0), MARK)
		canvas.draw_arc(spot, maxf(radius * 0.1, 4.0), 0.0, TAU, 16, EDGE, 2.0, true)
	if label != "":
		var font: Font = (canvas as Control).get_theme_default_font() if canvas is Control else ThemeDB.fallback_font
		var font_size: int = clampi(int(hub * 0.9), 12, 48)
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		canvas.draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LABEL)
