## The crystal of Zone 7 as pure logic: a round crystal cut into `den` equal wedge shards, which shards
## are lit, and the fraction they make. The crystal scene (scenes/zones/z07_crystal_shards/crystal.gd)
## and the picture painter (crystal_art.gd) draw what this computes; tests check it without nodes.
##
## Shard i of n is the wedge from angle start_angle(i, n) to start_angle(i + 1, n), clockwise from the
## top. Its outline (unit circle, centre at 0) is built once per n and cached on the script (a static
## Dictionary), never per node or per frame.
class_name CrystalShards
extends RefCounted

## Points on each wedge's outer arc: enough for a smooth edge on the biggest crystal.
const ARC_STEPS: int = 6

static var _wedges: Dictionary[int, Array] = {}

var den: int = 1
var _lit: Array[bool] = []


static func make(shards: int) -> CrystalShards:
	var crystal: CrystalShards = CrystalShards.new()
	crystal.den = maxi(shards, 1)
	crystal._lit.resize(crystal.den)
	crystal._lit.fill(false)
	return crystal


## The angle (radians, clockwise from straight up) where shard `index` of `shards` starts.
static func start_angle(index: int, shards: int) -> float:
	return TAU * float(index) / float(maxi(shards, 1)) - PI / 2.0


## The outlines of every shard of a `shards`-shard crystal on the unit circle (centre 0, radius 1),
## each a PackedVector2Array starting at the centre. Cached per shard count.
static func wedges(shards: int) -> Array:
	var n: int = maxi(shards, 1)
	if not _wedges.has(n):
		var outlines: Array = []
		for index: int in n:
			var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
			for step: int in ARC_STEPS + 1:
				var angle: float = lerpf(start_angle(index, n), start_angle(index + 1, n), float(step) / ARC_STEPS)
				points.append(Vector2(cos(angle), sin(angle)))
			outlines.append(points)
		_wedges[n] = outlines
	return _wedges[n]


## The shard under `point` (relative to the crystal's centre) on a crystal of `radius`, or -1 when the
## point is outside the crystal. Angles only: no polygon test, so it is exact and cheap.
static func shard_at(point: Vector2, radius: float, shards: int) -> int:
	if point.length() > radius or radius <= 0.0:
		return -1
	var angle: float = fposmod(point.angle() + PI / 2.0, TAU) # 0 at the top, clockwise
	return clampi(floori(angle / TAU * float(shards)), 0, shards - 1)


## The width of a shard's outer edge on a crystal of `radius`: the chord between its two corners.
static func outer_edge(radius: float, shards: int) -> float:
	return 2.0 * radius * sin(PI / float(maxi(shards, 1)))


## The smallest radius at which every shard's outer edge is at least `min_target` wide (a shard is a
## touch target: CLAUDE.md rule 7).
static func radius_for_targets(min_target: float, shards: int) -> float:
	if shards <= 1:
		return min_target
	return min_target / (2.0 * sin(PI / float(shards)))


## Lights or darkens shard `index`. Returns true when it is now lit.
func toggle(index: int) -> bool:
	if index < 0 or index >= den:
		return false
	_lit[index] = not _lit[index]
	return _lit[index]


func set_lit(index: int, lit: bool) -> void:
	if index >= 0 and index < den:
		_lit[index] = lit


func is_lit(index: int) -> bool:
	return index >= 0 and index < den and _lit[index]


func lit_count() -> int:
	return _lit.count(true)


## Lights exactly the first `count` shards (the picture model and tests).
func light_first(count: int) -> void:
	for index: int in den:
		_lit[index] = index < count


func clear() -> void:
	_lit.fill(false)


## The lit shards as a fraction in lowest terms: 2 of 4 lit is {1, 2}, none is {0, 1}.
func fraction() -> Dictionary:
	return Rational.normalize(lit_count(), den)


## Which shards are lit, in order (the scene redraws from this).
func lit_flags() -> Array[bool]:
	return _lit.duplicate()
