# The Fib poem maker (Zone 9, Sprint 40, P4-S40-03): FibPoem's pure rules and the poem screen. A line
# glows when its stored syllable counts match its goal (1, 1, 2, 3, 5, 8); a line that does not match
# never costs anything; a finished poem saves into the child's save (schema v4) as word ids only and
# shows in My poems; the museum door opens with Fibonacci mastery.
class_name FibPoemTest
extends GdUnitTestSuite

const POEM: Array = [["sun"], ["glow"], ["crystal"], ["deep", "cave", "light"], ["shining", "silver", "star"], ["watermelon", "helicopter"]]

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("fib_poem_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func test_a_line_fits_when_its_syllables_match_its_goal() -> void:
	assert_str(String(FibPoem.line_state([], 0))).is_equal("empty")
	assert_str(String(FibPoem.line_state(["crystal"], 0))).is_equal("long")
	assert_str(String(FibPoem.line_state(["crystal"], 2))).is_equal("fits")
	assert_str(String(FibPoem.line_state(["sun"], 3))).is_equal("short")
	assert_bool(FibPoem.is_complete(POEM)).is_true()
	var broken: Array = POEM.duplicate(true)
	broken[5] = ["watermelon"]
	assert_bool(FibPoem.is_complete(broken)).is_false()


func test_saving_keeps_word_ids_only_and_never_more_than_the_limit() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	var broken: Array = POEM.duplicate(true)
	broken[0] = []
	assert_bool(FibPoem.add_poem(save, broken, "t")).is_false() # an unfinished poem is not saved
	assert_array(FibPoem.saved(save)).is_empty()
	for index: int in FibPoem.MAX_SAVED + 3:
		assert_bool(FibPoem.add_poem(save, POEM, "2027-08-%02dT10:00:00Z" % (index % 28 + 1))).is_true()
	assert_int(FibPoem.saved(save).size()).is_equal(FibPoem.MAX_SAVED)
	for poem: Variant in FibPoem.saved(save):
		assert_bool(FibPoem.is_saved_poem(poem)).is_true()
		for line: Variant in poem["lines"]:
			for word: Variant in line:
				assert_bool(PoemWords.has_word(str(word))).is_true()
	assert_bool(FibPoem.add_word(FibPoem.blank_poem(), 0, "glimmer")).is_false() # not a bank word


func test_the_museum_door_opens_with_fibonacci_mastery_or_a_saved_poem() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	assert_bool(FibPoem.is_open(save, [])).is_false()
	assert_bool(FibPoem.is_open(save, [&"fib.sequence.next_term"])).is_true()
	FibPoem.add_poem(save, POEM, "t")
	assert_bool(FibPoem.is_open(save, [])).is_true()


func _screen() -> FibPoemScreen:
	var screen: FibPoemScreen = load("res://scenes/zones/z09_pattern_grotto/fib_poem.tscn").instantiate()
	add_child(screen)
	auto_free(screen)
	await get_tree().process_frame
	return screen


func test_tapping_words_builds_lines_that_glow_and_the_poem_saves() -> void:
	var screen: FibPoemScreen = await _screen()
	assert_bool(screen.save_button().disabled).is_true()
	screen.word_tile("crystal").pressed.emit() # two syllables on line 1 (goal 1): too many, no cost
	assert_array(screen.lines()[0]).contains_exactly(["crystal"])
	assert_bool(screen.line_row(0).modulate == FibPoemScreen.LINE_GLOW).is_false()
	screen.placed_chip(0, 0).pressed.emit() # tap the placed word: it goes back out
	assert_array(screen.lines()[0]).is_empty()
	for line: int in POEM.size():
		screen.select_line(line)
		for word: Variant in POEM[line]:
			screen.word_tile(str(word)).pressed.emit()
		assert_bool(screen.line_row(line).modulate == FibPoemScreen.LINE_GLOW).override_failure_message("line %d" % line).is_true()
	assert_bool(screen.save_button().disabled).is_false()
	var saved: Array[bool] = []
	screen.poem_saved.connect(func() -> void: saved.append(true))
	screen.save_button().pressed.emit()
	assert_array(saved).is_not_empty()
	assert_array(FibPoem.saved(SaveSystem.data())[0]["lines"]).is_equal(POEM)
	assert_bool(screen.showing_poems()).is_true()
	assert_str(screen.saved_poem_texts()[0]).is_equal("sun\nglow\ncrystal\ndeep cave light\nshining silver star\nwatermelon helicopter")
	# Written to disk at once (a save point).
	var on_disk: Dictionary = JsonUtil.parse_file(SaveSystem.profile_dir().path_join("profile.json"))
	assert_int(on_disk["poems"]["saved"].size()).is_equal(1)


func test_every_word_tile_comes_from_the_text_table_and_is_a_touch_target() -> void:
	var screen: FibPoemScreen = await _screen()
	for word: String in PoemWords.ids():
		var tile: Button = screen.word_tile(word)
		assert_str(tile.text).is_equal(Text.get_line(PoemWords.line_id(word)))
		assert_float(tile.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	for line: int in FibPoem.TARGETS.size():
		assert_float(screen.line_row(line).custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	assert_object(screen.find_child("*LineEdit*", true, false)).is_null()
