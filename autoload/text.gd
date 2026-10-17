## Text autoload: the only source of child-facing strings (CLAUDE.md rule 4).
##
## Reads text/lines.csv (columns: id, text, context, voice_version) once at startup
## and hands out lines by stable id, filling {placeholders} such as {n}, {a}, {b}
## at runtime. Scenes and scripts never hard-code child-facing words, so Phase 3
## can add narration by id without reworking any screen.
##
## Note for Godot beginners: an *autoload* is a script Godot instantiates once at
## startup and exposes by name to every script, so any script can call
## Text.get_line(&"ui.title.play"). Because the autoload's name is "Text", this
## script has no class_name (the two would collide).
extends Node

## Emitted when a requested line id does not exist. The debug overlay and tests
## listen to this to show gaps; the lint keeps ids in code and the table in step.
signal missing_line(id: StringName)

const LINES_PATH: String = "res://text/lines.csv"
const VOCABULARY_PATH: String = "res://curriculum/vocabulary.json"
const COLUMN_ID: String = "id"
const COLUMN_TEXT: String = "text"
## All columns the table must have. Extra columns are allowed.
const REQUIRED_COLUMNS: PackedStringArray = ["id", "text", "context", "voice_version"]
## The warm headlamp yellow used to highlight numbers in Bolt's bubble.
const HIGHLIGHT_COLOR: String = "#FFD166"

var _lines: Dictionary[StringName, String] = {}
var _placeholder_pattern: RegEx = RegEx.new()
var _vocabulary: Dictionary[StringName, Dictionary] = {}
var _vocabulary_loaded: bool = false


func _init() -> void:
	# {name}: lowercase letters, digits and underscores, e.g. {n}, {a}, {answer}.
	_placeholder_pattern.compile("\\{([a-z_][a-z0-9_]*)\\}")


func _ready() -> void:
	load_table()


## Reads a lines CSV, replacing whatever was loaded before. Returns OK or an error code.
## Public so tests can load a small fixture table instead of the real one.
func load_table(path: String = LINES_PATH) -> Error:
	_lines.clear()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("Text: cannot open %s (%s)" % [path, error_string(open_error)])
		return open_error
	var header: PackedStringArray = file.get_csv_line()
	for column: String in REQUIRED_COLUMNS:
		if not header.has(column):
			push_error("Text: %s is missing the '%s' column" % [path, column])
			return ERR_INVALID_DATA
	var id_column: int = header.find(COLUMN_ID)
	var text_column: int = header.find(COLUMN_TEXT)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() <= maxi(id_column, text_column):
			continue # blank or short line
		var id: StringName = StringName(row[id_column].strip_edges())
		if id.is_empty():
			continue
		if _lines.has(id):
			push_error("Text: duplicate line id '%s' in %s" % [id, path])
			continue
		_lines[id] = row[text_column]
	return OK


func has_line(id: StringName) -> bool:
	return _lines.has(id)


func line_count() -> int:
	return _lines.size()


## The text for a line id with its {placeholders} filled from params.
## An unknown id emits missing_line and returns "[id]" so the gap is visible.
## A placeholder with no value is reported (push_error in debug builds) and left as typed.
func get_line(id: StringName, params: Dictionary = {}) -> String:
	if not _lines.has(id):
		missing_line.emit(id)
		_report("Text: missing line '%s'" % id)
		return "[%s]" % id
	var filled: String = _lines[id].format(params)
	var unfilled: PackedStringArray = _placeholders_in(filled)
	if not unfilled.is_empty():
		_report("Text: line '%s' is missing parameter(s) %s" % [id, ", ".join(unfilled)])
	return filled


