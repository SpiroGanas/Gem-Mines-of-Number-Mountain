# Mirrors scripts/input/stroke_capture.gd and scenes/shell/parent_area/capture.gd: the debug-build
# tool that saves digit strokes (never pictures) for measuring the network on real writing.
class_name StrokeCaptureTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("capture_" + str(Time.get_ticks_usec()))


func after_test() -> void:
	TestWindow.restore(get_window())


func _strokes() -> Array[PackedVector2Array]:
	return [PackedVector2Array([Vector2(0.123456, 0.2), Vector2(0.5, 0.9)]), PackedVector2Array([Vector2(0.1, 0.5), Vector2(0.9, 0.5)])]


func test_a_sample_holds_the_label_device_box_and_normalized_strokes_only() -> void:
	var sample: Dictionary = StrokeCapture.make_sample(7, "pen", Vector2i(180, 250), _strokes(), "2027-02-10T10:00:00Z")
	assert_array(sample.keys()).contains_exactly_in_any_order(["label", "device", "box", "strokes", "captured_at"])
	assert_int(sample["label"]).is_equal(7)
	assert_array(sample["box"]).is_equal([180, 250])
	assert_float(sample["strokes"][0][0][0]).is_equal_approx(0.1235, 0.00001) # rounded to 4 places
	assert_int(sample["strokes"].size()).is_equal(2)


func test_samples_are_saved_listed_counted_and_read_back_by_the_python_tools_format() -> void:
	for device: String in ["pen", "pen", "touch"]:
		var path: String = StrokeCapture.save(StrokeCapture.make_sample(3, device, Vector2i(100, 100), _strokes(), "t"), _dir)
		assert_str(path).is_not_empty()
	assert_int(StrokeCapture.files(_dir).size()).is_equal(3)
	assert_dict(StrokeCapture.counts(_dir)).is_equal({"pen": 2, "touch": 1})
	var back: Variant = JsonUtil.parse_file(StrokeCapture.files(_dir)[0])
	assert_int(back["label"]).is_equal(3)
	assert_bool(back["strokes"] is Array).is_true()


func test_two_saves_in_the_same_moment_do_not_overwrite_each_other() -> void:
	var sample: Dictionary = StrokeCapture.make_sample(1, "touch", Vector2i(100, 100), _strokes(), "t")
	for i: int in 5:
		StrokeCapture.save(sample, _dir)
	assert_int(StrokeCapture.files(_dir).size()).is_equal(5)


func test_export_copies_every_sample_and_clear_deletes_them() -> void:
	StrokeCapture.save(StrokeCapture.make_sample(1, "pen", Vector2i(100, 100), _strokes(), "t"), _dir)
	StrokeCapture.save(StrokeCapture.make_sample(2, "pen", Vector2i(100, 100), _strokes(), "t"), _dir)
	var target: String = create_temp_dir("capture_export_" + str(Time.get_ticks_usec()))
	assert_int(StrokeCapture.export_to(target, _dir)).is_equal(2)
	assert_int(DirAccess.get_files_at(target).size()).is_equal(2)
	StrokeCapture.clear_all(_dir)
	assert_array(StrokeCapture.files(_dir)).is_empty()
	assert_int(DirAccess.get_files_at(target).size()).is_equal(2) # the exported copies stay


func test_every_digit_comes_up_before_any_repeats() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var bag: Array[int] = []
	var first_round: Array[int] = []
	for i: int in 10:
		first_round.append(StrokeCapture.next_label(bag, rng))
	first_round.sort()
	assert_array(first_round).is_equal([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
	assert_array(bag).is_empty()


func test_the_device_name_follows_the_router_kind() -> void:
	assert_str(StrokeCapture.device_name(InputRouter.DeviceKind.PEN)).is_equal("pen")
	assert_str(StrokeCapture.device_name(InputRouter.DeviceKind.MOUSE)).is_equal("mouse")
	assert_str(StrokeCapture.device_name(InputRouter.DeviceKind.TOUCH)).is_equal("touch")


func test_capture_is_a_debug_build_feature_with_a_project_switch() -> void:
	assert_bool(OS.is_debug_build()).is_true() # tests run in a debug build
	assert_bool(StrokeCapture.is_enabled()).is_true()
	ProjectSettings.set_setting(StrokeCapture.SETTING, false)
	assert_bool(StrokeCapture.is_enabled()).is_false()
	ProjectSettings.set_setting(StrokeCapture.SETTING, true)


func test_the_screen_saves_what_was_written_for_the_digit_asked_and_moves_on() -> void:
	var screen: CaptureScreen = load("res://scenes/shell/parent_area/capture.tscn").instantiate()
	add_child(screen)
	auto_free(screen)
	screen.use_directory(_dir)
	await await_idle_frame()
	var asked: int = screen.target_label()
	assert_int(asked).is_between(0, 9)
	# an empty box saves nothing and does not move on
	screen.save_and_next()
	assert_array(StrokeCapture.files(_dir)).is_empty()
	assert_int(screen.target_label()).is_equal(asked)
	# write a stroke with the synthetic router events
	var box: DigitBox = screen.digit_box()
	var rect: Rect2 = box.get_global_rect()
	InputSim.touch(InputRouter, rect.position + rect.size * Vector2(0.3, 0.2), true)
	InputSim.drag(InputRouter, rect.position + rect.size * Vector2(0.5, 0.6))
	InputSim.touch(InputRouter, rect.position + rect.size * Vector2(0.5, 0.6), false)
	screen.save_and_next()
	var saved: Array[String] = StrokeCapture.files(_dir)
	assert_int(saved.size()).is_equal(1)
	assert_int(JsonUtil.parse_file(saved[0])["label"]).is_equal(asked)
	assert_bool(box.has_ink()).is_false() # the box is clear for the next digit
	assert_str(screen.status_text()).contains("finger 1")


func test_the_dashboard_offers_the_screen_in_debug_builds_and_the_shell_knows_it() -> void:
	assert_bool(Shell.SCREEN_PATHS.has(&"capture")).is_true()
	assert_bool(Shell.NON_PAUSABLE.has(&"capture")).is_true()
	var dash: DashboardScreen = load("res://scenes/shell/parent_area/dashboard.tscn").instantiate()
	add_child(dash)
	auto_free(dash)
	assert_object(dash.find_child("CaptureButton", true, false)).is_not_null()
	ProjectSettings.set_setting(StrokeCapture.SETTING, false)
	dash.refresh()
	await await_idle_frame()
	assert_object(dash.find_child("CaptureButton", true, false)).is_null()
	ProjectSettings.set_setting(StrokeCapture.SETTING, true)
