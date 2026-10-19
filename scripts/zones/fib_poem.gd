## The rules of the Fib poem maker (Zone 9, Sprint 40), pure functions over word ids and the save. A Fib
## poem has six lines whose syllables follow the Fibonacci numbers 1, 1, 2, 3, 5, 8. The child builds each
## line from word tiles (curriculum/poem_words.json, counted by a person, PoemWords); a line "fits" when
## its stored syllable counts add up to its goal. The game never judges the words, only the counts, and a
## line that does not fit yet costs nothing (CLAUDE.md rule 8): it just does not glow.
##
## Saved poems (save schema v4, `poems.saved`) keep only word ids, never free text or strokes; the poem
## maker reads the words from the text table when it shows a poem.
class_name FibPoem
extends RefCounted

## Each line's syllable goal.
const TARGETS: Array[int] = [1, 1, 2, 3, 5, 8]
## The most poems a save keeps; saving one more lets the oldest go.
const MAX_SAVED: int = 20
## The most words a line holds (eight one-syllable words fill the last line).
const MAX_WORDS_PER_LINE: int = 8

const EMPTY: StringName = &"empty"
const SHORT: StringName = &"short"
const FITS: StringName = &"fits"
const LONG: StringName = &"long"


## The skill that opens the poem maker: the same one the Fib poem rocks need (fib.poem.syllables).
const OPENED_BY: StringName = &"fib.sequence.next_term"


## The poem maker's door in the museum shows once the child knows Fibonacci numbers (OPENED_BY is
## mastered) or already has a saved poem (a skill won back later never hides the poems).
static func is_open(save: Dictionary, mastered: Array[StringName]) -> bool:
	return mastered.has(OPENED_BY) or not saved(save).is_empty()


## Six empty lines.
static func blank_poem() -> Array:
	var lines: Array = []
	for index: int in TARGETS.size():
		lines.append([])
	return lines


## A line's syllables: the words' stored counts added up.
static func line_syllables(words: Array) -> int:
	return PoemWords.line_syllables(words)


## Where line `index` stands against its goal: empty, short, fits or long.
static func line_state(words: Array, index: int) -> StringName:
	if words.is_empty():
		return EMPTY
	var have: int = line_syllables(words)
	if have == TARGETS[index]:
		return FITS
	return SHORT if have < TARGETS[index] else LONG


static func line_fits(words: Array, index: int) -> bool:
	return line_state(words, index) == FITS


## True when all six lines fit their goals.
static func is_complete(lines: Array) -> bool:
	if lines.size() != TARGETS.size():
		return false
	for index: int in lines.size():
		if not line_fits(lines[index], index):
			return false
	return true


## Adds a word to a line (false when the line is full or the word is not in the bank).
static func add_word(lines: Array, index: int, word: String) -> bool:
	if index < 0 or index >= lines.size() or not PoemWords.has_word(word) or lines[index].size() >= MAX_WORDS_PER_LINE:
		return false
	lines[index].append(word)
	return true


## Takes the word at `position` out of line `index`.
static func remove_word(lines: Array, index: int, position: int) -> void:
	if index >= 0 and index < lines.size() and position >= 0 and position < lines[index].size():
		lines[index].remove_at(position)


## The first line that does not fit yet (the poem maker selects it after a line starts to fit), or -1.
static func next_open_line(lines: Array) -> int:
	for index: int in lines.size():
		if not line_fits(lines[index], index):
			return index
	return -1


## True for a saved poem the poem maker can show: {made_at: String, lines: six arrays of bank word ids}.
static func is_saved_poem(poem: Variant) -> bool:
	if not poem is Dictionary or not poem.get("made_at") is String or not poem.get("lines") is Array:
		return false
	var lines: Array = poem["lines"]
	if lines.size() != TARGETS.size():
		return false
	for line: Variant in lines:
		if not line is Array:
			return false
		for word: Variant in line:
			if not word is String or not PoemWords.has_word(word):
				return false
	return true


## The save's poems block, made sound if it is missing (a save from before schema v4 that skipped the
## migration, in a test).
static func poems(save: Dictionary) -> Dictionary:
	if not save.get("poems") is Dictionary:
		save["poems"] = {}
	if not save["poems"].get("saved") is Array:
		save["poems"]["saved"] = []
	return save["poems"]


## The saved poems, oldest first.
static func saved(save: Dictionary) -> Array:
	return poems(save)["saved"]


## Saves a finished poem into the save (word ids only). Returns false, and saves nothing, when a line
## does not fit. Keeps at most MAX_SAVED poems, letting the oldest go.
static func add_poem(save: Dictionary, lines: Array, now_iso: String) -> bool:
	if not is_complete(lines):
		return false
	var copy: Array = []
	for line: Array in lines:
		copy.append(line.duplicate())
	var list: Array = saved(save)
	list.append({"made_at": now_iso, "lines": copy})
	while list.size() > MAX_SAVED:
		list.remove_at(0)
	return true
