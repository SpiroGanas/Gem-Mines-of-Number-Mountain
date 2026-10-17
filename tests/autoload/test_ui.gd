# Mirrors autoload/ui.gd.
class_name UiTest
extends GdUnitTestSuite


func test_min_target_is_never_below_64() -> void:
	assert_int(UI.min_target_px()).is_greater_equal(64)
	assert_float(UI.scale_factor()).is_greater(0.0)


func test_target_size_scales_with_the_multiples() -> void:
	var side: float = float(UI.min_target_px())
	assert_vector(UI.target_size()).is_equal(Vector2(side, side))
	assert_vector(UI.target_size(3.0, 1.5)).is_equal(Vector2(side * 3.0, side * 1.5))


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
