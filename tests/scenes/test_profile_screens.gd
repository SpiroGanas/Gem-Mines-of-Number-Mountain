# Mirrors the Sprint 23 screens: the title screen's profile switcher, parent onboarding, the profiles
# page (add, rename, delete twice, bring back), "How this game teaches" and the dashboard's child
# picker and per-child import. Runs on the real autoloads pointed at a temp folder.
class_name ProfileScreensTest
extends GdUnitTestSuite

const SHELL_SCENE: String = "res://scenes/shell/shell.tscn"

var _dir: String
var _shell: Shell


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("profile_screens_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))
	SaveSystem.use_directory(_dir)
	ParentGateScreen.forget_lock()


func after_test() -> void:
	if _shell != null:
		_shell.queue_free()
		_shell = null
	ParentGateScreen.forget_lock()
	DeviceSettings.use_shared(null)
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())
	get_tree().paused = false


func _start_shell() -> void:
	_shell = load(SHELL_SCENE).instantiate()
	_shell.fade_seconds = 0.0
	add_child(_shell)


func _until_screen(screen_id: StringName) -> void:
	var tries: int = 0
	while _shell.current_screen_id() != screen_id and tries < 100:
		await get_tree().process_frame
		tries += 1
	assert_str(_shell.current_screen_id()).is_equal(screen_id)


func _screen(path: String, args: Dictionary = {}) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	screen.setup(args)
	add_child(screen)
	auto_free(screen)
	return screen


func _type(pad: NumberPad, value: int) -> void:
	pad.clear()
	for digit: String in str(value):
		pad.press_digit(int(digit))
	pad.submit()


func _pass(panel: GatePanel) -> void:
	for question: int in ParentGateRules.QUESTIONS_TO_PASS:
		_type(panel.number_pad(), panel.rules.answer())


## A device with Charlie and `others` more children (Charlie active).
func _family(others: Array[String]) -> Array[String]:
	SaveSystem.data()["child"]["nickname"] = "Charlie"
	SaveSystem.data()["placement"]["done"] = true
	SaveSystem.save_now()
	var ids: Array[String] = [Profiles.active.id]
	for name: String in others:
		ids.append(Profiles.create(name, Profile.AVATARS[ids.size()], 1).id)
	return ids


# --- Title screen: the profile switcher -------------------------------------------------------------


func test_one_child_keeps_the_one_tap_play_button() -> void:
	_family([])
	var title: TitleScreen = _screen("res://scenes/shell/title.tscn")
	assert_array(title.profile_tiles()).is_empty()
	assert_bool(title.find_child("PlayButton", true, false).visible).is_true()
	var requested: Array[StringName] = []
	title.request_screen.connect(func(id: StringName, _args: Dictionary) -> void: requested.append(id))
	(title.find_child("PlayButton", true, false) as Button).pressed.emit()
	assert_array(requested).contains_exactly([&"hub"])


func test_each_child_has_a_big_avatar_tile_and_one_tap_switches_and_starts() -> void:
	var ids: Array[String] = _family(["Ada", "Sam"])
	var title: TitleScreen = _screen("res://scenes/shell/title.tscn")
	var tiles: Array[Button] = title.profile_tiles()
	assert_int(tiles.size()).is_equal(3)
	assert_bool(title.find_child("PlayButton", true, false).visible).is_false()
	for tile: Button in tiles:
		assert_float(tile.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()) * 3.0)
		assert_float(tile.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()) * 3.0)
		assert_array(tile.find_children("*", "AvatarArt", true, false)).has_size(1)
		assert_array(tile.find_children("*", "LineEdit", true, false)).is_empty() # no typing for children
	assert_str((tiles[1].find_child("Nickname", true, false) as Label).text).is_equal("Ada")
	var requested: Array[StringName] = []
	title.request_screen.connect(func(id: StringName, _args: Dictionary) -> void: requested.append(id))
	tiles[1].pressed.emit() # one tap (a click works the same: Button.pressed)
	assert_str(Profiles.active.id).is_equal(ids[1])
	assert_array(requested).contains_exactly([&"first_run"]) # Ada was made by a grown-up: Bolt says hello first


func test_a_tile_can_be_clicked_with_the_mouse() -> void:
	var ids: Array[String] = _family(["Ada"])
	_start_shell()
	await _until_screen(&"title")
	await get_tree().process_frame
	var title: TitleScreen = _shell.current_screen()
	var tile: Button = title.profile_tiles()[1]
	var center: Vector2 = tile.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = center
		click.global_position = center
		get_viewport().push_input(click)
		await get_tree().process_frame
	assert_str(Profiles.active.id).is_equal(ids[1])


func test_grown_ups_on_the_title_go_through_the_gate_to_the_profiles_page() -> void:
	_family(["Ada"])
	_start_shell()
	await _until_screen(&"title")
	(_shell.current_screen() as TitleScreen).grownups_button().pressed.emit()
	await _until_screen(&"parent_gate")
	var gate: ParentGateScreen = _shell.current_screen()
	_pass(gate.gate_panel())
	await _until_screen(&"profiles")
	(_shell.current_screen().find_child("BackButton", true, false) as Button).pressed.emit()
	await _until_screen(&"title")


