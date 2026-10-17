# Mirrors scripts/ui/explorer_theme.gd.
class_name ExplorerThemeTest
extends GdUnitTestSuite


func test_contrast_ratio_known_values() -> void:
	assert_float(ExplorerTheme.contrast_ratio(Color.BLACK, Color.WHITE)).is_equal_approx(21.0, 0.01)
	assert_float(ExplorerTheme.contrast_ratio(Color.WHITE, Color.WHITE)).is_equal_approx(1.0, 0.001)
	# Symmetric: argument order does not matter.
	assert_float(ExplorerTheme.contrast_ratio(Color("#1F2945"), Color.WHITE)) \
		.is_equal_approx(ExplorerTheme.contrast_ratio(Color.WHITE, Color("#1F2945")), 0.0001)


func test_label_text_has_aaa_contrast_on_the_mine_background() -> void:
	var ratio: float = ExplorerTheme.contrast_ratio(ExplorerTheme.OFF_WHITE, ExplorerTheme.NAVY)
	assert_float(ratio).is_greater_equal(ExplorerTheme.MIN_TEXT_CONTRAST)


func test_button_text_has_aaa_contrast_on_resting_and_hover_fills() -> void:
	for fill: Color in [ExplorerTheme.YELLOW, ExplorerTheme.YELLOW_HOVER, ExplorerTheme.GREEN, ExplorerTheme.GREEN_HOVER]:
		assert_float(ExplorerTheme.contrast_ratio(ExplorerTheme.NAVY, fill)).is_greater_equal(ExplorerTheme.MIN_TEXT_CONTRAST)


func test_pressed_button_text_still_meets_aa_contrast() -> void:
	# The pressed fill is darker and only shows for a moment; AA (4.5) is the floor there.
	for fill: Color in [ExplorerTheme.YELLOW_PRESSED, ExplorerTheme.GREEN_PRESSED]:
		assert_float(ExplorerTheme.contrast_ratio(ExplorerTheme.NAVY, fill)).is_greater_equal(4.5)


func test_disabled_button_text_still_meets_aa_contrast() -> void:
	# Disabled controls are exempt from WCAG, but a child should still be able to read them.
	assert_float(ExplorerTheme.contrast_ratio(ExplorerTheme.NAVY, ExplorerTheme.GREY_DISABLED)).is_greater_equal(4.5)


func test_built_theme_has_large_text_and_the_expected_types() -> void:
	var theme: Theme = ExplorerTheme.build(64)
	assert_int(theme.default_font_size).is_greater_equal(40)
	assert_int(theme.get_font_size(&"font_size", &"Button")).is_greater_equal(40)
	assert_int(theme.get_font_size(&"font_size", &"HeadingLabel")).is_greater(theme.get_font_size(&"font_size", &"Label"))
	assert_int(theme.get_font_size(&"font_size", &"NumberLabel")).is_greater(theme.get_font_size(&"font_size", &"HeadingLabel"))
	assert_bool(theme.has_stylebox(&"normal", &"Button")).is_true()
	assert_bool(theme.has_stylebox(&"normal", &"GoButton")).is_true()
	assert_str(theme.get_type_variation_base(&"GoButton")).is_equal("Button")


func test_button_style_leaves_room_for_a_finger() -> void:
	var theme: Theme = ExplorerTheme.build(64)
	var box: StyleBox = theme.get_stylebox(&"normal", &"Button")
	assert_float(box.get_margin(SIDE_LEFT)).is_greater_equal(12.0)
