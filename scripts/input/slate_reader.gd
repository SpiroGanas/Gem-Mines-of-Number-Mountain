## What a set of digit-box readings means (pure logic for the chalk slate).
##
## Boxes run left to right, most significant digit first. Boxes to the LEFT of the first box with ink
## are leading zeros the child did not write (the answer 7 on a two-box slate); a blank box after
## the first inked one is not finished. Pure: no nodes, easy to test.
class_name SlateReader
extends RefCounted

enum Status {
	## No ink in any box.
	EMPTY,
	## A box after the first inked one is blank (`boxes` lists them).
	INCOMPLETE,
	## An inked box holds marks that are not a digit (`boxes` lists them).
	UNREADABLE,
	## Every digit is read with enough confidence: submit `value`.
	SURE,
	## Some digit is below the confidence threshold (`boxes` lists them): ask "Did you write {value}?".
	UNSURE,
}


## `readings[i]` is the Recognizer result of box i, or an empty Dictionary for a box with no ink.
## Returns {status: Status, value: int, boxes: Array[int], digits: Array[int]}.
static func interpret(readings: Array[Dictionary], threshold: float) -> Dictionary:
	var first: int = -1
	for index: int in readings.size():
		if not readings[index].is_empty():
			first = index
			break
	var result: Dictionary = {"status": Status.EMPTY, "value": -1, "boxes": [] as Array[int], "digits": [] as Array[int]}
	if first < 0:
		return result
	var blank: Array[int] = []
	var unreadable: Array[int] = []
	var unsure: Array[int] = []
	var digits: Array[int] = []
	for index: int in range(first, readings.size()):
		var reading: Dictionary = readings[index]
		if reading.is_empty():
			blank.append(index)
			continue
		var digit: int = int(reading.get("digit", -1))
		if digit < 0 or digit > 9:
			unreadable.append(index)
			continue
		digits.append(digit)
		if float(reading.get("confidence", 0.0)) < threshold:
			unsure.append(index)
	if not blank.is_empty():
		result["status"] = Status.INCOMPLETE
		result["boxes"] = blank
		return result
	if not unreadable.is_empty():
		result["status"] = Status.UNREADABLE
		result["boxes"] = unreadable
		return result
	var value: int = 0
	for digit: int in digits:
		value = value * 10 + digit
	result["value"] = value
	result["digits"] = digits
	result["boxes"] = unsure
	result["status"] = Status.UNSURE if not unsure.is_empty() else Status.SURE
	return result
