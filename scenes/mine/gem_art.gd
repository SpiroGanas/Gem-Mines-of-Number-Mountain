## Draws one gem from shapes, so the gray-box mine needs no image files.
##
## Gems differ by SHAPE as well as color (CLAUDE.md accessibility rule): quartz is a six-sided
## crystal point, garnet a round-cut stone, pyrite a cube, amethyst a tall prism, and the six
## museum minerals each have their own outline (malachite a banded oval, fluorite an octahedron,
## hematite a rounded lump, calcite a rhombohedron, topaz a long crystal with a flat top,
## obsidian a sharp shard). Shapes are in unit coordinates (0..1) and scaled to the control's size.
##
## Godot note: a Control's _draw() runs when the control needs repainting; call
## queue_redraw() after changing anything that affects how it looks.
class_name GemArt
extends Control

const QUARTZ: StringName = &"quartz"
const GARNET: StringName = &"garnet"
const PYRITE: StringName = &"pyrite"
const AMETHYST: StringName = &"amethyst"
const MALACHITE: StringName = &"malachite"
const FLUORITE: StringName = &"fluorite"
const HEMATITE: StringName = &"hematite"
const CALCITE: StringName = &"calcite"
const TOPAZ: StringName = &"topaz"
const OBSIDIAN: StringName = &"obsidian"
## The rare gems of Zones 4 and 5. They come from rare NUMBERS, never from chance (CLAUDE.md rule 9):
## a prime, a twin prime, a Mersenne prime or a perfect square (RewardsRules.gem_for_value). Each has
## its own outline as well as its own color.
const PRIME: StringName = &"prime_gem"
const TWIN: StringName = &"twin_gem"
const MERSENNE: StringName = &"mersenne_gem"
const SQUARE: StringName = &"square_gem"
const RARE_TYPES: Array[StringName] = [PRIME, TWIN, MERSENNE, SQUARE]
## The weekly Deep Dig's special gem (Sprint 19): a geode split open, earned by finishing the dig.
const GEODE: StringName = &"geode"
## The ten Gem Museum minerals, in the museum's order.
const ALL_TYPES: Array[StringName] = [QUARTZ, GARNET, PYRITE, AMETHYST, MALACHITE, FLUORITE, HEMATITE, CALCITE, TOPAZ, OBSIDIAN]
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
		MALACHITE: # wide oval (its stripes are drawn on top)
			var oval: PackedVector2Array = PackedVector2Array()
			for i: int in 20:
				var angle: float = TAU * float(i) / 20.0
				oval.append(Vector2(0.5 + 0.48 * cos(angle), 0.5 + 0.32 * sin(angle)))
			return oval
		FLUORITE: # octahedron: a diamond with a ridge
			return PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.92, 0.5), Vector2(0.5, 1.0), Vector2(0.08, 0.5)])
		HEMATITE: # rounded lump of three bumps
			var lump: PackedVector2Array = PackedVector2Array()
			for i: int in 24:
				var angle: float = TAU * float(i) / 24.0
				var radius: float = 0.36 + 0.08 * cos(3.0 * angle)
				lump.append(Vector2(0.5 + radius * cos(angle), 0.52 + radius * sin(angle)))
			return lump
		CALCITE: # rhombohedron: a leaning box
			return PackedVector2Array([Vector2(0.3, 0.1), Vector2(0.95, 0.1), Vector2(0.7, 0.9), Vector2(0.05, 0.9)])
		TOPAZ: # long crystal with a flat top
			return PackedVector2Array([Vector2(0.32, 0.05), Vector2(0.68, 0.05), Vector2(0.8, 0.2), Vector2(0.8, 0.85), Vector2(0.5, 1.0), Vector2(0.2, 0.85), Vector2(0.2, 0.2)])
		OBSIDIAN: # sharp shard
			return PackedVector2Array([Vector2(0.45, 0.0), Vector2(0.95, 0.62), Vector2(0.6, 1.0), Vector2(0.05, 0.78)])
		PRIME: # a four-pointed star: "unbreakable"
			return _star(4, 0.5, 0.2)
		MERSENNE: # an eight-pointed burst: the rarest
			return _star(8, 0.5, 0.3)
		TWIN: # a peanut: two lobes joined, because twin primes come as a pair
			var peanut: PackedVector2Array = PackedVector2Array()
			for i: int in 24:
				var angle: float = TAU * float(i) / 24.0
				peanut.append(Vector2(0.5 + 0.48 * cos(angle), 0.5 + 0.3 * sin(angle) * (0.55 + 0.45 * cos(angle) * cos(angle))))
			return peanut
		GEODE: # a geode split open: a round bottom and a jagged crystal top
			var geode: PackedVector2Array = PackedVector2Array()
			for i: int in 9:
				var angle: float = PI * float(i) / 8.0
				geode.append(Vector2(0.5 + 0.46 * cos(angle), 0.45 + 0.46 * sin(angle)))
			for i: int in range(1, 8):
				geode.append(Vector2(0.04 + 0.92 * float(i) / 8.0, 0.45 - (0.22 if i % 2 == 1 else 0.06)))
			return geode
		SQUARE: # a square cut with notched corners
			return PackedVector2Array([Vector2(0.2, 0.08), Vector2(0.8, 0.08), Vector2(0.92, 0.2), Vector2(0.92, 0.8), Vector2(0.8, 0.92), Vector2(0.2, 0.92), Vector2(0.08, 0.8), Vector2(0.08, 0.2)])
	return PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.9, 0.9), Vector2(0.1, 0.9)])


## A star with `tips` points, alternating the outer and inner radius around the unit square's centre.
static func _star(tips: int, outer: float, inner: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in tips * 2:
		var angle: float = TAU * float(i) / float(tips * 2) - PI / 2.0
		var radius: float = outer if i % 2 == 0 else inner
		points.append(Vector2(0.5 + radius * cos(angle), 0.5 + radius * sin(angle)))
	return points


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
		MALACHITE:
			return Color("#2E9E5B")
		FLUORITE:
			return Color("#5CC8C8")
		HEMATITE:
			return Color("#8A4A4A")
		CALCITE:
			return Color("#F2E6C9")
		TOPAZ:
			return Color("#F0A44B")
		OBSIDIAN:
			return Color("#3A3A4A")
		PRIME:
			return Color("#FF8FB3")
		TWIN:
			return Color("#7FD1B9")
		MERSENNE:
			return Color("#FFD84D")
		SQUARE:
			return Color("#7F9CF5")
		GEODE:
			return Color("#B98AE8")
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
	draw_polyline(outline, OUTLINE if gem_type != OBSIDIAN else fill.lightened(0.6), OUTLINE_WIDTH, true)
	if gem_type == MALACHITE: # its light and dark bands
		for band: float in [0.36, 0.5, 0.64]:
			draw_line(Vector2(0.12, band) * size, Vector2(0.88, band) * size, fill.darkened(0.35), maxf(size.y * 0.04, 2.0))
