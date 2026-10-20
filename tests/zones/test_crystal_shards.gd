# The crystal splitting mechanic (Zone 7): CrystalShards' wedge geometry and lit fraction, and the
# CrystalPicker scene the child taps (finger, stylus and mouse all arrive as mouse buttons).
class_name CrystalShardsTest
extends GdUnitTestSuite

var _picker: CrystalPicker
var _submitted: Array[Dictionary] = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_submitted.clear()


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(den: int, match: Dictionary = {}) -> CrystalPicker:
	_picker = load("res://scenes/zones/z07_crystal_shards/crystal.tscn").instantiate()
	add_child(_picker)
	auto_free(_picker)
	_picker.setup(den, match)
	_picker.submitted.connect(func(value: Dictionary) -> void: _submitted.append(value))
	await await_idle_frame()
	return _picker


func _click(control: Control, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		control._gui_input(event)


func test_the_wedge_count_equals_the_denominator() -> void:
	for den: int in range(1, 25):
		var outlines: Array = CrystalShards.wedges(den)
		assert_int(outlines.size()).is_equal(den)
		for outline: PackedVector2Array in outlines:
			assert_vector(outline[0]).is_equal(Vector2.ZERO) # every wedge starts at the centre
			assert_int(outline.size()).is_equal(CrystalShards.ARC_STEPS + 2)
	assert_bool(CrystalShards.wedges(8) == CrystalShards.wedges(8)).is_true() # cached, not rebuilt


func test_lighting_num_shards_reports_the_fraction_in_lowest_terms() -> void:
	var crystal: CrystalShards = CrystalShards.make(8)
	assert_dict(crystal.fraction()).is_equal({"num": 0, "den": 1})
	crystal.light_first(6)
	assert_dict(crystal.fraction()).is_equal({"num": 3, "den": 4})
	crystal.toggle(0)
	assert_dict(crystal.fraction()).is_equal({"num": 5, "den": 8})
	crystal.light_first(8)
	assert_dict(crystal.fraction()).is_equal({"num": 1, "den": 1})


func test_a_point_finds_its_shard_by_angle() -> void:
	# Four shards clockwise from the top: top-right is 0, bottom-right 1, bottom-left 2, top-left 3.
	assert_int(CrystalShards.shard_at(Vector2(10, -10), 100.0, 4)).is_equal(0)
	assert_int(CrystalShards.shard_at(Vector2(10, 10), 100.0, 4)).is_equal(1)
	assert_int(CrystalShards.shard_at(Vector2(-10, 10), 100.0, 4)).is_equal(2)
	assert_int(CrystalShards.shard_at(Vector2(-10, -10), 100.0, 4)).is_equal(3)
	assert_int(CrystalShards.shard_at(Vector2(200, 0), 100.0, 4)).is_equal(-1) # outside the crystal


func test_every_shard_is_at_least_a_touch_target_wide() -> void:
	for den: int in [2, 6, 12]:
		var picker: CrystalPicker = await _make(den)
		var radius: float = picker.crystal().radius()
		assert_float(CrystalShards.outer_edge(radius, den)).is_greater_equal(float(UI.min_target_px()) - 0.01)
		assert_float(picker.done_button().custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
		picker.get_parent().remove_child(picker)
		picker.queue_free()


func test_clicking_shards_lights_them_and_done_hands_in_the_fraction() -> void:
	var picker: CrystalPicker = await _make(6)
	var crystal: ShardCrystal = picker.crystal()
	_click(crystal, crystal.shard_center(0))
	_click(crystal, crystal.shard_center(3))
	_click(crystal, crystal.shard_center(5))
	_click(crystal, crystal.shard_center(5)) # a second click turns it off
	assert_int(crystal.crystal.lit_count()).is_equal(2)
	picker.done_button().pressed.emit()
	assert_array(_submitted).is_equal([{"num": 1, "den": 3}])


func test_a_press_that_slides_to_another_shard_lights_nothing() -> void:
	var picker: CrystalPicker = await _make(4)
	var crystal: ShardCrystal = picker.crystal()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = crystal.shard_center(0)
	crystal._gui_input(press)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	release.position = crystal.shard_center(2)
	crystal._gui_input(release)
	assert_int(crystal.crystal.lit_count()).is_equal(0)


func test_the_keyboard_picks_and_lights_shards() -> void:
	var picker: CrystalPicker = await _make(5)
	var crystal: ShardCrystal = picker.crystal()
	for key: Key in [KEY_SPACE, KEY_RIGHT, KEY_RIGHT, KEY_ENTER]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.pressed = true
		crystal._gui_input(event)
	assert_bool(crystal.crystal.is_lit(0)).is_true()
	assert_bool(crystal.crystal.is_lit(2)).is_true()
	assert_int(crystal.crystal.lit_count()).is_equal(2)


func test_matching_shows_the_crystal_to_copy_and_equal_fractions_match() -> void:
	var picker: CrystalPicker = await _make(8, {"num": 1, "den": 2})
	assert_object(picker.find_child("MatchCrystal", true, false)).is_not_null()
	for index: int in 4:
		picker.crystal().toggle(index)
	picker.submit()
	assert_array(_submitted).is_equal([{"num": 1, "den": 2}]) # 4 of 8 matches 1 of 2


func test_a_disabled_crystal_takes_no_taps() -> void:
	var picker: CrystalPicker = await _make(4)
	picker.set_enabled(false)
	_click(picker.crystal(), picker.crystal().shard_center(1))
	picker.submit()
	assert_int(picker.crystal().crystal.lit_count()).is_equal(0)
	assert_array(_submitted).is_empty()
