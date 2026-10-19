## The Alloy Mixer machine as WorkshopArt draws it (Zone 7's engineering project): two ore hoppers
## (copper, round lumps; tin, square lumps) over an electric mixing drum, and a rack of finished alloy
## bars. `phase` (0..1) turns the drum while the machine runs on the hub's shelf. Electric only: a
## motor with a lightning mark, never a flame, steam or smoke (CLAUDE.md content rules).
##   params {a, b, copper, tin, mixed}: the recipe a : b, the ore in each hopper, and whether the mix
##   is done (the drum glows and an alloy bar sits on the rack).
class_name AlloyMixerArt
extends RefCounted

const DRUM: Color = Color("#8A96B3")
const ALLOY: Color = Color("#E3B26B")


static func draw(canvas: CanvasItem, area: Vector2, params: Dictionary, phase: float) -> void:
	var copper: int = clampi(int(params.get("copper", 4)), 0, 40)
	var tin: int = clampi(int(params.get("tin", 6)), 0, 40)
	var mixed: bool = bool(params.get("mixed", false))
	for side: int in 2:
		var hopper: Rect2 = Rect2(Vector2(area.x * (0.04 + 0.26 * side), area.y * 0.06), Vector2(area.x * 0.22, area.y * 0.5))
		var funnel: PackedVector2Array = PackedVector2Array([hopper.position, Vector2(hopper.end.x, hopper.position.y), Vector2(hopper.end.x - hopper.size.x * 0.3, hopper.end.y), Vector2(hopper.position.x + hopper.size.x * 0.3, hopper.end.y)])
		canvas.draw_colored_polygon(funnel, Color("#56627F"))
		CrystalArt.draw_ore_mix(canvas, hopper.grow(-8.0), {"type": "ore_mix", "a": copper if side == 0 else 0, "b": 0 if side == 0 else tin})
		canvas.draw_line(Vector2(hopper.get_center().x, hopper.end.y), Vector2(area.x * 0.62, area.y * 0.62), WorkshopArt.STEEL, 4.0)
	var center: Vector2 = Vector2(area.x * 0.66, area.y * 0.68)
	var radius: float = minf(area.x * 0.12, area.y * 0.24)
	if mixed:
		canvas.draw_circle(center, radius * 1.25, Color(WorkshopArt.LIGHT, 0.25))
	canvas.draw_circle(center, radius, DRUM)
	canvas.draw_arc(center, radius, 0.0, TAU, 32, WorkshopArt.INK, 3.0)
	for spoke: int in 3:
		var angle: float = phase * TAU + TAU * spoke / 3.0
		canvas.draw_line(center, center + Vector2.from_angle(angle) * radius * 0.85, WorkshopArt.INK, 3.0)
	var bolt: Vector2 = center + Vector2(-radius * 1.5, radius * 0.4)
	canvas.draw_colored_polygon(PackedVector2Array([bolt + Vector2(-4, -12), bolt + Vector2(6, -12), bolt + Vector2(1, -2), bolt + Vector2(7, -2), bolt + Vector2(-5, 12), bolt + Vector2(-1, 1), bolt + Vector2(-7, 1)]), WorkshopArt.LIGHT)
	# The rack of alloy bars on the right.
	var rack: Rect2 = Rect2(Vector2(area.x * 0.82, area.y * 0.2), Vector2(area.x * 0.15, area.y * 0.7))
	canvas.draw_rect(rack, Color("#2A3352"))
	canvas.draw_rect(rack, WorkshopArt.STEEL, false, 2.0)
	var bars: int = 3 if mixed else 0
	for index: int in bars:
		var bar: Rect2 = Rect2(rack.position + Vector2(rack.size.x * 0.1, rack.size.y * (0.75 - 0.25 * index)), Vector2(rack.size.x * 0.8, rack.size.y * 0.16))
		canvas.draw_rect(bar, ALLOY)
		canvas.draw_rect(bar, WorkshopArt.INK, false, 2.0)
