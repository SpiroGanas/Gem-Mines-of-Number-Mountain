# Mirrors autoload/text.gd and text/lines.csv.
class_name TextTest
extends GdUnitTestSuite

const TEXT_SCRIPT: String = "res://autoload/text.gd"
const REAL_LINES: String = "res://text/lines.csv"


## A fresh Text node (not the global one) loaded from CSV content written to a temp file.
func _text_from(csv: String) -> Node:
	var dir: String = create_temp_dir("text")
	var path: String = dir.path_join("lines.csv")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(csv)
	file.close()
	var script: GDScript = load(TEXT_SCRIPT)
	var text: Node = auto_free(script.new())
	assert_int(text.load_table(path)).is_equal(OK)
	return text


func test_get_line_returns_the_text_for_an_id() -> void:
	var text: Node = _text_from("id,text,context,voice_version\na.b.c,Hello there.,ctx,0\n")
	assert_str(text.get_line(&"a.b.c")).is_equal("Hello there.")
	assert_bool(text.has_line(&"a.b.c")).is_true()
	assert_bool(text.has_line(&"a.b.d")).is_false()


func test_quoted_fields_keep_their_commas() -> void:
	var text: Node = _text_from("id,text,context,voice_version\nq.a.b,\"First, second.\",ctx,0\n")
	assert_str(text.get_line(&"q.a.b")).is_equal("First, second.")


func test_blank_lines_are_skipped() -> void:
	var text: Node = _text_from("id,text,context,voice_version\n\na.b.c,One,ctx,0\n\n\nd.e.f,Two,ctx,0\n")
	assert_int(text.line_count()).is_equal(2)


func test_placeholders_are_filled_from_params() -> void:
	var text: Node = _text_from("id,text,context,voice_version\nsum.a.b,{a} plus {b} is {answer}.,ctx,0\n")
	var filled: String = text.get_line(&"sum.a.b", {"a": 3, "b": 4, "answer": 7})
	assert_str(filled).is_equal("3 plus 4 is 7.")


func test_string_name_param_keys_work() -> void:
	var text: Node = _text_from("id,text,context,voice_version\nx.y.z,Count to {n}.,ctx,0\n")
	assert_str(text.get_line(&"x.y.z", {&"n": 20})).is_equal("Count to 20.")


func test_a_missing_param_is_reported_and_left_visible() -> void:
	var text: Node = _text_from("id,text,context,voice_version\nsum.a.b,{a} plus {b}.,ctx,0\n")
	var result: Array[String] = [""]
	await assert_error(func() -> void: result[0] = text.get_line(&"sum.a.b", {"a": 3})) \
		.is_push_error("Text: line 'sum.a.b' is missing parameter(s) b")
	assert_str(result[0]).is_equal("3 plus {b}.")


func test_an_unknown_id_emits_missing_line_and_returns_the_id() -> void:
	var text: Node = _text_from("id,text,context,voice_version\na.b.c,Hi,ctx,0\n")
	monitor_signals(text)
	var result: Array[String] = [""]
	await assert_error(func() -> void: result[0] = text.get_line(&"no.such.line")) \
		.is_push_error("Text: missing line 'no.such.line'")
	await assert_signal(text).is_emitted("missing_line", [&"no.such.line"])
	assert_str(result[0]).is_equal("[no.such.line]")


func test_required_params_lists_placeholders_in_order_without_repeats() -> void:
	var text: Node = _text_from("id,text,context,voice_version\nr.a.b,{b} then {a} then {b} again,ctx,0\nplain.a.b,No numbers,ctx,0\n")
	assert_array(text.required_params(&"r.a.b")).contains_exactly(["b", "a"])
	assert_array(text.required_params(&"plain.a.b")).is_empty()
	assert_array(text.required_params(&"unknown.a.b")).is_empty()


func test_a_table_without_the_required_columns_is_rejected() -> void:
	var dir: String = create_temp_dir("text_bad")
	var path: String = dir.path_join("bad.csv")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("id,text\na.b.c,Hello\n")
	file.close()
	var script: GDScript = load(TEXT_SCRIPT)
	var text: Node = auto_free(script.new())
	await assert_error(func() -> void: assert_int(text.load_table(path)).is_equal(ERR_INVALID_DATA)) \
		.is_push_error("Text: %s is missing the 'context' column" % path)


func test_duplicate_ids_keep_the_first_line_and_report() -> void:
	var dir: String = create_temp_dir("text_dup")
	var path: String = dir.path_join("dup.csv")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("id,text,context,voice_version\na.b.c,First,ctx,0\na.b.c,Second,ctx,0\n")
	file.close()
	var script: GDScript = load(TEXT_SCRIPT)
	var text: Node = auto_free(script.new())
	await assert_error(func() -> void: text.load_table(path)) \
		.is_push_error("Text: duplicate line id 'a.b.c' in %s" % path)
	assert_str(text.get_line(&"a.b.c")).is_equal("First")