## The line as BBCode for a RichTextLabel. Square brackets in the text are escaped, and the values
## of the params named in `highlight` are drawn bold in `color` (hint rung 1: "look at these numbers").
## `links` maps Word Gem words to their term ids ({"sum": &"sum", "fact family": &"fact_family"}):
## each whole-word match in the line (any case) becomes a tappable [url] whose meta is the term
## id, so a RichTextLabel's meta_clicked reports which Word Gem was tapped.
func get_line_bbcode(id: StringName, params: Dictionary = {}, highlight: Array = [], color: String = HIGHLIGHT_COLOR, links: Dictionary = {}) -> String:
	if not _lines.has(id):
		return get_line(id, params) # reports the gap the usual way
	var filled: Dictionary = {}
	for key: Variant in params:
		var value: String = escape_bbcode(str(params[key]))
		filled[key] = "[b][color=%s]%s[/color][/b]" % [color, value] if highlight.has(key) else value
	var template: String = escape_bbcode(_lines[id])
	if not links.is_empty():
		template = _link_words(template, links)
	return template.format(filled)


func _link_words(template: String, links: Dictionary) -> String:
	var words: Array = links.keys()
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length()) # "equal groups" before "equal"
	var escaped: PackedStringArray = PackedStringArray()
	for word: String in words:
		escaped.append(word.replace(" ", "\\s+"))
	var pattern: RegEx = RegEx.new()
	pattern.compile("(?i)\\b(" + "|".join(escaped) + ")\\b")
	var result: String = ""
	var last: int = 0
	for found: RegExMatch in pattern.search_all(template):
		if found.get_start() > 0 and template[found.get_start() - 1] == "{":
			continue # a placeholder such as {tens}, not the word
		var word: String = found.get_string(1)
		var term: Variant = links.get(word.to_lower(), links.get(" ".join(word.to_lower().split(" ", false)), ""))
		result += template.substr(last, found.get_start() - last)
		result += "[url=%s][u]%s[/u][/url]" % [term, word]
		last = found.get_end()
	return result + template.substr(last)


## Text made safe to show in a BBCode label: "[" becomes the [lb] tag.
static func escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


## The placeholder names a line needs, in order of first appearance, e.g. ["a", "b"].
## Generators' tests use this to prove a problem supplies every parameter its prompt needs.
func required_params(id: StringName) -> PackedStringArray:
	if not _lines.has(id):
		return PackedStringArray()
	return _placeholders_in(_lines[id])


## A Word Gem: {term: String, text: String, picture: Texture2D or null, visual: Dictionary}.
## Empty when the term id is unknown. Words come from the text table; the picture
## and the line ids come from curriculum/vocabulary.json.
func term_definition(term_id: StringName) -> Dictionary:
	_ensure_vocabulary()
	if not _vocabulary.has(term_id):
		_report("Text: unknown Word Gem '%s'" % term_id)
		return {}
	var entry: Dictionary = _vocabulary[term_id]
	var picture: Texture2D = null
	var picture_path: Variant = entry.get("picture")
	if picture_path is String and ResourceLoader.exists(picture_path):
		picture = load(picture_path)
	return {
		"term": get_line(StringName(entry["term_line_id"])),
		"text": get_line(StringName(entry["definition_line_id"])),
		"picture": picture,
		"visual": entry.get("visual", {}),
	}


## Every Word Gem id in curriculum/vocabulary.json, in file order.
func term_ids() -> Array[StringName]:
	_ensure_vocabulary()
	var ids: Array[StringName] = []
	for id: StringName in _vocabulary:
		ids.append(id)
	return ids


func _ensure_vocabulary() -> void:
	if _vocabulary_loaded:
		return
	_vocabulary_loaded = true
	var parsed: Variant = JsonUtil.parse_file(VOCABULARY_PATH) # whole numbers stay ints (picture sizes)
	if not parsed is Dictionary:
		push_error("Text: cannot read %s" % VOCABULARY_PATH)
		return
	for entry: Dictionary in parsed.get("terms", []):
		_vocabulary[StringName(entry["id"])] = entry


func _placeholders_in(template: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for match: RegExMatch in _placeholder_pattern.search_all(template):
		var name: String = match.get_string(1)
		if not names.has(name):
			names.append(name)
	return names


func _report(message: String) -> void:
	if OS.is_debug_build():
		push_error(message)
