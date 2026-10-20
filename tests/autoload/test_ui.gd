# Mirrors autoload/ui.gd.
class_name UiTest
extends GdUnitTestSuite


func test_min_target_is_never_below_64() -> void:
	assert_int(UI.min_target_px()).is_greater_equal(64)
	assert_float(UI.scale_factor()).is_greater(0.0)


func test_target_size_scales_with_the_multiples() -> void:
	TestWindow.use_design_size(get_window()) # the headless 64x64 window counts as a phone
	var side: float = float(UI.min_target_px())
	assert_bool(UI.is_compact()).is_false()
	assert_vector(UI.target_size()).is_equal(Vector2(side, side))
	assert_vector(UI.target_size(3.0, 1.5)).is_equal(Vector2(side * 3.0, side * 1.5))
	TestWindow.restore(get_window())


# --- Phones (the compact layout) -------------------------------------------------------------------


func test_a_landscape_phone_is_compact_and_a_tablet_is_not() -> void:
	TestWindow.use_phone(get_window()) # 2400 x 1080 at 420 dpi: about 411 dp tall
	assert_float(UI.short_side_dp()).is_equal_approx(1080.0 * 160.0 / 420.0, 0.5)
	assert_bool(UI.is_compact()).is_true()
	assert_int(UI.min_target_px()).is_equal(168) # 64 dp at 420 dpi on a 1.0 canvas scale
	TestWindow.use_tablet(get_window(), Vector2i(1920, 1200))
	UI.simulate_dpi(224) # a 10-inch tablet: about 857 dp tall
	assert_bool(UI.is_compact()).is_false()
	TestWindow.restore(get_window())
	assert_int(UI.dpi_override).is_equal(0)


func test_on_a_phone_multiples_keep_their_design_size_but_never_go_below_one_target() -> void:
	TestWindow.use_phone(get_window(), TestWindow.SMALL_PHONE, TestWindow.SMALL_PHONE_DPI)
	var side: float = float(UI.min_target_px()) # 192 canvas pixels
	assert_float(side).is_equal(192.0)
	assert_vector(UI.target_size()).is_equal(Vector2(side, side))
	assert_vector(UI.target_size(2.5, 1.75)).is_equal(Vector2(side, side)) # a pad key: one target
	assert_vector(UI.target_size(6.0, 1.0)).is_equal(Vector2(384.0, side)) # a picture: its design width
	assert_vector(UI.target_size(0.8, 0.8)).is_equal(Vector2(51.2, 51.2)) # a sign (a picture only)
	assert_vector(UI.picture_size(6.0, 2.0)).is_equal(Vector2(384.0, 128.0))
	assert_int(UI.spacing(24)).is_equal(12)
	TestWindow.restore(get_window())


func test_touch_targets_follow_a_simulated_density() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	UI.make_touch_target(button, 1.0, 1.0)
	TestWindow.use_phone(get_window())
	assert_vector(button.custom_minimum_size).is_equal(Vector2(168.0, 168.0))
	TestWindow.restore(get_window())
	assert_vector(button.custom_minimum_size).is_equal(UI.target_size(1.0, 1.0))
	button.queue_free()


func test_make_touch_target_sizes_the_control_and_registers_it() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	UI.make_touch_target(button, 2.0, 1.0)
	assert_vector(button.custom_minimum_size).is_equal(UI.target_size(2.0, 1.0))
	assert_bool(button.is_in_group(UI.TARGET_GROUP)).is_true()
	button.queue_free()


func test_touch_targets_are_resized_when_the_metrics_change() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	UI.make_touch_target(button, 1.0, 1.0)
	button.custom_minimum_size = Vector2.ZERO # pretend it was resized wrongly
	UI._on_window_size_changed()
	assert_vector(button.custom_minimum_size).is_equal(UI.target_size(1.0, 1.0))
	button.queue_free()


func test_metrics_changed_is_emitted_on_a_window_resize() -> void:
	monitor_signals(UI, false) # false: do not auto-free the global autoload
	UI._on_window_size_changed()
	await assert_signal(UI).is_emitted("metrics_changed")


func test_theme_is_cached_until_the_window_changes() -> void:
	var first: Theme = UI.theme()
	assert_object(UI.theme()).is_same(first)
	UI._on_window_size_changed()
	assert_object(UI.theme()).is_not_same(first)
