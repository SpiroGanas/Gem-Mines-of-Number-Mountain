# The alloy mixer and the depth gauge of Zone 7: Alloy and DepthRide (pure rules) and the two scenes the
# child works with buttons (finger, stylus and mouse alike) or the keyboard.
class_name AlloyAndGaugeTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())


func after_test() -> void:
	TestWindow.restore(get_window())


func test_scaling_2_to_3_by_4_gives_8_to_12() -> void:
	assert_dict(Alloy.scale(2, 3, 4)).is_equal({"copper": 8, "tin": 12})
	assert_int(Alloy.tin_for(2, 3, 8)).is_equal(12)
	assert_int(Alloy.tin_for(2, 3, 7)).is_equal(-1) # not a whole number of recipes
	assert_bool(Alloy.is_right_mix(2, 3, 8, 12)).is_true()
	assert_bool(Alloy.is_right_mix(2, 3, 8, 11)).is_false()


func test_wrong_mixes_name_the_mistake_for_the_hint() -> void:
	assert_str(String(Alloy.mistake_for(2, 3, 8, 9))).is_equal("added_instead_of_scaled") # 3 + (8 - 2)
	assert_str(String(Alloy.mistake_for(2, 3, 8, 3))).is_equal("scaled_one_part")
	assert_str(String(Alloy.mistake_for(2, 3, 8, 10))).is_equal("")
	assert_str(String(Alloy.mistake_for(2, 3, 8, 12))).is_equal("")
	for name: StringName in [Alloy.ADDED, Alloy.ONE_PART]:
		assert_bool(SkillCatalog.misconception_names().has(name)).is_true()


func test_the_mixer_sets_tin_within_its_hopper_and_mix_hands_it_in() -> void:
	var mixer: AlloyMixer = load("res://scenes/zones/z07_crystal_shards/alloy_mixer.tscn").instantiate()
	mixer.speed_scale = 0.0
	add_child(mixer)
	auto_free(mixer)
	mixer.setup(2, 3, 8, 18)
	var got: Array[int] = []
	mixer.submitted.connect(func(tin: int) -> void: got.append(tin))
	assert_bool(mixer.less_button().disabled).is_true() # nothing to take out yet
	for i: int in 13:
		mixer.more_button().pressed.emit()
	mixer.less_button().pressed.emit()
	mixer.mix_button().pressed.emit()
	assert_array(got).is_equal([12])
	mixer.set_tin(40)
	assert_int(mixer.tin).is_equal(18) # never past the hopper
	assert_bool(mixer.more_button().disabled).is_true()
	for button: Button in [mixer.more_button(), mixer.less_button(), mixer.mix_button()]:
		assert_float(button.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_the_ride_never_leaves_the_gauge() -> void:
	var ride: DepthRide = DepthRide.make(-30, 30, 25)
	assert_int(ride.move(10)).is_equal(30)
	assert_bool(ride.can_go_up()).is_false()
	assert_int(ride.move(-75)).is_equal(-30)
	assert_bool(ride.can_go_down()).is_false()
	assert_float(DepthRide.height_share(0, -30, 30)).is_equal_approx(0.5, 0.0001)
	assert_float(DepthRide.height_share(30, -30, 30)).is_equal_approx(0.0, 0.0001)
	assert_array(DepthRide.labels(-10, 10, 5)).is_equal([10, 5, 0, -5, -10])


func test_the_gauge_rides_the_cab_and_stop_hands_in_its_level() -> void:
	var gauge: DepthGauge = load("res://scenes/zones/z07_crystal_shards/depth_gauge.tscn").instantiate()
	add_child(gauge)
	auto_free(gauge)
	gauge.setup(-30, 30, 5)
	var got: Array[int] = []
	gauge.submitted.connect(func(level: int) -> void: got.append(level))
	for i: int in 12:
		gauge.down_button().pressed.emit()
	gauge.stop_button().pressed.emit()
	assert_array(got).is_equal([-7])
	var up: InputEventKey = InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	gauge._unhandled_key_input(up)
	assert_int(gauge.level()).is_equal(-6)
	await await_millis(400) # the cab glides with a tween
	for button: Button in [gauge.up_button(), gauge.down_button(), gauge.stop_button()]:
		assert_float(button.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_a_disabled_gauge_and_mixer_take_nothing() -> void:
	var gauge: DepthGauge = load("res://scenes/zones/z07_crystal_shards/depth_gauge.tscn").instantiate()
	add_child(gauge)
	auto_free(gauge)
	gauge.setup(-10, 10, 0)
	gauge.set_enabled(false)
	gauge.move(3)
	assert_int(gauge.level()).is_equal(0)
	assert_bool(gauge.stop_button().disabled).is_true()
