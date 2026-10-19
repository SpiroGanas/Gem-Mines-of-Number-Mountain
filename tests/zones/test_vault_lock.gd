# The vault lock (Zone 8, Sprint 36, P4-S36-01): lamps for binary and dials for other bases. The rule
# is pure (VaultLock: digit × base^place, added up); the scene's places are big buttons that work the
# same with finger, stylus and mouse, Open hands in {base, digits}, and the whole lock fits a landscape
# phone (at most 4.5 touch targets tall).
class_name VaultLockTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())


func after_test() -> void:
	TestWindow.restore(get_window())


func _scene(base: int, places: int) -> VaultLockPicker:
	var lock: VaultLockPicker = load("res://scenes/zones/z08_power_tower/vault_lock.tscn").instantiate()
	add_child(lock)
	auto_free(lock)
	lock.setup(base, places)
	lock.speed_scale = 0.0
	return lock


func test_the_plan_examples() -> void:
	var binary: VaultLock = VaultLock.make(2, 4)
	binary.set_digits([1, 1, 0, 1])
	assert_int(binary.value()).is_equal(13)
	var five: VaultLock = VaultLock.make(5, 2)
	five.set_digits([2, 3])
	assert_int(five.value()).is_equal(13)
	assert_dict(five.answer()).is_equal({"base": 5, "digits": [2, 3]})


func test_a_tap_toggles_a_lamp_and_turns_a_dial_round() -> void:
	var lamps: VaultLock = VaultLock.make(2, 3)
	lamps.tap(0)
	assert_array(lamps.digits).is_equal([1, 0, 0])
	lamps.tap(0)
	assert_array(lamps.digits).is_equal([0, 0, 0])
	var dial: VaultLock = VaultLock.make(3, 1)
	for turn: int in 3:
		dial.tap(0)
	assert_int(dial.digits[0]).is_equal(0) # 0, 1, 2, then round to 0
	dial.tap(5) # off the lock: ignored
	assert_array(dial.digits).is_equal([0])


func test_the_lock_hands_in_no_leading_zeros_and_place_worths() -> void:
	var lock: VaultLock = VaultLock.make(2, 6)
	lock.set_digits([1, 0, 1])
	assert_dict(lock.answer()).is_equal({"base": 2, "digits": [1, 0, 1]})
	assert_int(lock.place_value(0)).is_equal(32)
	assert_int(lock.place_value(5)).is_equal(1)
	assert_dict(VaultLock.make(4, 3).answer()).is_equal({"base": 4, "digits": [0]})


func test_the_scene_lights_lamps_reads_the_total_and_opens() -> void:
	var lock: VaultLockPicker = _scene(2, 6)
	var given: Array = []
	lock.submitted.connect(func(value: Dictionary) -> void: given.append(value))
	assert_int(lock.place_count()).is_equal(6)
	for index: int in [2, 3, 5]: # 8 + 4 + 1
		lock.place_button(index).pressed.emit()
	assert_int(lock.value()).is_equal(13)
	assert_str(lock.find_child("Total", true, false).text).contains("13")
	lock.open_button().pressed.emit()
	assert_array(given).is_equal([{"base": 2, "digits": [1, 1, 0, 1]}])


func test_every_place_is_a_touch_target_and_the_lock_fits_a_phone() -> void:
	for spec: Vector2i in [Vector2i(2, 6), Vector2i(3, 5), Vector2i(8, 3)]:
		var lock: VaultLockPicker = _scene(spec.x, spec.y)
		await await_idle_frame()
		for index: int in lock.place_count():
			assert_float(lock.place_button(index).size.x).is_greater_equal(float(UI.min_target_px()))
			assert_float(lock.place_button(index).size.y).is_greater_equal(float(UI.min_target_px()))
		var needed: Vector2 = lock.get_combined_minimum_size() / float(UI.min_target_px())
		assert_float(needed.y).override_failure_message("%s tall" % needed.y).is_less_equal(4.5)
		assert_float(needed.x).is_less_equal(11.0)


func test_a_mouse_click_lights_a_lamp() -> void:
	var lock: VaultLockPicker = _scene(2, 4)
	await await_idle_frame()
	var button: Button = lock.place_button(1)
	var center: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = center
		click.global_position = center
		get_viewport().push_input(click)
		await await_idle_frame()
	assert_int(lock.value()).is_equal(4)


func test_disabled_locks_ignore_taps_and_dials_cycle_through_their_base() -> void:
	var lock: VaultLockPicker = _scene(5, 3)
	lock.set_enabled(false)
	lock.tap(0)
	assert_int(lock.value()).is_equal(0)
	lock.set_enabled(true)
	for turn: int in 4:
		lock.place_button(2).pressed.emit()
	assert_int(lock.value()).is_equal(4)
	lock.place_button(2).pressed.emit()
	assert_int(lock.value()).is_equal(0)
