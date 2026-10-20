## The Vault Door as WorkshopArt draws it (Zone 11's engineering project): a tall round-topped door with a lock plate
## showing the code in letter cards; solved, the plate shows the word it hid, the lamp lights and, as `phase` goes from
## 0 to 1, the door swings open on the hub's shelf. Electric only: a lamp and a lightning mark, never steam or smoke
## (CLAUDE.md content rules).
##   params {code, word, open}: the coded word on the plate, the word it hid (shown when open), whether it is open.
## Draws only a few strings (the plate), so the hub's per-frame redraw stays cheap.
class_name VaultDoorArt
extends RefCounted

const DOOR: Color = Color("#4C5A7A")
const SLOT: Color = Color("#1B2236")


static func draw(canvas: CanvasItem, area: Vector2, params: Dictionary, phase: float) -> void:
	var open: bool = bool(params.get("open", false))
	var frame: Rect2 = Rect2(Vector2(area.x * 0.3, area.y * 0.08), Vector2(area.x * 0.4, area.y * 0.84))
	canvas.draw_rect(frame, SLOT)
	var swing: float = phase if open else 0.0
	var door: Rect2 = Rect2(frame.position, Vector2(frame.size.x * (1.0 - 0.8 * swing), frame.size.y))
	canvas.draw_rect(door, DOOR)
	canvas.draw_rect(door, WorkshopArt.INK, false, 3.0)
	var plate: Rect2 = Rect2(door.position + Vector2(door.size.x * 0.15, door.size.y * 0.25), Vector2(door.size.x * 0.7, door.size.y * 0.22))
	canvas.draw_rect(plate, Color(1, 1, 1, 0.12))
	var text: String = str(params.get("word", "")) if open and swing < 0.5 else str(params.get("code", ""))
	var font: Font = ThemeDB.fallback_font
	var font_size: int = clampi(roundi(plate.size.y * 0.7), 10, 40)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, Vector2(plate.get_center().x - text_size.x / 2.0, plate.get_center().y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, WorkshopArt.LIGHT)
	var lamp: Vector2 = door.position + Vector2(door.size.x * 0.5, door.size.y * 0.6)
	canvas.draw_circle(lamp, minf(door.size.x, door.size.y) * 0.07, WorkshopArt.GOOD if open else WorkshopArt.STEEL)
	if open:
		canvas.draw_circle(lamp, minf(door.size.x, door.size.y) * 0.14, Color(WorkshopArt.GOOD, 0.3))
