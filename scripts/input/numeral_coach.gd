## Numeral-formation coaching (parent setting, default off): when the same digit is written
## backwards three times in a play session, Bolt shows how to write it, once per digit per
## session. It is only ever a demonstration: it never blocks submitting and never costs anything.
class_name NumeralCoach
extends RefCounted

## How many backwards writings of one digit bring the demonstration.
const MIRRORED_BEFORE_DEMO: int = 3

var _mirrored_counts: Dictionary[int, int] = {}
var _shown: Dictionary[int, bool] = {}


## Notes one accepted reading. Returns true when the demonstration for `digit` should play now.
func note(digit: int, mirrored: bool, coaching_on: bool) -> bool:
	if not coaching_on or not mirrored or digit < 0 or digit > 9:
		return false
	_mirrored_counts[digit] = _mirrored_counts.get(digit, 0) + 1
	if _mirrored_counts[digit] >= MIRRORED_BEFORE_DEMO and not _shown.get(digit, false):
		_shown[digit] = true
		return true
	return false


func mirrored_count(digit: int) -> int:
	return _mirrored_counts.get(digit, 0)


## A new session starts the counting again.
func reset() -> void:
	_mirrored_counts.clear()
	_shown.clear()
