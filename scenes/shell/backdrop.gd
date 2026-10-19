## The scenery behind a screen, drawn in code (placeholder art pass, P1-S10-01): a calm vertical
## gradient, rock shapes along the edges and, underground, electric lamps on a cable (never flames:
## CLAUDE.md content rules). Each zone has its own tint so the three MVP zones look different:
## Pebble Meadow teal, the Quarry of Tens red-brown, the Skip-Count Caves purple with glowing
## crystals. Nothing moves: the screen stays quiet while the child thinks (GDD "Game feel").
##
## Sprint 20 art pass (Kenney CC0, no artist): Zone 4 (Factor Workshop, steel blue with gears of
## light) and Zone 5 (Prime Caverns, deep green with glowing crystals) get their own tints;
## underground, Kenney stalactites and stalagmites line the top and bottom edges, tinted to the zone's
## rock; the surface workshop's key art is Number Mountain itself, drawn in code: its silhouette
## behind the hub with the mine's door glowing with electric light at its foot.
##
## Phase 4: Zone 7 (Crystal Shards) is deep teal-violet with glowing crystals in a cooler blue. A zone
## without its own palette takes the deepest one before it.
class_name Backdrop
extends Control

const PALETTES: Dictionary = {
	&"workshop": {"top": Color("#34406A"), "bottom": Color("#1F2945"), "rock": Color("#2A3558"), "lamps": false, "crystals": false},
	&"zone1": {"top": Color("#2C4A58"), "bottom": Color("#1F2945"), "rock": Color("#35505C"), "lamps": true, "crystals": false},
	&"zone2": {"top": Color("#47323E"), "bottom": Color("#1F2945"), "rock": Color("#553B43"), "lamps": true, "crystals": false},
	&"zone3": {"top": Color("#37305F"), "bottom": Color("#1A1D3A"), "rock": Color("#3E3768"), "lamps": true, "crystals": true},
	&"zone4": {"top": Color("#2B3F5C"), "bottom": Color("#1A2238"), "rock": Color("#34486A"), "lamps": true, "crystals": false},
	&"zone5": {"top": Color("#23453F"), "bottom": Color("#141F2A"), "rock": Color("#2C5049"), "lamps": true, "crystals": true},
	&"zone7": {"top": Color("#2A3B63"), "bottom": Color("#141A30"), "rock": Color("#33446F"), "lamps": true, "crystals": true, "crystal_color": Color("#8FE3FF")},
}
## Zones past the last one that has art fall back to it.
const LAST_ZONE: int = 12
const STALACTITES_PATH: String = "res://assets/art/kenney/cave/stalactites.png"
const STALAGMITES_PATH: String = "res://assets/art/kenney/cave/stalagmites.png"
## How tall the edge tiles are drawn, as a share of the screen height.
const EDGE_HEIGHT: float = 0.07

static var _textures: Dictionary = {}
const LAMP_GLOW: Color = Color(1.0, 0.86, 0.45, 0.25)
const LAMP_BULB: Color = Color("#FFE9A8")
const CRYSTAL: Color = Color("#9B6BD6")

## The hub sets this: Number Mountain is the hub's key art, not every surface screen's.
@export var key_art: bool = false:
	set(value):
		key_art = value
		queue_redraw()
@export var palette: StringName = &"workshop":
	set(value):
		palette = value if PALETTES.has(value) else &"workshop"
		queue_redraw()


## The palette for a zone number: its own, or the deepest zone's before it that has one (zones
## below 1 take Zone 1's).
static func palette_for_zone(zone: int) -> StringName:
	for candidate: int in range(clampi(zone, 1, LAST_ZONE), 0, -1):
		var name: StringName = StringName("zone%d" % candidate)
		if PALETTES.has(name):
			return name
	return &"zone1"


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


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
	if colors_now["lamps"]:
		_draw_edge(_texture(STALACTITES_PATH), 0.0, rock.lightened(0.15))
		_draw_edge(_texture(STALAGMITES_PATH), s.y * (1.0 - EDGE_HEIGHT), rock.lightened(0.1))
	elif key_art:
		_draw_mountain(rock)
	if colors_now["crystals"]:
		for index: int in 7:
			var base: Vector2 = Vector2(s.x * (0.07 + 0.14 * index), s.y * (0.9 - 0.02 * (index % 3)))
			var height: float = s.y * (0.05 + 0.02 * (index % 2))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 0), base + Vector2(0, -height), base + Vector2(12, 0)]), Color(colors_now.get("crystal_color", CRYSTAL), 0.8))


## A row of edge tiles across the screen at `y`, tinted to the zone's rock.
func _draw_edge(tile: Texture2D, y: float, tint: Color) -> void:
	if tile == null:
		return
	var height: float = size.y * EDGE_HEIGHT
	var width: float = height * tile.get_width() / float(tile.get_height())
	var x: float = 0.0
	while x < size.x:
		draw_texture_rect(tile, Rect2(Vector2(x, y), Vector2(width, height)), false, tint)
		x += width


## Number Mountain behind the hub: two peaks, a snow-free rocky top, and the mine's arched door at its
## foot lit by an electric lamp.
func _draw_mountain(rock: Color) -> void:
	var s: Vector2 = size
	var far: Color = rock.lightened(0.08)
	draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.08, s.y * 0.86), Vector2(s.x * 0.36, s.y * 0.2), Vector2(s.x * 0.47, s.y * 0.34), Vector2(s.x * 0.6, s.y * 0.12), Vector2(s.x * 0.94, s.y * 0.86)]), far)
	draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.33, s.y * 0.27), Vector2(s.x * 0.36, s.y * 0.2), Vector2(s.x * 0.4, s.y * 0.26), Vector2(s.x * 0.37, s.y * 0.25)]), far.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.56, s.y * 0.19), Vector2(s.x * 0.6, s.y * 0.12), Vector2(s.x * 0.65, s.y * 0.2), Vector2(s.x * 0.61, s.y * 0.18)]), far.lightened(0.15))
	var door: Vector2 = Vector2(s.x * 0.5, s.y * 0.86)
	var radius: float = s.y * 0.06
	draw_circle(door + Vector2(0, -radius * 1.2), radius * 1.7, Color(LAMP_GLOW, 0.18))
	draw_rect(Rect2(door + Vector2(-radius, -radius), Vector2(radius * 2.0, radius)), LAMP_BULB.darkened(0.25))
	draw_circle(door + Vector2(0, -radius), radius, LAMP_BULB.darkened(0.25))
	draw_circle(door + Vector2(0, -radius * 2.4), radius * 0.25, LAMP_BULB)
