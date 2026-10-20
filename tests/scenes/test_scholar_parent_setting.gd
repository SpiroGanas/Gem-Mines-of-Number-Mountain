# The parent's Explorer / Scholar / Auto setting (Scholar mode part 1, Sprint 37, P4-S37-03): three
# buttons on the dashboard set the child's settings.interface_mode (already in the save: no migration),
# the profile reads it back, and the game follows it (Scholar lines and notation alone).
class_name ScholarParentSettingTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("scholar_parent_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	ScholarMode.reset_overrides()


func after_test() -> void:
	ScholarMode.reset_overrides()
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _dashboard() -> DashboardScreen:
	var screen: DashboardScreen = load("res://scenes/shell/parent_area/dashboard.tscn").instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


func test_a_new_child_starts_in_explorer_mode() -> void:
	var dashboard: DashboardScreen = _dashboard()
	assert_str(str(SaveSystem.data()["settings"]["interface_mode"])).is_equal("explorer")
	var explorer: Button = dashboard.find_child("Interface_explorer", true, false)
	assert_bool(explorer.button_pressed).is_true()
	assert_float(explorer.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_the_buttons_set_the_childs_mode_and_the_game_follows() -> void:
	var dashboard: DashboardScreen = _dashboard()
	(dashboard.find_child("Interface_scholar", true, false) as Button).pressed.emit()
	assert_str(str(SaveSystem.data()["settings"]["interface_mode"])).is_equal("scholar")
	assert_str(Profile.from_save(SaveSystem.data()).interface_mode).is_equal("scholar")
	assert_bool(ScholarMode.is_on(ModeGate.Feature.MATH_NOTATION)).is_true()
	assert_str(Text.get_line(&"z8.evaluate.prompt", {"b": 2, "e": 5})).is_equal("Evaluate this power.")
	var again: DashboardScreen = _dashboard()
	(again.find_child("Interface_auto", true, false) as Button).pressed.emit()
	assert_str(str(SaveSystem.data()["settings"]["interface_mode"])).is_equal("auto")
	SaveSystem.data()["settings"]["starting_grade"] = 1
	assert_str(Text.get_line(&"z8.evaluate.prompt", {"b": 2, "e": 5})).is_equal("What is 2 to the power 5?")
	(again.find_child("Interface_explorer", true, false) as Button).pressed.emit()
	assert_bool(ScholarMode.is_on(ModeGate.Feature.MATH_NOTATION)).is_false()