func test_back_from_the_gate_never_reaches_the_grown_up_screens() -> void:
	var gate: ParentGateScreen = _screen("res://scenes/shell/parent_area/parent_gate.tscn", {"then": &"profiles", "back_to": &"title"})
	var requested: Array[StringName] = []
	gate.request_screen.connect(func(id: StringName, _args: Dictionary) -> void: requested.append(id))
	(gate.find_child("BackButton", true, false) as Button).pressed.emit()
	_type(gate.number_pad(), gate.rules.answer()) # one right answer is not enough
	assert_array(requested).contains_exactly([&"title"])


# --- Parent onboarding ---------------------------------------------------------------------------------


func test_a_new_install_goes_from_play_through_onboarding_to_bolt() -> void:
	assert_bool(Profiles.needs_onboarding()).is_true()
	_start_shell()
	await _until_screen(&"title")
	(_shell.current_screen().find_child("PlayButton", true, false) as Button).pressed.emit()
	await _until_screen(&"onboarding")
	var onboarding: OnboardingScreen = _shell.current_screen()
	# 1. The gate: a child alone stops here.
	assert_int(onboarding.step).is_equal(OnboardingScreen.Step.GATE)
	assert_object(onboarding.next_button()).is_null()
	_type(onboarding.gate_panel().number_pad(), onboarding.gate_panel().rules.answer() + 1)
	assert_int(onboarding.step).is_equal(OnboardingScreen.Step.GATE)
	_pass(onboarding.gate_panel())
	# 2. The first child.
	assert_int(onboarding.step).is_equal(OnboardingScreen.Step.PROFILE)
	assert_bool(onboarding.next_button().disabled).is_true() # a name first
	assert_int(onboarding.avatar_buttons().size()).is_equal(Profile.AVATARS.size())
	assert_int(onboarding.grade_buttons().size()).is_equal(7)
	onboarding.nickname_field().text = "Mia"
	onboarding.nickname_field().text_changed.emit("Mia")
	onboarding.avatar_buttons()[6].pressed.emit()
	onboarding.grade_buttons()[0].pressed.emit() # kindergarten
	assert_bool(onboarding.next_button().disabled).is_false()
	onboarding.next_button().pressed.emit()
	# 3. The session limit.
	assert_int(onboarding.step).is_equal(OnboardingScreen.Step.SESSION)
	(onboarding.find_child("MoreButton", true, false) as Button).pressed.emit()
	(onboarding.find_child("StartButton", true, false) as Button).pressed.emit()
	await _until_screen(&"first_run")
	assert_str(Profiles.active.nickname).is_equal("Mia")
	assert_str(Profiles.active.avatar_id).is_equal(Profile.AVATARS[6])
	assert_int(Profiles.active.starting_grade).is_equal(0)
	assert_int(Profiles.active.session_minutes).is_equal(25)
	assert_int(Profiles.count()).is_equal(1)
	assert_bool(Profiles.needs_onboarding()).is_false()
	assert_str(SaveSystem.data()["placement"]["seed"]).is_equal("grade_0")
	# Bolt says hello and skips the name step (Mia has a name), then the placement quest starts.
	var first_run: FirstRunScreen = _shell.current_screen()
	first_run.next_button().pressed.emit()
	assert_int(first_run.step).is_equal(FirstRunScreen.Step.READY)
	first_run.next_button().pressed.emit()
	await _until_screen(&"mine")
	assert_bool(Adaptive.placement_active()).is_true()
	assert_str(Adaptive.placement().current_skill()).is_equal("count.to_20.objects") # the grade K probe
	assert_bool(SaveSystem.data()["profile"]["welcomed"]).is_true()


func test_onboarding_screens_are_parent_screens_with_pictures() -> void:
	var onboarding: OnboardingScreen = _screen("res://scenes/shell/parent_area/onboarding.tscn")
	for step: OnboardingScreen.Step in [OnboardingScreen.Step.GATE, OnboardingScreen.Step.PROFILE, OnboardingScreen.Step.SESSION]:
		onboarding.show_step(step)
		await get_tree().process_frame
		assert_int(onboarding.find_children("*", "IconArt", true, false).size() + onboarding.find_children("*", "AvatarArt", true, false).size()).is_greater(0)
		assert_str((onboarding.find_child("StepBody", true, false) as Label).text).is_not_empty()


# --- The profiles page ---------------------------------------------------------------------------------


func test_deleting_a_child_asks_twice_and_can_be_undone() -> void:
	var ids: Array[String] = _family(["Ada"])
	var page: ProfilesScreen = _screen("res://scenes/shell/parent_area/profiles.tscn")
	page.ask_delete(ids[1])
	assert_int(page.confirm_state()).is_equal(ProfilesScreen.Confirm.FIRST)
	assert_int(Profiles.count()).is_equal(2)
	(page.find_child("YesButton", true, false) as Button).pressed.emit()
	assert_int(page.confirm_state()).is_equal(ProfilesScreen.Confirm.SECOND)
	assert_int(Profiles.count()).is_equal(2) # still there after the first yes
	(page.find_child("ForGoodButton", true, false) as Button).pressed.emit()
	assert_int(Profiles.count()).is_equal(1)
	assert_str(page.status_text()).is_equal(Text.get_line(&"parent.profiles.deleted", {"name": "Ada"}))
	var restore: Button = page.find_child("RestoreButton", true, false)
	assert_object(restore).is_not_null()
	restore.pressed.emit()
	assert_int(Profiles.count()).is_equal(2)


