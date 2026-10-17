## The scenery behind a screen, drawn in code (placeholder art pass, P1-S10-01): a calm vertical
## gradient, rock shapes along the edges and, underground, electric lamps on a cable (never flames:
## CLAUDE.md content rules). Each zone has its own tint so the three MVP zones look different:
## Pebble Meadow teal, the Quarry of Tens red-brown, the Skip-Count Caves purple with glowing
## crystals. Nothing moves: the screen stays quiet while the child thinks (GDD "Game feel").
class_name Backdrop
extends Control

const PALETTES: Dictionary = {
	&"workshop": {"top": Color("#34406A"), "bottom": Color("#1F2945"), "rock": Color("#2A3558"), "lamps": false, "crystals": false},
	&"zone1": {"top": Color("#2C4A58"), "bottom": Color("#1F2945"), "rock": Color("#35505C"), "lamps": true, "crystals": false},
	&"zone2": {"top": Color("#47323E"), "bottom": Color("#1F2945"), "rock": Color("#553B43"), "lamps": true, "crystals": false},
	&"zone3": {"top": Color("#37305F"), "bottom": Color("#1A1D3A"), "rock": Color("#3E3768"), "lamps": true, "crystals": true},
}
const LAMP_GLOW: Color = Color(1.0, 0.86, 0.45, 0.25)
const LAMP_BULB: Color = Color("#FFE9A8")
const CRYSTAL: Color = Color("#9B6BD6")

@export var palette: StringName = &"workshop":
	set(value):
		palette = value if PALETTES.has(value) else &"workshop"
		queue_redraw()


## The palette for a zone number (1 to 3; others fall back to Zone 1's).
static func palette_for_zone(zone: int) -> StringName:
	return StringName("zone%d" % clampi(zone, 1, 3))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func colors() -> Dictionary:
	return PALETTES[palette]


func _draw() -> void:
	var colors_now: Dictionary = colors()
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([colors_now["top"], colors_now["top"], colors_now["bottom"], colors_now["bottom"]]))
	var rock: Color = colors_now["rock"]
	# Rock shapes along the bottom and the two sides.
	draw_colored_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(0, s.y * 0.8), Vector2(s.x * 0.12, s.y * 0.86), Vector2(s.x * 0.22, s.y * 0.82), Vector2(s.x * 0.34, s.y * 0.9), Vector2(s.x * 0.5, s.y * 0.88), Vector2(s.x * 0.66, s.y * 0.92), Vector2(s.x * 0.8, s.y * 0.84), Vector2(s.x, s.y * 0.88), s]), rock)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x * 0.05, 0), Vector2(s.x * 0.03, s.y * 0.3), Vector2(s.x * 0.06, s.y * 0.55), Vector2(0, s.y * 0.7)]), rock)
	draw_colored_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x * 0.95, 0), Vector2(s.x * 0.97, s.y * 0.35), Vector2(s.x * 0.94, s.y * 0.6), Vector2(s.x, s.y * 0.75)]), rock)
	if colors_now["lamps"]:
		draw_line(Vector2(0, s.y * 0.04), Vector2(s.x, s.y * 0.06), rock.lightened(0.3), 3.0)
		for index: int in 5:
			var at: Vector2 = Vector2(s.x * (0.1 + 0.2 * index), s.y * (0.045 + 0.004 * index))
			draw_circle(at + Vector2(0, 18), 36.0, LAMP_GLOW)
			draw_line(at, at + Vector2(0, 10), rock.lightened(0.3), 2.0)
			draw_circle(at + Vector2(0, 18), 9.0, LAMP_BULB) # an electric bulb
	if colors_now["crystals"]:
		for index: int in 7:
			var base: Vector2 = Vector2(s.x * (0.07 + 0.14 * index), s.y * (0.9 - 0.02 * (index % 3)))
			var height: float = s.y * (0.05 + 0.02 * (index % 2))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 0), base + Vector2(0, -height), base + Vector2(12, 0)]), Color(CRYSTAL, 0.8))
