# The readability audit (P1-S10-04), run on every screen the Shell can show:
#   - every button is at least one 64 dp touch target in both directions (rule 7);
#   - every visible word comes from the text table: no "[missing.id]" and no unfilled {placeholder};
#   - no text field outside the parent area (rule 6);
#   - text on the backdrops keeps AAA contrast.
# The manual half of the checklist (picture beside every instruction, color never the only clue)
# is in docs/gdd.md section 12.
class_name ReadabilityTest
extends GdUnitTestSuite

const PARENT_AREA: Array[StringName] = [&"parent_gate", &"dashboard", &"family_rewards"]

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("readability_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _shown_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in root.find_children("*", "", true, false):
		if node is Label:
			texts.append((node as Label).text)
		elif node is Button:
			texts.append((node as Button).text)
		elif node is RichTextLabel:
			texts.append((node as RichTextLabel).get_parsed_text())
	return texts


func test_every_screen_passes_the_audit() -> void:
	for screen_id: StringName in Shell.SCREEN_PATHS:
		var screen: ShellScreen = load(Shell.SCREEN_PATHS[screen_id]).instantiate()
		add_child(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		for node: Node in screen.find_children("*", "Button", true, false):
			var button: Button = node
			var smallest: float = minf(button.custom_minimum_size.x, button.custom_minimum_size.y)
			assert_float(smallest).override_failure_message("%s: button %s is smaller than a touch target" % [screen_id, button.name]).is_greater_equal(float(UI.min_target_px()))
		for text: String in _shown_texts(screen):
			assert_bool(text.begins_with("[") and text.ends_with("]")).override_failure_message("%s shows a missing line: %s" % [screen_id, text]).is_false()
			assert_bool(text.contains("{")).override_failure_message("%s has an unfilled placeholder: %s" % [screen_id, text]).is_false()
		if not PARENT_AREA.has(screen_id):
			for forbidden: String in ["LineEdit", "TextEdit", "SpinBox"]:
				assert_array(screen.find_children("*", forbidden, true, false)).override_failure_message("%s has a %s" % [screen_id, forbidden]).is_empty()
		screen.queue_free()
		await get_tree().process_frame


func test_text_on_every_backdrop_keeps_aaa_contrast() -> void:
	for palette: StringName in Backdrop.PALETTES:
		for key: String in ["top", "bottom", "rock"]:
			var color: Color = Backdrop.PALETTES[palette][key]
			assert_float(ExplorerTheme.contrast_ratio(ExplorerTheme.OFF_WHITE, color)).override_failure_message("%s %s" % [palette, key]).is_greater_equal(ExplorerTheme.MIN_TEXT_CONTRAST)


func test_every_workshop_button_has_a_picture() -> void:
	var hub: ShellScreen = load(Shell.SCREEN_PATHS[&"hub"]).instantiate()
	add_child(hub)
	auto_free(hub)
	await get_tree().process_frame
	for name: String in ["DigButton", "MuseumButton", "GarageButton", "SettingsButton", "GrownupsButton", "WorkshopButton", "BuildButton"]:
		var button: Button = hub.find_child(name, true, false)
		assert_array(button.find_children("*", "IconArt", true, false)).override_failure_message(name).has_size(1)


func test_each_mvp_zone_has_its_own_mine_tint() -> void:
	var seen: Array[Color] = []
	for zone: int in [1, 2, 3]:
		var top: Color = Backdrop.PALETTES[Backdrop.palette_for_zone(zone)]["top"]
		assert_bool(seen.has(top)).is_false()
		seen.append(top)