func test_keep_cancels_a_delete_and_the_last_child_cannot_be_deleted() -> void:
	var ids: Array[String] = _family(["Ada"])
	var page: ProfilesScreen = _screen("res://scenes/shell/parent_area/profiles.tscn")
	page.ask_delete(ids[1])
	(page.find_child("KeepButton", true, false) as Button).pressed.emit()
	assert_int(page.confirm_state()).is_equal(ProfilesScreen.Confirm.NONE)
	page.delete_for_good() # without the two confirmations nothing happens
	assert_int(Profiles.count()).is_equal(2)
	Profiles.delete(ids[1])
	page.refresh()
	assert_bool((page.row_for(ids[0]).find_child("DeleteButton", true, false) as Button).disabled).is_true()
	page.ask_delete(ids[0])
	assert_str(page.status_text()).is_equal(Text.get_line(&"parent.profiles.last_one"))


func test_adding_renaming_and_playing_as_from_the_profiles_page() -> void:
	var ids: Array[String] = _family([])
	var page: ProfilesScreen = _screen("res://scenes/shell/parent_area/profiles.tscn")
	page.set_new_avatar(&"rocket")
	page.set_new_grade(2)
	var made: Profile = page.add_child_profile("Ada")
	assert_str(made.avatar_id).is_equal("rocket")
	assert_int(made.starting_grade).is_equal(2)
	page.rename(made.id, "Adaline")
	assert_str(Profiles.get_profile(made.id).nickname).is_equal("Adaline")
	page.play_as(made.id)
	assert_str(Profiles.active.id).is_equal(made.id)
	page.next_avatar(ids[0])
	assert_str(Profiles.get_profile(ids[0]).avatar_id).is_equal(Profile.AVATARS[1])
	for name: String in ["C", "D"]:
		page.add_child_profile(name)
	assert_int(Profiles.count()).is_equal(4)
	assert_object(page.find_child("AddButton", true, false)).is_null() # four is the limit
	assert_object(page.add_child_profile("E")).is_null()


# --- How this game teaches, and the dashboard --------------------------------------------------------


func test_how_it_teaches_explains_the_method_and_shows_the_privacy_address_as_text() -> void:
	var page: HowItTeachesScreen = _screen("res://scenes/shell/parent_area/how_it_teaches.tscn")
	var texts: PackedStringArray = page.texts()
	for line_id: StringName in [&"parent.teach.map_body", &"parent.teach.mastery_body", &"parent.teach.review_body", &"parent.teach.hints_body"]:
		assert_bool(texts.has(Text.get_line(line_id))).override_failure_message(String(line_id)).is_true()
	assert_bool(texts.has(Text.get_line(&"parent.teach.privacy_url"))).is_true()
	assert_array(page.find_children("*", "LinkButton", true, false)).is_empty() # plain text, nothing opens
	assert_object(page.find_child("Scroll", true, false)).is_not_null()


func test_the_dashboard_shows_the_active_child_and_can_show_another() -> void:
	var ids: Array[String] = _family(["Ada"])
	SaveSystem.data()["rewards"]["coins"] = 9
	var dashboard: DashboardScreen = _screen("res://scenes/shell/parent_area/dashboard.tscn")
	assert_str((dashboard.find_child("ActiveChild", true, false) as Label).text).is_equal(Text.get_line(&"parent.dash.child", {"name": "Charlie"}))
	var show_ada: Button = dashboard.find_child("Show_%s" % ids[1], true, false)
	assert_object(show_ada).is_not_null()
	show_ada.pressed.emit()
	assert_str(Profiles.active.id).is_equal(ids[1])
	assert_str((dashboard.find_child("ActiveChild", true, false) as Label).text).is_equal(Text.get_line(&"parent.dash.child", {"name": "Ada"}))
	assert_str((dashboard.find_child("ImportButton", true, false) as Button).text).is_equal(Text.get_line(&"parent.dash.import_into", {"name": "Ada"}))


func test_the_dashboard_imports_a_file_as_a_new_child() -> void:
	_family([])
	var path: String = _dir.path_join("charlie.json")
	assert_int(SaveSystem.export_bundle(path)).is_equal(OK)
	var dashboard: DashboardScreen = _screen("res://scenes/shell/parent_area/dashboard.tscn")
	assert_int(dashboard.import_from(path, false, true)).is_equal(OK)
	assert_int(Profiles.count()).is_equal(2)
	assert_str(dashboard.status_text()).is_equal(Text.get_line(&"parent.dash.import_added", {"name": "Charlie"}))
	assert_object(dashboard.find_child("Show_%s" % SaveSystem.last_import_report["added"], true, false)).is_not_null()
