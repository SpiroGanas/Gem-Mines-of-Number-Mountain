# Mirrors scenes/mine/hello_rock.tscn (Sprint 1 device test; removed with it in Sprint 4).
class_name HelloRockTest
extends GdUnitTestSuite

const SCENE_PATH: String = "res://scenes/mine/hello_rock.tscn"


func test_scene_instantiates_with_a_rock_at_least_the_minimum_target() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATH)
	var rock: HelloRock = runner.scene()
	assert_object(rock).is_not_null()
	assert_int(rock.state).is_equal(HelloRock.RockState.IDLE)
	var button: TextureButton = rock.find_child("Rock")
	assert_object(button).is_not_null()
	assert_int(int(button.custom_minimum_size.x)).is_greater_equal(UI.min_target_px())
	assert_int(int(button.custom_minimum_size.x)).is_greater_equal(HelloRock.ROCK_MIN_PX)
	assert_object(button.texture_normal).is_same(rock.rock_idle)


func test_tap_wobbles_cracks_then_resets() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATH)
	var rock: HelloRock = runner.scene()
	var button: TextureButton = rock.find_child("Rock")

	rock.tap()
	assert_int(rock.state).is_equal(HelloRock.RockState.WOBBLING)
	assert_int(rock.taps).is_equal(1)

	await assert_signal(rock).wait_until(2000).is_emitted("cracked")
	assert_int(rock.state).is_equal(HelloRock.RockState.CRACKED)
	assert_object(button.texture_normal).is_same(rock.rock_cracked)

	await assert_signal(rock).wait_until(3000).is_emitted("reset")
	assert_int(rock.state).is_equal(HelloRock.RockState.IDLE)
	assert_object(button.texture_normal).is_same(rock.rock_idle)
	assert_float(button.rotation).is_equal(0.0)


func test_taps_while_busy_are_ignored() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATH)
	var rock: HelloRock = runner.scene()
	rock.tap()
	rock.tap()
	rock.tap()
	assert_int(rock.taps).is_equal(1)
	await assert_signal(rock).wait_until(3000).is_emitted("reset")


func test_ui_min_target_px_never_below_64() -> void:
	assert_int(UI.min_target_px()).is_greater_equal(64)
	assert_float(UI.scale_factor()).is_greater(0.0)
