# Scholar variants in the text table (Phase 4, Sprint 37, P4-S37-05): a row with mode "scholar" is a
# longer form of the same id, shown only while ModeGate's LONGER_TEXT is on for the child; every other
# child sees the explorer line, and the table still has one explorer line per id.
class_name TextScholarTest
extends GdUnitTestSuite

const FIXTURE: String = "user://tmp/text_scholar_lines.csv"

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("text_scholar_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	ScholarMode.reset_overrides()


func after_test() -> void:
	Text.scholar_override = null
	ScholarMode.reset_overrides()
	Text.load_table()
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func _load_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tmp"))
	var file: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string("id,text,context,voice_version,mode\na.b.c,What is {n} squared?,ctx,0\na.b.c,Evaluate {n} squared: n times n.,ctx,0,scholar\nd.e.f,Plain.,ctx,0\n")
	file.close()
	assert_int(Text.load_table(FIXTURE)).is_equal(OK)


func test_explorer_children_see_the_short_line() -> void:
	_load_fixture()
	Text.scholar_override = false
	assert_str(Text.get_line(&"a.b.c", {"n": 7})).is_equal("What is 7 squared?")
	assert_bool(Text.has_scholar_variant(&"a.b.c")).is_true()
	assert_bool(Text.has_scholar_variant(&"d.e.f")).is_false()
	assert_int(Text.line_count()).is_equal(2) # the variant is not a second line


func test_scholar_children_see_the_variant_and_lines_without_one_are_unchanged() -> void:
	_load_fixture()
	Text.scholar_override = true
	assert_str(Text.get_line(&"a.b.c", {"n": 7})).is_equal("Evaluate 7 squared: n times n.")
	assert_str(Text.get_line(&"d.e.f")).is_equal("Plain.")
	assert_str(Text.get_line_bbcode(&"a.b.c", {"n": 7})).contains("Evaluate")


func test_the_gate_decides_from_the_childs_setting() -> void:
	_load_fixture()
	SaveSystem.data()["settings"]["interface_mode"] = "explorer"
	assert_str(Text.get_line(&"a.b.c", {"n": 3})).starts_with("What is")
	SaveSystem.data()["settings"]["interface_mode"] = "scholar"
	assert_str(Text.get_line(&"a.b.c", {"n": 3})).starts_with("Evaluate")
	SaveSystem.data()["settings"]["interface_mode"] = "auto"
	SaveSystem.data()["settings"]["starting_grade"] = 1
	assert_str(Text.get_line(&"a.b.c", {"n": 3})).starts_with("What is") # grade 1 stays Explorer
	SaveSystem.data()["settings"]["starting_grade"] = 5
	assert_str(Text.get_line(&"a.b.c", {"n": 3})).starts_with("Evaluate")


func test_every_real_scholar_variant_needs_only_params_its_line_gets() -> void:
	Text.load_table()
	var variants: int = 0
	for id: StringName in [&"z8.repeat.prompt", &"z8.evaluate.prompt", &"z8.square.prompt", &"z8.cube.prompt", &"z8.root.prompt", &"z8.sci.prompt_read", &"z8.sci.prompt_write", &"z8.lever.prompt"]:
		assert_bool(Text.has_scholar_variant(id)).override_failure_message(String(id)).is_true()
		variants += 1
		# A variant asks for no placeholder the explorer line does not (generators fill the explorer's).
		Text.scholar_override = false
		var explorer: String = Text.template(id)
		var regex: RegEx = RegEx.create_from_string("\\{([a-z_][a-z0-9_]*)\\}")
		for found: RegExMatch in regex.search_all(Text.scholar_template(id)):
			assert_str(explorer).contains("{" + found.get_string(1) + "}")
	assert_int(variants).is_equal(8)
