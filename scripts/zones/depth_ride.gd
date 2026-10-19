## The depth gauge's ride (Zone 7, negative.depth.move): pure logic for Bolt's elevator cab on the
## vertical number line, 0 at the mountain's base. Up adds, down subtracts, and the cab never leaves
## the gauge. The gauge scene (scenes/zones/z07_crystal_shards/depth_gauge.gd) draws it.
class_name DepthRide
extends RefCounted

var low: int = -30
var high: int = 30
var level: int = 0


static func make(min_level: int, max_level: int, start: int) -> DepthRide:
	var ride: DepthRide = DepthRide.new()
	ride.low = mini(min_level, max_level)
	ride.high = maxi(min_level, max_level)
	ride.level = clampi(start, ride.low, ride.high)
	return ride


## Moves the cab `meters` up (positive) or down (negative), stopping at the ends. Returns the new level.
func move(meters: int) -> int:
	level = clampi(level + meters, low, high)
	return level


func can_go_up() -> bool:
	return level < high


func can_go_down() -> bool:
	return level > low


## Where `value` sits between the top (0.0) and the bottom (1.0) of a gauge from low to high.
static func height_share(value: int, min_level: int, max_level: int) -> float:
	if max_level == min_level:
		return 0.5
	return clampf(float(max_level - value) / float(max_level - min_level), 0.0, 1.0)


## The labels the gauge shows: every `every` meters from high down to low, top first.
static func labels(min_level: int, max_level: int, every: int) -> Array[int]:
	var values: Array[int] = []
	var step: int = maxi(every, 1)
	var top: int = floori(max_level / float(step)) * step
	var at: int = top
	while at >= min_level:
		values.append(at)
		at -= step
	return values
