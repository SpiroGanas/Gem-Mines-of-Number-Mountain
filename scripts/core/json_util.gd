## JSON helpers that fix one Godot quirk: JSON.parse_string returns every number as a
## float (1 comes back as 1.0). Saves, skill files and exported problems hold many
## integers, and a float where a typed `int` is expected is a silent bug waiting to
## happen, so everything the game reads goes through here.
class_name JsonUtil
extends RefCounted

## Whole numbers this large or larger stay floats (they cannot be an exact int).
const MAX_EXACT_INT: float = 9.0e15


## Parses JSON text. Returns null when the text is not valid JSON.
static func parse_text(text: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return intify(json.data)


## Reads and parses a JSON file. Returns null if the file is missing or not valid JSON.
static func parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return parse_text(FileAccess.get_file_as_string(path))


## Recursively turns floats that hold a whole number into ints (3.0 becomes 3).
## Real fractions such as 0.42 are left alone. Dictionaries and arrays are copied.
static func intify(value: Variant) -> Variant:
	if value is float:
		var number: float = value
		if absf(number) < MAX_EXACT_INT and number == floorf(number):
			return int(number)
		return number
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value:
			copy[key] = intify(value[key])
		return copy
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(intify(item))
		return items
	return value
