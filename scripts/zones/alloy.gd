## The alloy mixer's rules (Zone 7, the ratio.scale.alloy skill and the Alloy Mixer build): pure logic,
## no nodes. A recipe is a copper to b tin; a mix of c copper and t tin is right when it keeps the
## recipe's ratio (c * b == t * a, cross-multiplied, never divided). A wrong mix is matched to the
## mistake it most likely shows, so Bolt's hint can name it.
class_name Alloy
extends RefCounted

## The mistakes a wrong mix can show (names in curriculum/misconceptions.json).
const ADDED: StringName = &"added_instead_of_scaled"
const ONE_PART: StringName = &"scaled_one_part"


## The tin that `copper` needs for an a : b recipe, or -1 when the copper is not a whole number of
## recipes (the hopper always holds whole recipes in the game).
static func tin_for(a: int, b: int, copper: int) -> int:
	if a <= 0 or copper % a != 0:
		return -1
	return MathUtil._exact_div(copper, a) * b


## True when c copper and t tin keep the a : b recipe.
static func is_right_mix(a: int, b: int, copper: int, tin: int) -> bool:
	return a > 0 and b > 0 and copper * b == tin * a


## The scaled-up mix: {copper, tin} for `factor` whole recipes (2 : 3 by 4 is 8 : 12).
static func scale(a: int, b: int, factor: int) -> Dictionary:
	return {"copper": a * factor, "tin": b * factor}


## The mistake a wrong tin count shows for c copper of an a : b recipe: added the extra copper to the
## tin instead of multiplying, or kept the recipe's tin; &"" for any other wrong count (and a right one).
static func mistake_for(a: int, b: int, copper: int, tin: int) -> StringName:
	if is_right_mix(a, b, copper, tin):
		return &""
	if tin == b + copper - a:
		return ADDED
	if tin == b:
		return ONE_PART
	return &""


## How full the mixing drum looks (0..1) for a mix, given the most the drum holds. Presentation only.
static func drum_fill(copper: int, tin: int, capacity: int) -> float:
	return clampf(float(copper + tin) / float(maxi(capacity, 1)), 0.0, 1.0)
