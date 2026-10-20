## The Fib poem word bank (Zone 9): curriculum/poem_words.json. Each word is a tile the child taps; its
## text is a line in text/lines.csv (z9.word.<id>) and its syllable count was counted by a person and
## stored in the file. Nothing here ever computes a syllable count; callers only add the stored ones.
## Read once and kept (the file is data that ships with the game).
class_name PoemWords
extends RefCounted

const PATH: String = "res://curriculum/poem_words.json"

## id -> {id, line_id, syllables}, in file order (the dictionary keeps insertion order).
static var _words: Dictionary = {}


static func _load() -> void:
	if not _words.is_empty():
		return
	var data: Variant = JsonUtil.parse_file(PATH)
	if not data is Dictionary or not data.get("words") is Array:
		push_error("PoemWords: cannot read %s" % PATH)
		return
	for entry: Variant in data["words"]:
		if entry is Dictionary and entry.has("id"):
			_words[String(entry["id"])] = {"id": String(entry["id"]), "line_id": StringName(str(entry["line_id"])), "syllables": int(entry["syllables"])}


## Every word id, in file order (one-syllable words first).
static func ids() -> Array[String]:
	_load()
	var result: Array[String] = []
	for id: String in _words:
		result.append(id)
	return result


static func has_word(id: String) -> bool:
	_load()
	return _words.has(id)


## The stored syllable count of a word (0 for an unknown id).
static func syllables(id: String) -> int:
	_load()
	return int(_words.get(id, {}).get("syllables", 0))


## The text-table line of a word's tile.
static func line_id(id: String) -> StringName:
	_load()
	return StringName(_words.get(id, {}).get("line_id", &""))


## The ids of every word with exactly `count` syllables, in file order.
static func with_syllables(count: int) -> Array[String]:
	_load()
	var result: Array[String] = []
	for id: String in _words:
		if int(_words[id]["syllables"]) == count:
			result.append(id)
	return result


## The syllables of a line of words: the stored counts added up.
static func line_syllables(words: Array) -> int:
	var total: int = 0
	for word: Variant in words:
		total += syllables(str(word))
	return total
