## The Clockwork Vault as WorkshopArt draws it (Zone 10's engineering project): a round vault door with a dial of
## n marks, a pointer and a row of lamps. Solved (`open`), the pointer rests on the mark x, the lamp is lit, and
## as `phase` goes from 0 to 1 the door slides open on the hub's shelf. Electric only: lamps and a lightning mark,
## never steam or smoke (CLAUDE.md content rules).
##   params {n, x, open}: n marks on the dial, the pointer at x, whether the dial is set (the lamp lights).
## Draws without making strings or arrays (the hub redraws it every frame of the opening).
class_name ClockworkVaultArt
extends RefCounted

const DOOR: Color = Color("#4C5A7A")
const SLOT: Color = Color("#1B2236")


static func draw(canvas: CanvasItem, area: Vector2, params: Dictionary, phase: float) -> void:
	var marks: int = clampi(int(params.get("n", 6)), 2, 12)
	var open: bool = bool(params.get("open", false))
	var radius: float = minf(area.x, area.y) * 0.42
	var center: Vector2 = area * 0.5
	var slide: float = phase if open else 0.0
	# The doorway behind, then the door sliding aside.
	canvas.draw_rect(Rect2(center - Vector2(radius * 1.05, radius * 1.05), Vector2(radius * 2.1, radius * 2.1)), SLOT)
	var door_center: Vector2 = center + Vector2(radius * 2.0 * slide, 0.0)
	canvas.draw_circle(door_center, radius, DOOR)
	canvas.draw_arc(door_center, radius, 0.0, TAU, 48, WorkshopArt.INK, 3.0)
	canvas.draw_arc(door_center, radius * 0.7, 0.0, TAU, 48, WorkshopArt.STEEL, 3.0)
	for index: int in marks:
		var angle: float = -PI / 2.0 + TAU * float(index) / float(marks)
		var direction: Vector2 = Vector2.from_angle(angle)
		canvas.draw_line(door_center + direction * radius * 0.7, door_center + direction * radius * 0.82, WorkshopArt.LIGHT, 3.0)
	var pointer_angle: float = -PI / 2.0 + TAU * float(int(params.get("x", 0))) / float(marks)
	canvas.draw_line(door_center, door_center + Vector2.from_angle(pointer_angle) * radius * 0.62, WorkshopArt.LIGHT, 5.0)
	canvas.draw_circle(door_center, radius * 0.07, WorkshopArt.LIGHT)
	var lamp: Vector2 = door_center + Vector2(0.0, radius * 0.42)
	canvas.draw_circle(lamp, radius * 0.09, WorkshopArt.GOOD if open else WorkshopArt.STEEL)
	if open:
		canvas.draw_circle(lamp, radius * 0.2, Color(WorkshopArt.GOOD, 0.3))
