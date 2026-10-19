# Mirrors scripts/input/device_caps.gd (Phase 3, Sprint 25): the touch-screen check, the --no-touch
# dev flag, and the 25% bigger drop area on a mouse-only device.
class_name DeviceCapsTest
extends GdUnitTestSuite


func after_test() -> void:
	DeviceCaps.reset()
	DigitInk.reset()


func test_the_no_touch_flag_is_read_from_the_user_arguments() -> void:
	assert_bool(DeviceCaps.has_no_touch_arg(PackedStringArray(["--no-touch"]))).is_true()
	assert_bool(DeviceCaps.has_no_touch_arg(PackedStringArray(["--seed", "4", "--no-touch"]))).is_true()
	assert_bool(DeviceCaps.has_no_touch_arg(PackedStringArray([]))).is_false()
	assert_bool(DeviceCaps.has_no_touch_arg(PackedStringArray(["--no-touchy", "no-touch"]))).is_false()


func test_headless_ci_counts_as_a_mouse_only_device() -> void:
	# The headless runner has no touch screen, exactly like a mouse-only Chromebook.
	assert_bool(DeviceCaps.check_at_startup()).is_equal(DisplayServer.is_touchscreen_available())
	assert_bool(DeviceCaps.is_mouse_only()).is_equal(not DisplayServer.is_touchscreen_available())


func test_the_override_decides_for_tests() -> void:
	DeviceCaps.touch_override = true
	assert_bool(DeviceCaps.has_touchscreen()).is_true()
	assert_float(DeviceCaps.drop_scale()).is_equal(1.0)
	DeviceCaps.touch_override = false
	assert_bool(DeviceCaps.is_mouse_only()).is_true()
	assert_float(DeviceCaps.drop_scale()).is_equal(1.25)


func test_with_touch_the_drop_area_is_the_target_itself() -> void:
	DeviceCaps.touch_override = true
	var rect: Rect2 = Rect2(100, 200, 80, 40)
	assert_that(DeviceCaps.drop_rect(rect)).is_equal(rect)


func test_without_touch_the_drop_area_is_25_percent_bigger_around_the_same_centre() -> void:
	DeviceCaps.touch_override = false
	var rect: Rect2 = Rect2(100, 200, 80, 40)
	var grown: Rect2 = DeviceCaps.drop_rect(rect)
	assert_that(grown.size).is_equal(Vector2(100, 50))
	assert_that(grown.get_center()).is_equal(rect.get_center())
	assert_bool(grown.has_point(Vector2(185, 220))).is_true() # 5 px right of the edge: within 10 px
	assert_bool(grown.has_point(Vector2(195, 220))).is_false()


func test_a_drop_inside_a_target_wins_over_a_nearer_grown_neighbour() -> void:
	DeviceCaps.touch_override = false
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(104, 0, 100, 100)]
	assert_int(DeviceCaps.drop_index(rects, Vector2(99, 50))).is_equal(0)
	assert_int(DeviceCaps.drop_index(rects, Vector2(105, 50))).is_equal(1)


func test_a_drop_in_the_grown_gap_goes_to_the_nearest_centre_and_far_away_to_none() -> void:
	DeviceCaps.touch_override = false
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(120, 0, 100, 100)]
	assert_int(DeviceCaps.drop_index(rects, Vector2(105, 50))).is_equal(0)
	assert_int(DeviceCaps.drop_index(rects, Vector2(115, 50))).is_equal(1)
	assert_int(DeviceCaps.drop_index(rects, Vector2(50, 150))).is_equal(-1)
	DeviceCaps.touch_override = true
	assert_int(DeviceCaps.drop_index(rects, Vector2(105, 50))).is_equal(-1) # with touch the gap is a miss


func test_the_slate_is_not_offered_without_a_touch_screen() -> void:
	DeviceCaps.touch_override = false
	assert_bool(DigitInk.is_available()).is_false()
	DeviceCaps.touch_override = true
	assert_bool(DigitInk.is_available()).is_equal(DigitInk.net() != null)