# --- The real table and the global Text autoload ---------------------------------------


func test_the_global_autoload_loaded_the_real_table() -> void:
	assert_int(Text.line_count()).is_greater(70)
	assert_str(Text.get_line(&"ui.title.play")).is_equal("Play")
	assert_str(Text.get_line(&"bolt.feedback.not_quite")).is_equal("Not quite. Let's look again.")


func test_feedback_never_says_wrong() -> void:
	for id: StringName in [&"bolt.feedback.correct", &"bolt.feedback.correct_hint", &"bolt.feedback.not_quite", &"bolt.hint.look_again", &"bolt.hint.show_model", &"bolt.hint.worked_example", &"bolt.hint.easier"]:
		assert_str(Text.get_line(id).to_lower()).not_contains("wrong")


func test_every_real_line_has_a_valid_unique_id_and_balanced_placeholders() -> void:
	var file: FileAccess = FileAccess.open(REAL_LINES, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	assert_array(header.slice(0, 4)).contains_exactly(["id", "text", "context", "voice_version"])
	assert_bool(header.size() == 4 or (header.size() == 5 and header[4] == "mode")).is_true() # Scholar variants (Sprint 37)
	var id_pattern: RegEx = RegEx.create_from_string("^[a-z0-9]+(\\.[a-z0-9_]+){2,}$")
	var seen: Dictionary[String, bool] = {}
	var scholar: Dictionary[String, bool] = {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 4:
			continue
		assert_object(id_pattern.search(row[0])).override_failure_message("bad line id: " + row[0]).is_not_null()
		var is_scholar: bool = row.size() > 4 and row[4] == "scholar"
		var ids: Dictionary[String, bool] = scholar if is_scholar else seen
		assert_bool(ids.has(row[0])).override_failure_message("duplicate id: " + row[0]).is_false()
		ids[row[0]] = true
		assert_str(row[1].strip_edges()).override_failure_message("empty text: " + row[0]).is_not_empty()
		assert_int(row[1].count("{")).override_failure_message("unbalanced braces: " + row[0]).is_equal(row[1].count("}"))
		assert_bool(row[3].is_valid_int()).override_failure_message("voice_version not an int: " + row[0]).is_true()


func test_term_definition_returns_the_word_gem_text() -> void:
	var gem: Dictionary = Text.term_definition(&"regrouping")
	assert_str(gem["term"]).is_equal("regrouping")
	assert_str(gem["text"]).contains("swap ten ones for one ten")
	assert_bool(gem.has("picture")).is_true()


func test_every_vocabulary_term_resolves_to_real_lines() -> void:
	var vocabulary: Dictionary = JsonUtil.parse_file("res://curriculum/vocabulary.json")
	var phase_2: int = vocabulary["terms"].filter(func(entry: Dictionary) -> bool: return int(entry["zone"]) <= 5).size()
	assert_int(phase_2).is_equal(31) # 26 from Zones 1-4 ("divide" added in Sprint 21), 4 from Zone 5, "recipe" from the workshop
	# Zone 6, Gear Works: 7 of its own plus the fraction previews' fraction, numerator, denominator, unit fraction
	assert_int(vocabulary["terms"].filter(func(entry: Dictionary) -> bool: return int(entry["zone"]) == 6).size()).is_equal(11)
	assert_int(vocabulary["terms"].filter(func(entry: Dictionary) -> bool: return int(entry["zone"]) == 7).size()).is_equal(9) # Zone 7, Crystal Shards
	assert_int(vocabulary["terms"].filter(func(entry: Dictionary) -> bool: return int(entry["zone"]) == 8).size()).is_equal(9) # Zone 8, Power Tower
	assert_int(vocabulary["terms"].size()).is_greater_equal(60) # later zones add theirs
	for entry: Dictionary in vocabulary["terms"]:
		assert_bool(Text.has_line(StringName(entry["term_line_id"]))).override_failure_message("missing " + entry["term_line_id"]).is_true()
		assert_bool(Text.has_line(StringName(entry["definition_line_id"]))).override_failure_message("missing " + entry["definition_line_id"]).is_true()


func test_unknown_term_returns_an_empty_dictionary() -> void:
	var result: Array[Dictionary] = [{"x": 1}]
	await assert_error(func() -> void: result[0] = Text.term_definition(&"not_a_term")) \
		.is_push_error("Text: unknown Word Gem 'not_a_term'")
	assert_dict(result[0]).is_empty()
