# Mirrors scenes/zones/z06_gear_works/gear_bench.gd (P4-S30-02): a gear dragged from the tray snaps onto
# the axle with a finger, a stylus and a mouse; a tap places it too; dropping it anywhere else puts it
# back; the train turns once; Go hands the gear in; targets are touch-sized; and the art never allocates
# while a gear spins.
class_name GearBenchTest
extends GdUnitTestSuite

const PEN_TILT: Vector2 = Vector2(0.2, 0.1)

var _router: Node
var _bench: GearBench
var _chosen: Array[int] = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_chosen.clear()
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(driver: int = 24, tray: Array[int] = [8, 21, 24, 72], turns: int = 3) -> GearBench:
	_bench = load("res://scenes/zones/z06_gear_works/gear_bench.tscn").instantiate()
	_bench.router = _router
	_bench.speed_scale = 50.0
	_bench.size = Vector2(1200, 800)
	add_child(_bench)
	auto_free(_bench)
	_bench.gear_chosen.connect(func(teeth: int) -> void: _chosen.append(teeth))
	_bench.setup(driver, tray, turns)
	await await_idle_frame()
	await await_idle_frame()
	return _bench


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_dragging_a_gear_with_a_finger_snaps_it_onto_the_axle() -> void:
	var bench: GearBench = await _make()
	assert_bool(bench.go_button().disabled).is_true()
	InputSim.drag_path(_router, _center(bench.tray_gear(8)), _center(bench.axle()))
	assert_int(bench.placed_teeth()).is_equal(8)
	assert_bool(bench.placed_gear().visible).is_true()
	assert_bool(bench.placed_gear().get_global_rect().intersects(bench.axle().get_global_rect())).is_true()
	assert_bool(bench.go_button().disabled).is_false()
	assert_array(_chosen).is_empty() # placing is not answering: Go hands it in
	bench.go_button().pressed.emit()
	assert_array(_chosen).is_equal([8])


func test_a_stylus_drag_works_the_same() -> void:
	var bench: GearBench = await _make()
	var start: Vector2 = _center(bench.tray_gear(21))
	var target: Vector2 = _center(bench.axle())
	InputSim.touch(_router, start, true)
	for step: int in range(1, 5):
		InputSim.drag(_router, start.lerp(target, step / 4.0), 0, 0.5, PEN_TILT)
	InputSim.touch(_router, target, false)
	assert_int(bench.placed_teeth()).is_equal(21)


func test_a_mouse_drag_and_a_mouse_click_both_work() -> void:
	var bench: GearBench = await _make()
	InputSim.mouse_button(_router, _center(bench.tray_gear(72)), true)
	InputSim.mouse_move(_router, _center(bench.axle()))
	InputSim.mouse_button(_router, _center(bench.axle()), false)
	assert_int(bench.placed_teeth()).is_equal(72)
	InputSim.mouse_button(_router, _center(bench.tray_gear(24)), true)
	InputSim.mouse_button(_router, _center(bench.tray_gear(24)), false) # a click is a tap
	assert_int(bench.placed_teeth()).is_equal(24)


func test_a_tap_places_a_gear_and_another_swaps_it() -> void:
	var bench: GearBench = await _make()
	InputSim.tap(_router, _center(bench.tray_gear(24)))
	assert_int(bench.placed_teeth()).is_equal(24)
	InputSim.tap(_router, _center(bench.tray_gear(8)))
	assert_int(bench.placed_teeth()).is_equal(8)
	assert_bool(bench.tray_gear(8).highlighted).is_true()
	assert_bool(bench.tray_gear(24).highlighted).is_false()


func test_dropping_a_gear_on_nothing_puts_it_back() -> void:
	var bench: GearBench = await _make()
	var start: Vector2 = _center(bench.tray_gear(8))
	InputSim.drag_path(_router, start, start + Vector2(0, -300))
	assert_int(bench.placed_teeth()).is_equal(0)
	assert_bool(bench.is_dragging()).is_false()
	assert_bool(bench.go_button().disabled).is_true()


