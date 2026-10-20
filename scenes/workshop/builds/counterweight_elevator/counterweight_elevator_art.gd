## The Counterweight Elevator as WorkshopArt draws it (Zone 8's engineering project): a tall shaft in the
## Power Tower, a beam on a pivot at the top, Bolt's cab hanging from one end and the counterweight from
## the other. Balanced (weight × distance the same on both sides), the cab rides up the shaft as `phase`
## goes from 0 to 1 while the machine runs on the hub's shelf. Electric only: lamps on the floors and a
## motor with a lightning mark, never steam or smoke (CLAUDE.md content rules).
##   params {w, d, r, x, balanced}: the cab's weight w at d steps, the counterweight x at r steps, and
##   whether the beam is balanced (the cab rides).
## Draws without making strings or arrays (the hub redraws it every frame of the ride).
class_name CounterweightElevatorArt
extends RefCounted

const SHAFT: Color = Color("#2A3352")


static func draw(canvas: CanvasItem, area: Vector2, params: Dictionary, phase: float) -> void:
	var balanced: bool = bool(params.get("balanced", false))
	var left_d: int = clampi(int(params.get("d", 2)), 1, 8)
	var right_d: int = clampi(int(params.get("r", 4)), 1, 8)
	var cab_weight: int = int(params.get("w", 8))
	var counter: int = int(params.get("x", 0))
	var shaft: Rect2 = Rect2(Vector2(area.x * 0.08, area.y * 0.18), Vector2(area.x * 0.26, area.y * 0.78))
	canvas.draw_rect(shaft, SHAFT)
	canvas.draw_rect(shaft, WorkshopArt.STEEL, false, 2.0)
	for index: int in 5:
		var y: float = shaft.end.y - shaft.size.y * 0.2 * float(index) - 6.0
		canvas.draw_line(Vector2(shaft.position.x, y), Vector2(shaft.end.x, y), Color(1, 1, 1, 0.15), 2.0)
		canvas.draw_circle(Vector2(shaft.position.x + 10.0, y - 10.0), 4.0, WorkshopArt.LIGHT)
	# The beam on its pivot above the shaft and the counterweight's side.
	var pivot: Vector2 = Vector2(area.x * 0.55, area.y * 0.12)
	var tilt: float = 0.0 if balanced else (-PowerArt.LEVER_TILT if cab_weight * left_d > counter * right_d else PowerArt.LEVER_TILT)
	var half: float = area.x * 0.36
	var cab_hook: Vector2 = PowerArt.hook_point(pivot, half, -left_d, tilt)
	var weight_hook: Vector2 = PowerArt.hook_point(pivot, half, right_d, tilt)
	canvas.draw_line(PowerArt.hook_point(pivot, half, -8, tilt), PowerArt.hook_point(pivot, half, 8, tilt), WorkshopArt.STEEL, 6.0)
	canvas.draw_circle(pivot, 8.0, WorkshopArt.INK)
	# The cab rides up the shaft when balanced; the cable runs from the beam to it.
	var ride: float = phase if balanced else 0.0
	var cab_y: float = lerpf(shaft.end.y - area.y * 0.12, shaft.position.y + area.y * 0.12, ride)
	var cab_center: Vector2 = Vector2(shaft.get_center().x, cab_y)
	canvas.draw_line(cab_hook, Vector2(cab_center.x, cab_hook.y), WorkshopArt.RAIL, 2.0)
	canvas.draw_line(Vector2(cab_center.x, cab_hook.y), cab_center, WorkshopArt.RAIL, 2.0)
	PowerArt.draw_cab(canvas, cab_center, minf(shaft.size.x * 0.7, area.y * 0.2))
	# The counterweight: stacked blocks, one per 4 weight (at most 8).
	var blocks: int = clampi(ceili(counter / 4.0), 0, 8)
	var block: Vector2 = Vector2(area.x * 0.08, area.y * 0.06)
	canvas.draw_line(weight_hook, weight_hook + Vector2(0, area.y * 0.1), WorkshopArt.RAIL, 2.0)
	for index: int in blocks:
		var top_left: Vector2 = weight_hook + Vector2(-block.x * 0.5, area.y * 0.1 + block.y * float(index))
		canvas.draw_rect(Rect2(top_left, block), PowerArt.WEIGHT)
		canvas.draw_rect(Rect2(top_left, block), WorkshopArt.INK, false, 1.5)
	if balanced:
		canvas.draw_circle(pivot, 16.0, Color(WorkshopArt.LIGHT, 0.35))
