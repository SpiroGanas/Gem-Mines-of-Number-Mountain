## The vault lock's rules (Zone 8, base.*.from_decimal): pure logic for a row of `places` places in a
## base. In binary each place is a lamp, off (0) or on (1), and a tap toggles it; in another base each
## place is a dial that a tap turns to the next digit, 0 to base - 1 and round again (never a long press:
## no multi-step gestures). The lock shows the number sum(digit × base^place). The vault lock scene
## (scenes/zones/z08_power_tower/vault_lock.gd) only draws this.
class_name VaultLock
extends RefCounted

var base: int = 2
## Digits left (biggest place) to right (ones), every place included.
var digits: Array[int] = []


static func make(lock_base: int, places: int) -> VaultLock:
	var lock: VaultLock = VaultLock.new()
	lock.base = clampi(lock_base, Notation.MIN_BASE, Notation.MAX_BASE)
	for index: int in clampi(places, 1, BaseGenerator.MAX_PLACES):
		lock.digits.append(0)
	return lock


func places() -> int:
	return digits.size()


## A tap on place `index` (0 is the leftmost): a lamp toggles, a dial turns to its next digit.
func tap(index: int) -> void:
	if index < 0 or index >= digits.size():
		return
	digits[index] = (digits[index] + 1) % base


## Sets every place from `new_digits` (most significant first, right-aligned); extra digits on the left
## are dropped. Used to resume a lock and by tests.
func set_digits(new_digits: Array) -> void:
	for index: int in digits.size():
		digits[index] = 0
	var offset: int = digits.size() - new_digits.size()
	for index: int in new_digits.size():
		if index + offset >= 0:
			digits[index + offset] = clampi(int(new_digits[index]), 0, base - 1)


## The worth of place `index` (the rightmost is 1, the next base, then base × base...).
func place_value(index: int) -> int:
	return Notation.power(base, digits.size() - 1 - index)


## The number the lock shows now: each digit times its place's worth, added up.
func value() -> int:
	var total: int = 0
	for index: int in digits.size():
		total += digits[index] * place_value(index)
	return total


## What the lock hands in: {base, digits} without leading zeros (the problem's answer shape).
func answer() -> Dictionary:
	return {"base": base, "digits": Notation.trimmed(digits)}


func is_lamp_row() -> bool:
	return base == 2
