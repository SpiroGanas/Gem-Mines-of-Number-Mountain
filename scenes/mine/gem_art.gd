## Draws one gem from shapes, so the gray-box mine needs no image files.
##
## Gems differ by SHAPE as well as color (CLAUDE.md accessibility rule): quartz is a six-sided
## crystal point, garnet a round-cut stone, pyrite a cube, amethyst a tall prism. Shapes are
## in unit coordinates (0..1) and scaled to the control's size. The CC0 art pass in Sprint 10
## replaces this with real sprites.
##
## Godot note: a Control's _draw() runs when the control needs repainting; call
## queue_redraw() after changing anything that affects how it looks.
class_name GemArt
extends Control

const QUARTZ: StringName = &"quartz"
const GARNET: StringName = &"garnet"
const PYRITE: StringName = &"pyrite"
const AMETHYST: StringName = &"amethyst"
const ALL_TYPES: Array[StringName] = [QUARTZ, GARNET, PYRITE, AMETHYST]
const OUTLINE: Color = Color("#1F2945")
const OUTLINE_WIDTH: float = 3.0

@export var gem_type: StringName = QUARTZ:
	set(value):
		gem_type = value
		queue_redraw()


## The gem's outline in unit coordinates. A round gem returns a 16-sided polygon.
static func shape_points(type: StringName) -> PackedVector2Array:
	match type:
		QUARTZ: # six-sided crystal point
			return PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.82, 0.22), Vector2(0.82, 0.78), Vector2(0.5, 1.0), Vector2(0.18, 0.78), Vector2(0.18, 0.22)])
		GARNET: # round cut
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in 16:
				var angle: float = TAU * float(i) / 16.0
				points.append(Vector2(0.5 + 0.45 * cos(angle), 0.5 + 0.45 * sin(angle)))
			return points
		PYRITE: # cube seen from a corner
			return PackedVector2Array([Vector2(0.12, 0.34), Vector2(0.40, 0.08), Vector2(0.96, 0.08), Vector2(0.96, 0.66), Vector2(0.68, 0.94), Vector2(0.12, 0.94)])
		AMETHYST: # tall prism with a pointed top
			return PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.78, 0.2), Vector2(0.78, 0.88), Vector2(0.5, 1.0), Vector2(0.22, 0.88), Vector2(0.22, 0.2)])
	return PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.9, 0.9), Vector2(0.1, 0.9)])


static func color_for(type: StringName) -> Color:
	match type:
		QUARTZ:
			return Color("#9AD8F5")
		GARNET:
			return Color("#C0394B")
		PYRITE:
			return Color("#E0B84A")
		AMETHYST:
			return Color("#9B6BD6")
	return Color("#CCCCCC")


## The zone's gem: quartz in Zone 1, garnet in Zone 2, pyrite in Zone 3.
static func gem_for_zone(zone: int) -> StringName:
	match zone:
		2:
			return GARNET
		3:
			return PYRITE
	return QUARTZ


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var points: PackedVector2Array = shape_points(gem_type)
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * size)
	var fill: Color = color_for(gem_type)
	draw_colored_polygon(scaled, fill)
	# A lighter facet and an outline, so the shape reads on any background.
	var facet: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		facet.append((Vector2(0.5, 0.5) + (point - Vector2(0.5, 0.5)) * 0.5) * size)
	draw_colored_polygon(facet, fill.lightened(0.35))
	var outline: PackedVector2Array = scaled.duplicate()
	outline.append(scaled[0])
	draw_polyline(outline, OUTLINE, OUTLINE_WIDTH, true)