func test_a_palm_the_pen_took_over_drops_the_gear_back() -> void:
	var bench: GearBench = await _make()
	InputSim.touch(_router, _center(bench.tray_gear(8)), true)
	assert_bool(bench.is_dragging()).is_true()
	_router.pointer_cancelled.emit(0)
	assert_bool(bench.is_dragging()).is_false()
	assert_int(bench.placed_teeth()).is_equal(0)


func test_placing_a_gear_turns_the_train_once_by_the_gear_ratio() -> void:
	var bench: GearBench = await _make()
	var driver_start: float = bench.driver_gear().angle
	var placed_start: float = 0.0
	bench.place(8)
	placed_start = bench.placed_gear().angle
	assert_bool(bench.is_spinning()).is_true()
	assert_str(bench.message_text()).is_equal(Text.get_line(&"z6.bench.watch"))
	await await_millis(200)
	assert_bool(bench.is_spinning()).is_false()
	assert_float(bench.driver_gear().angle - driver_start).is_equal_approx(TAU, 0.001)
	assert_float(bench.placed_gear().angle - placed_start).is_equal_approx(-3.0 * TAU, 0.001) # 24 / 8 turns, the other way
	assert_str(bench.message_text()).is_equal(Text.get_line(&"z6.bench.drag_gear"))


func test_a_disabled_bench_takes_nothing() -> void:
	var bench: GearBench = await _make()
	bench.set_enabled(false)
	InputSim.tap(_router, _center(bench.tray_gear(8)))
	assert_int(bench.placed_teeth()).is_equal(0)
	assert_bool(bench.place(8)).is_false()
	bench.set_enabled(true)
	assert_bool(bench.place(8)).is_true()
	bench.set_enabled(false)
	bench.submit()
	assert_array(_chosen).is_empty()


func test_only_tray_gears_can_be_placed() -> void:
	var bench: GearBench = await _make()
	assert_bool(bench.place(13)).is_false()
	assert_int(bench.placed_teeth()).is_equal(0)


func test_tray_gears_and_go_are_touch_sized() -> void:
	var bench: GearBench = await _make()
	var least: float = float(UI.min_target_px())
	for gear: Gear in bench.tray_gears():
		assert_float(gear.size.x).is_greater_equal(least)
		assert_float(gear.size.y).is_greater_equal(least)
	assert_float(bench.go_button().size.y).is_greater_equal(least)
	assert_float(bench.axle().size.x).is_greater_equal(least)


func test_every_gear_stays_on_the_stage_even_the_biggest() -> void:
	var bench: GearBench = await _make(12, [6, 9, 12, 192], 2)
	bench.place(192)
	var stage: Rect2 = bench.find_child("Stage", true, false).get_global_rect().grow(2.0)
	assert_bool(stage.encloses(bench.driver_gear().get_global_rect())).is_true()
	assert_bool(stage.encloses(bench.placed_gear().get_global_rect())).is_true()


func test_gear_art_refills_its_buffer_without_resizing_while_spinning() -> void:
	var art: GearArt = GearArt.new()
	var first: PackedVector2Array = art.outline(Vector2(50, 50), 40.0, 12, 0.0)
	assert_int(first.size()).is_equal(48)
	var turned: PackedVector2Array = art.outline(Vector2(50, 50), 40.0, 12, 1.0)
	assert_int(turned.size()).is_equal(48)
	assert_bool(turned[0] != Vector2.ZERO).is_true()
	assert_int(art.outline(Vector2(50, 50), 40.0, 500, 0.0).size()).is_equal(GearArt.MAX_DRAWN_TEETH * 4)
	assert_float(GearArt.radius_for(48, 10.0)).is_equal_approx(20.0, 0.001)
	assert_float(GearArt.radius_for(1000, 10.0)).is_equal_approx(10.0 * GearArt.MAX_RADIUS_SCALE, 0.001)
