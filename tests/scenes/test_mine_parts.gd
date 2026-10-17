# Mirrors scenes/mine/rock.tscn, rock_wall.tscn, cart.tscn and bolt.tscn.
class_name MinePartsTest
extends GdUnitTestSuite

const FAST: float = 25.0


func _rock(index: int = 0) -> Rock:
	var rock: Rock = load("res://scenes/mine/rock.tscn").instantiate()
	rock.rock_index = index
	rock.speed_scale = FAST
	add_child(rock)
	auto_free(rock)
	return rock


func _until(condition: Callable, max_frames: int = 400) -> void:
	var frames: int = 0
	while not condition.call() and frames < max_frames:
		await get_tree().process_frame
		frames += 1


# --- Rock -----------------------------------------------------------------------------


func test_a_rock_is_a_full_size_touch_target_and_starts_idle() -> void:
	var rock: Rock = _rock()
	assert_int(rock.rock_state).is_equal(Rock.RockState.IDLE)
	assert_float(rock.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()) * 2.0)
	assert_float(rock.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()) * 2.0)
	assert_bool(rock.gem_is_visible()).is_false()
	assert_str(rock.text).is_empty() # a rock never shows a number


func test_a_wobble_finishes_and_leaves_the_rock_open_for_another_try() -> void:
	var rock: Rock = _rock()
	rock.set_rock_state(Rock.RockState.SELECTED)
	monitor_signals(rock, false)
	rock.play_wobble()
	assert_int(rock.rock_state).is_equal(Rock.RockState.WOBBLING)
	await assert_signal(rock).wait_until(2000).is_emitted("wobble_finished")
	assert_int(rock.rock_state).is_equal(Rock.RockState.SELECTED)
	assert_float(rock.rotation).is_equal_approx(0.0, 0.001)
	assert_bool(rock.disabled).is_false()


func test_a_crack_reveals_the_gem_and_locks_the_rock() -> void:
	var rock: Rock = _rock()
	monitor_signals(rock, false)
	rock.play_crack(GemArt.GARNET)
	await assert_signal(rock).wait_until(2000).is_emitted("crack_finished")
	assert_int(rock.rock_state).is_equal(Rock.RockState.CRACKED)
	assert_bool(rock.gem_is_visible()).is_true()
	assert_str(rock.gem_type()).is_equal(GemArt.GARNET)
	assert_bool(rock.disabled).is_true()
	assert_vector(rock.scale).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001)) # squash and stretch settled


func test_taking_the_gem_hides_it_but_the_rock_stays_open() -> void:
	var rock: Rock = _rock()
	rock.play_crack(GemArt.QUARTZ)
	await _until(func() -> bool: return rock.scale.is_equal_approx(Vector2.ONE) and rock.rock_state == Rock.RockState.CRACKED and rock.gem_is_visible())
	rock.take_gem()
	assert_bool(rock.gem_is_visible()).is_false()
	assert_int(rock.rock_state).is_equal(Rock.RockState.CRACKED)


func test_the_gem_sits_inside_the_rock() -> void:
	var rock: Rock = _rock()
	rock.size = Vector2(300, 240)
	rock.play_crack(GemArt.QUARTZ)
	await get_tree().process_frame
	assert_bool(rock.get_global_rect().has_point(rock.gem_center())).is_true()


# --- Rock wall ------------------------------------------------------------------------


func _wall(count: int) -> RockWall:
	var wall: RockWall = load("res://scenes/mine/rock_wall.tscn").instantiate()
	wall.speed_scale = FAST
	add_child(wall)
	auto_free(wall)
	wall.build(count)
	return wall


func test_a_wall_has_the_requested_number_of_rocks_up_to_nine() -> void:
	for count: int in range(RockWall.MIN_ROCKS, RockWall.MAX_ROCKS + 1):
		assert_int(_wall(count).rock_count()).is_equal(count)
	assert_int(_wall(20).rock_count()).is_equal(RockWall.MAX_ROCKS)


func test_tapping_a_rock_reports_its_index() -> void:
	var wall: RockWall = _wall(6)
	var heard: Array[int] = []
	wall.rock_selected.connect(func(index: int) -> void: heard.append(index))
	wall.rock(4).pressed.emit()
	wall.rock(0).pressed.emit()
	assert_array(heard).contains_exactly([4, 0])


