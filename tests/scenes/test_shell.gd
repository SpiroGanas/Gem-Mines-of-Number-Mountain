# Mirrors scenes/shell/*.tscn: screen flow, pause, saving at save points (P1-S03-02).
class_name ShellTest
extends GdUnitTestSuite

const SHELL_SCENE: String = "res://scenes/shell/shell.tscn"

var _shell: Shell
var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window()) # the headless window is 64x64; see TestWindow
	# Point the real SaveSystem at a temp folder so tests never touch the real save.
	_dir = create_temp_dir("shell_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_shell = load(SHELL_SCENE).instantiate()
	_shell.fade_seconds = 0.0 # no animation waits in tests
	add_child(_shell)
	auto_free(_shell)


func after_test() -> void:
	TestWindow.restore(get_window())
	get_tree().paused = false
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func _press(button_name: String) -> void:
	var button: Button = _shell.current_screen().find_child(button_name, true, false)
	assert_object(button).override_failure_message("no button " + button_name).is_not_null()
	button.pressed.emit()


## Waits until the shell shows `screen_id`.
func _until_screen(screen_id: StringName) -> void:
	var tries: int = 0
	while _shell.current_screen_id() != screen_id and tries < 100:
		await get_tree().process_frame
		tries += 1
	assert_str(_shell.current_screen_id()).is_equal(screen_id)


func _all_buttons(root: Node) -> Array[Node]:
	return root.find_children("*", "Button", true, false)


# --- Flow -----------------------------------------------------------------------------


func test_it_starts_on_the_title_screen() -> void:
	assert_str(_shell.current_screen_id()).is_equal(&"title")
	assert_object(_shell.current_screen()).is_instanceof(TitleScreen)


func test_play_goes_to_the_hub_and_settings_and_back() -> void:
	_press("PlayButton")
	await _until_screen(&"hub")
	_press("SettingsButton")
	await _until_screen(&"settings")
	_press("BackButton")
	await _until_screen(&"hub")


func test_screen_changed_is_emitted_for_each_switch() -> void:
	monitor_signals(_shell)
	_press("PlayButton")
	await assert_signal(_shell).wait_until(2000).is_emitted("screen_changed", [&"hub"])


func test_only_the_old_screen_is_freed() -> void:
	var title: Node = _shell.current_screen()
	_press("PlayButton")
	await _until_screen(&"hub")
	await get_tree().process_frame
	assert_bool(is_instance_valid(title) and not title.is_queued_for_deletion()).is_false()
	assert_int(_shell.find_child("ScreenHost", true, false).get_child_count()).is_equal(1)


func test_an_unknown_screen_is_ignored() -> void:
	_shell.change_screen(&"nowhere")
	assert_str(_shell.current_screen_id()).is_equal(&"title")


func test_a_request_made_during_a_change_is_not_lost() -> void:
	_shell.change_screen(&"hub")
	_shell.change_screen(&"settings") # arrives while the hub change is still running
	await _until_screen(&"settings")


func test_the_settings_back_target_comes_from_the_request() -> void:
	_shell.change_screen(&"settings", {"back_to": &"title"})
	await _until_screen(&"settings")
	_press("BackButton")
	await _until_screen(&"title")


func test_dig_opens_the_mine_and_head_up_style_requests_return_to_the_hub() -> void:
	_press("PlayButton")
	await _until_screen(&"hub")
	_press("DigButton")
	await _until_screen(&"mine")
	assert_object(_shell.current_screen()).is_instanceof(MineScreen)
	_shell.current_screen().request_screen.emit(&"hub", {})
	await _until_screen(&"hub")


func test_the_pause_button_on_the_mine_opens_the_pause_menu() -> void:
	_shell.change_screen(&"mine")
	await _until_screen(&"mine")
	_press("PauseButton")
	assert_bool(_shell.is_paused()).is_true()
	assert_bool(get_tree().paused).is_true()


# --- Pause ----------------------------------------------------------------------------


func test_escape_on_the_title_screen_does_not_pause() -> void:
	InputRouter.pause_requested.emit()
	assert_bool(_shell.is_paused()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_escape_pauses_and_a_second_escape_resumes() -> void:
	_shell.change_screen(&"hub")
	await _until_screen(&"hub")
	InputRouter.pause_requested.emit()
	assert_bool(_shell.is_paused()).is_true()
	assert_bool(get_tree().paused).is_true()
	InputRouter.pause_requested.emit()
	assert_bool(_shell.is_paused()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_pause_menu_buttons_resume_and_leave() -> void:
	_shell.change_screen(&"settings")
	await _until_screen(&"settings")
	_shell.pause()
	var menu: PauseMenu = _shell.find_child("PauseMenu", true, false)
	menu.find_child("ResumeButton", true, false).pressed.emit()
	assert_bool(_shell.is_paused()).is_false()
	_shell.pause()
	menu.find_child("HubButton", true, false).pressed.emit()
	assert_bool(get_tree().paused).is_false() # unpaused before the switch so the fade can run
	await _until_screen(&"hub")
	assert_bool(_shell.is_paused()).is_false()


func test_pause_settings_opens_settings_and_returns_to_the_hub() -> void:
	_shell.change_screen(&"hub")
	await _until_screen(&"hub")
	_shell.pause()
	_shell.find_child("PauseMenu", true, false).find_child("SettingsButton", true, false).pressed.emit()
	await _until_screen(&"settings")
	_press("BackButton")
	await _until_screen(&"hub")


func test_the_pause_menu_is_hidden_at_start() -> void:
	assert_bool(_shell.find_child("PauseMenu", true, false).visible).is_false()


# --- Save points ----------------------------------------------------------------------


func test_leaving_a_screen_saves() -> void:
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_false()
	_press("PlayButton")
	await _until_screen(&"hub")
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_true()


func test_a_posture_change_saves() -> void:
	SaveSystem.data()["rewards"]["coins"] = 77
	InputRouter.posture_changed.emit(Vector2i(1280, 800))
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_int(on_disk["rewards"]["coins"]).is_equal(77)


func test_toggling_read_aloud_persists_to_the_save() -> void:
	_shell.change_screen(&"settings")
	await _until_screen(&"settings")
	var toggle: Button = _shell.current_screen().find_child("ReadAloudButton", true, false)
	assert_bool(toggle.button_pressed).is_false()
	toggle.button_pressed = true # emits toggled
	assert_bool(SaveSystem.data()["settings"]["read_aloud"]).is_true()
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_bool(on_disk["settings"]["read_aloud"]).is_true()
	assert_str(toggle.text).is_equal("Read aloud: On")


# --- Every screen obeys the rules -----------------------------------------------------


func test_every_button_on_every_screen_is_a_full_size_touch_target() -> void:
	for screen_id: StringName in [&"title", &"hub", &"settings", &"mine"]:
		_shell.change_screen(screen_id, {})
		await _until_screen(screen_id)
		for node: Node in _all_buttons(_shell.current_screen()):
			var button: Button = node
			assert_float(button.custom_minimum_size.y).override_failure_message("%s/%s too small" % [screen_id, button.name]).is_greater_equal(float(UI.min_target_px()))
			assert_float(button.custom_minimum_size.x).override_failure_message("%s/%s too small" % [screen_id, button.name]).is_greater_equal(float(UI.min_target_px()))
	_shell.pause()
	for node: Node in _all_buttons(_shell.find_child("PauseMenu", true, false)):
		assert_float((node as Button).custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_no_screen_contains_a_text_field() -> void:
	for screen_id: StringName in [&"title", &"hub", &"settings", &"mine"]:
		_shell.change_screen(screen_id, {})
		await _until_screen(screen_id)
		for forbidden: String in ["LineEdit", "TextEdit", "SpinBox"]:
			assert_array(_shell.current_screen().find_children("*", forbidden, true, false)).is_empty()


func test_every_label_and_button_text_comes_from_the_text_table() -> void:
	for screen_id: StringName in [&"title", &"hub", &"settings", &"mine"]:
		_shell.change_screen(screen_id, {})
		await _until_screen(screen_id)
		for node: Node in _shell.current_screen().find_children("*", "", true, false):
			var text: String = ""
			if node is Label:
				text = (node as Label).text
			elif node is Button:
				text = (node as Button).text
			if text == "":
				continue
			assert_bool(text.begins_with("[") and text.ends_with("]")).override_failure_message("%s/%s shows a missing line: %s" % [screen_id, node.name, text]).is_false()
			assert_bool(text.contains("{")).override_failure_message("%s/%s has an unfilled placeholder: %s" % [screen_id, node.name, text]).is_false()


func test_the_title_shows_the_game_name_from_the_text_table() -> void:
	var label: Label = _shell.current_screen().find_child("TitleLabel", true, false)
	assert_str(label.text).is_equal("Gem Mines of Number Mountain")


# --- Developer overlay ----------------------------------------------------------------


func test_the_debug_overlay_reports_the_screen_and_input_device() -> void:
	_shell.change_screen(&"hub")
	await _until_screen(&"hub")
	var overlay: DebugOverlay = _shell.find_child("DebugOverlay", true, false)
	var text: String = overlay.describe()
	assert_str(text).contains("screen=hub")
	assert_str(text).contains("device=")
	assert_str(text).contains("min_target_px=")


func test_a_new_miners_first_dig_is_the_placement_quest_and_later_digs_are_not() -> void:
	_shell.change_screen(&"hub")
	await _until_screen(&"hub")
	assert_bool(Adaptive.needs_placement()).is_true()
	_press("DigButton")
	await _until_screen(&"mine")
	assert_bool(Adaptive.placement_active()).is_true()
	var bolt: Bolt = _shell.current_screen().bolt()
	assert_str(bolt.current_line_id()).is_equal("bolt.placement.intro")
	SaveSystem.use_directory(_dir) # reloading the profile drops the quest in progress
	assert_bool(Adaptive.placement_active()).is_false()
