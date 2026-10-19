## The logic of a gear train (Zone 6, P4-S30-01): gears in a row, each meshing with the next, the first
## one driven by an electric motor. Teeth push teeth, so while the first gear turns once, teeth[0] teeth
## pass every meshing point and gear i turns teeth[0] ÷ teeth[i] times. Neighbours turn opposite ways
## (cosmetic: Zone 6 never asks about direction). Two marked teeth that start together line up again
## once lcm(teeth) teeth have passed, after lcm(teeth) ÷ teeth[0] turns of the first gear.
##
## Pure logic: scenes (the gear bench, the Conveyor Sync build) ask it for angles; it holds no nodes.
## A train precomputes each gear's speed when it is made, so the per-frame angle needs no allocation.
class_name GearTrain
extends RefCounted

var teeth: Array[int] = []
## Turns of each gear for one turn of the first, signed by direction (+1 the first gear's way).
var _speeds: PackedFloat64Array = PackedFloat64Array()


func _init(gear_teeth: Array[int] = []) -> void:
	set_teeth(gear_teeth)


## Changes the gears (a new train): the speeds are worked out once here, not every frame.
func set_teeth(gear_teeth: Array[int]) -> void:
	teeth = gear_teeth.duplicate()
	_speeds.resize(teeth.size())
	for index: int in teeth.size():
		_speeds[index] = float(teeth[0]) / float(teeth[index]) * float(direction_of(index))


func size() -> int:
	return teeth.size()


## Gear `index`'s angle (radians) after the first gear has turned `driver_turns` times. No allocation.
func angle_of(index: int, driver_turns: float) -> float:
	return TAU * driver_turns * _speeds[index]


## How many times gear `index` turns for one turn of the first gear, unsigned (1.5 for 24 then 16).
func turns_per_driver_turn(index: int) -> float:
	return absf(_speeds[index])


## +1 for the first gear and every second gear after it, -1 for the gears between: meshing gears turn
## opposite ways.
static func direction_of(index: int) -> int:
	return 1 if index % 2 == 0 else -1


## Gear `index`'s turns for one turn of the first, as an exact fraction {num, den} in lowest terms.
static func ratio(gear_teeth: Array[int], index: int) -> Dictionary:
	return Rational.normalize(gear_teeth[0], gear_teeth[index])


## Turns of the first gear until every marked tooth is back where it started at the same time:
## lcm of all the teeth ÷ the first gear's teeth. One gear alone is back after 1 turn.
static func turns_to_align(gear_teeth: Array[int]) -> int:
	assert(not gear_teeth.is_empty(), "GearTrain.turns_to_align needs at least one gear")
	var together: int = gear_teeth[0]
	for count: int in gear_teeth:
		together = Rational.lcm(together, count)
	return floori(float(together) / float(gear_teeth[0]))


## The first time (in steps) two conveyors that drop a gem every `every_a` and every `every_b` steps
## drop together: their least common multiple (the Conveyor Sync build).
static func first_shared_drop(every_a: int, every_b: int) -> int:
	return Rational.lcm(every_a, every_b)