func test_only_the_chosen_rock_is_marked_selected() -> void:
	var wall: RockWall = _wall(6)
	wall.mark_selected(2)
	for index: int in 6:
		var expected: int = Rock.RockState.SELECTED if index == 2 else Rock.RockState.IDLE
		assert_int(wall.rock(index).rock_state).override_failure_message("rock %d" % index).is_equal(expected)
	wall.clear_selection()
	assert_int(wall.rock(2).rock_state).is_equal(Rock.RockState.IDLE)


func test_a_cracked_rock_is_never_reselected_or_enabled() -> void:
	var wall: RockWall = _wall(6)
	wall.rock(1).set_rock_state(Rock.RockState.CRACKED)
	wall.mark_selected(1)
	wall.set_interactive(true)
	assert_int(wall.rock(1).rock_state).is_equal(Rock.RockState.CRACKED)
	assert_bool(wall.rock(1).disabled).is_true()
	assert_bool(wall.rock(0).disabled).is_false()
	wall.set_interactive(false)
	assert_bool(wall.rock(0).disabled).is_true()


func test_rebuilding_replaces_the_rocks() -> void:
	var wall: RockWall = _wall(9)
	wall.build(6)
	await get_tree().process_frame
	assert_int(wall.rock_count()).is_equal(6)
	assert_int(wall.get_child_count()).is_equal(6)


func test_every_rock_looks_different() -> void:
	var a: Rock = _rock(0)
	var b: Rock = _rock(1)
	assert_int(a.rock_index).is_not_equal(b.rock_index) # facets are seeded from the index


# --- Cart -----------------------------------------------------------------------------


func _cart() -> Cart:
	var cart: Cart = load("res://scenes/mine/cart.tscn").instantiate()
	cart.speed_scale = FAST
	add_child(cart)
	auto_free(cart)
	return cart


func test_the_cart_shows_coin_and_gem_totals_from_the_text_table() -> void:
	var cart: Cart = _cart()
	cart.set_totals(7, 3)
	assert_int(cart.coins_shown()).is_equal(7)
	assert_int(cart.gems_shown()).is_equal(3)
	var labels: Array[Node] = cart.find_children("*", "Label", true, false)
	assert_str((labels[0] as Label).text).is_equal("Coins: 7")
	assert_str((labels[1] as Label).text).is_equal("Gems: 3")


func test_a_flying_gem_lands_in_the_cart_and_is_cleaned_up() -> void:
	var cart: Cart = _cart()
	var fx: Control = auto_free(Control.new())
	add_child(fx)
	monitor_signals(cart, false)
	cart.receive_gem(GemArt.PYRITE, Vector2(400, 100), fx)
	assert_int(fx.get_child_count()).is_equal(1)
	await assert_signal(cart).wait_until(3000).is_emitted("gem_landed", [GemArt.PYRITE])
	await get_tree().process_frame
	assert_int(fx.get_child_count()).is_equal(0)


# --- Bolt -----------------------------------------------------------------------------


func test_bolt_says_lines_from_the_table_with_params_filled() -> void:
	var bolt: Bolt = load("res://scenes/mine/bolt.tscn").instantiate()
	add_child(bolt)
	auto_free(bolt)
	bolt.say(&"z1.dig.prompt_build_number", {"n": 34})
	assert_str(bolt.spoken_text()).is_equal("Build 34 with ten-bars and one-gems.")
	assert_str(bolt.current_line_id()).is_equal("z1.dig.prompt_build_number")
	bolt.say(&"bolt.feedback.not_quite")
	assert_str(bolt.spoken_text()).is_equal("Not quite. Let's look again.")


func test_a_note_goes_under_the_main_line_and_saying_a_new_line_clears_it() -> void:
	var bolt: Bolt = load("res://scenes/mine/bolt.tscn").instantiate()
	add_child(bolt)
	auto_free(bolt)
	bolt.say(&"z1.dig.prompt_build_number", {"n": 58})
	bolt.note(&"bolt.feedback.not_quite")
	assert_str(bolt.spoken_text()).is_equal("Build 58 with ten-bars and one-gems.") # the problem stays
	assert_str(bolt.note_text()).is_equal("Not quite. Let's look again.")
	assert_str(bolt.current_note_id()).is_equal("bolt.feedback.not_quite")
	bolt.say(&"bolt.mine.pick_rock")
	assert_str(bolt.note_text()).is_empty()
	bolt.note(&"bolt.feedback.correct")
	bolt.say(&"bolt.mine.pick_rock", {}, true) # keep_note: praise survives the next prompt
	assert_str(bolt.note_text()).is_equal("That's it! Nice work.")
	bolt.clear_note()
	assert_str(bolt.note_text()).is_empty()
