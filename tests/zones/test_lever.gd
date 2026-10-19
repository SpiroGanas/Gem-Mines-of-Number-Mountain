# The counterweight lever (Zone 8, Sprint 36, P4-S36-03): Lever is the pure rule (weight × distance on
# each side; the heavier side goes down), the scene's More and Less set the counterweight and its beam
# leans the way the rule says, and the tower elevator's floors are powers of the base.
class_name LeverTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())


func after_test() -> void:
	TestWindow.restore(get_window())


func test_eight_at_two_balances_four_at_four() -> void:
	assert_str(Lever.side_heavier(8, 2, 4, 4)).is_equal("level")
	assert_str(Lever.side_heavier(8, 2, 3, 4)).is_equal("left")
	assert_str(Lever.side_heavier(8, 2, 5, 4)).is_equal("right")
	var lever: Lever = Lever.make(8, 2, 4, 32)
	assert_bool(lever.is_balanced()).is_false()
	lever.set_weight(4)
	assert_bool(lever.is_balanced()).is_true()
	assert_int(lever.add_weight(100)).is_equal(32) # never past the counterweight's range
	assert_int(lever.add_weight(-100)).is_equal(0)


func test_the_scene_sets_the_weight_and_leans_the_beam() -> void:
	var scene: CounterweightLever = load("res://scenes/zones/z08_power_tower/counterweight.tscn").instantiate()
	add_child(scene)
	auto_free(scene)
	scene.speed_scale = 0.0
	scene.setup(8, 2, 4, 32)
	assert_float(scene.beam_angle()).is_less(0.0) # empty right hook: the left side is down
	var given: Array = []
	scene.submitted.connect(func(weight: int) -> void: given.append(weight))
	for press: int in 4:
		scene.more_button().pressed.emit()
	assert_float(scene.beam_angle()).is_equal(0.0)
	scene.more_button().pressed.emit()
	assert_float(scene.beam_angle()).is_greater(0.0)
	scene.less_button().pressed.emit()
	scene.balance_button().pressed.emit()
	assert_array(given).is_equal([4])
	await await_idle_frame()
	var needed: Vector2 = scene.get_combined_minimum_size() / float(UI.min_target_px())
	assert_float(needed.y).is_less_equal(4.5) # fits a landscape phone
	for button: Button in [scene.more_button(), scene.less_button(), scene.balance_button()]:
		assert_float(button.size.y).is_greater_equal(float(UI.min_target_px()))


func test_the_tower_floors_double_and_the_cab_stays_inside() -> void:
	var ride: TowerRide = TowerRide.make(2, 10, 0)
	assert_int(ride.height_of(0)).is_equal(1)
	assert_int(ride.height_of(5)).is_equal(32)
	assert_int(ride.height_of(10)).is_equal(1024)
	assert_bool(ride.was_visited(0)).is_true()
	assert_bool(ride.was_visited(3)).is_false()
	ride.move(3)
	assert_bool(ride.was_visited(3) and ride.was_visited(3)).is_true()
	assert_int(ride.move(-10)).is_equal(0)
	assert_int(ride.move(20)).is_equal(10)
	assert_bool(ride.can_go_up()).is_false()


func test_the_tower_elevator_rides_and_stops() -> void:
	var tower: TowerElevator = load("res://scenes/zones/z08_power_tower/tower_elevator.tscn").instantiate()
	add_child(tower)
	auto_free(tower)
	tower.speed_scale = 0.0
	tower.setup(2, 6, 0)
	var stopped: Array = []
	tower.submitted.connect(func(floor_number: int) -> void: stopped.append(floor_number))
	assert_bool(tower.down_button().disabled).is_true()
	for press: int in 5:
		tower.up_button().pressed.emit()
	assert_str(tower.find_child("Height", true, false).text).contains("32")
	tower.stop_button().pressed.emit()
	assert_array(stopped).is_equal([5])
	await await_idle_frame()
	var needed: Vector2 = tower.get_combined_minimum_size() / float(UI.min_target_px())
	assert_float(needed.y).override_failure_message("%s tall" % needed.y).is_less_equal(4.6)
