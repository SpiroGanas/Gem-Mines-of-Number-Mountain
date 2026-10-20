## The counterweight lever's rules (Zone 8, lever.counterweight.balance, and the Counterweight Elevator
## build): pure logic. A lever balances when weight × distance (the moment) is the same on both sides;
## the heavier moment's side goes down. Weights and distances are whole numbers. The counterweight
## scene and the build only draw this.
class_name Lever
extends RefCounted

var left_weight: int = 0
var left_distance: int = 1
var right_weight: int = 0
var right_distance: int = 1
## The most weight the right hook can take (the counterweight's range).
var max_weight: int = 32


static func make(left_w: int, left_d: int, right_d: int, most: int) -> Lever:
	var lever: Lever = Lever.new()
	lever.left_weight = maxi(left_w, 0)
	lever.left_distance = maxi(left_d, 1)
	lever.right_distance = maxi(right_d, 1)
	lever.max_weight = maxi(most, 1)
	return lever


## weight × distance on a side.
static func moment(weight: int, distance: int) -> int:
	return weight * distance


func left_moment() -> int:
	return moment(left_weight, left_distance)


func right_moment() -> int:
	return moment(right_weight, right_distance)


## "level", "left" (the left side is heavier and goes down) or "right".
func tilt() -> String:
	return side_heavier(left_weight, left_distance, right_weight, right_distance)


static func side_heavier(left_w: int, left_d: int, right_w: int, right_d: int) -> String:
	var left: int = moment(left_w, left_d)
	var right: int = moment(right_w, right_d)
	if left == right:
		return "level"
	return "left" if left > right else "right"


func is_balanced() -> bool:
	return tilt() == "level"


## Changes the right weight by `amount`, kept between 0 and max_weight. Returns the new weight.
func add_weight(amount: int) -> int:
	right_weight = clampi(right_weight + amount, 0, max_weight)
	return right_weight


func set_weight(weight: int) -> void:
	right_weight = clampi(weight, 0, max_weight)
