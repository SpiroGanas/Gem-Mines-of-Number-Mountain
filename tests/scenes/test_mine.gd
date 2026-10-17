# Mirrors scenes/mine/mine.tscn: the whole dig loop (P1-S04-01), end to end.
class_name MineTest
extends GdUnitTestSuite

const MINE_SCENE: String = "res://scenes/mine/mine.tscn"

var _mine: MineScreen
var _dir: String
var _sounds: Array[StringName] = []


func before_test() -> void:
	TestWindow.use_design_size(get_window()) # the headless window is 64x64; see TestWindow
	_dir = create_temp_dir("mine_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_sounds.clear()
	_mine = _make_mine(12345)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


## A mine for the tests. By default its wall holds only build problems (a drag board), so the loop
## tests can build answers; pass all_skills for a wall mixing every Zone 1 skill.
func _make_mine(seed_value: int, all_skills: bool = false) -> MineScreen:
	var mine: MineScreen = load(MINE_SCENE).instantiate()
	mine.animation_speed = 25.0
	mine.seed_value = seed_value
	var only: Array[StringName] = [&"pv.tens_ones.build"]
	if all_skills:
		only.clear()
		for skill: Skill in SkillCatalog.load_all().skills_in_zone(1):
			only.append(skill.id)
	mine.skill_ids = only
	add_child(mine)
	auto_free(mine)
	mine.sfx().played.connect(func(id: StringName) -> void: _sounds.append(id))
	return mine


func _until(condition: Callable, max_frames: int = 600) -> void:
	var frames: int = 0
	while not condition.call() and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	assert_bool(condition.call()).override_failure_message("timed out waiting after %d frames (state %s)" % [frames, DigFlow.State.keys()[_mine.flow.state]]).is_true()


func _wait_state(state: DigFlow.State) -> void:
	await _until(func() -> bool: return _mine.flow.state == state)


## Fills the tray with `tens` ten-bars and `ones` one-gems through the board's own tray.
func _build(tens: int, ones: int) -> void:
	var tray: DragTarget = _mine.board().tray()
	tray.clear()
	for i: int in tens:
		tray.add_item(DragItem.make(DragItem.TEN))
	for i: int in ones:
		tray.add_item(DragItem.make(DragItem.ONE))


## Taps a rock and waits until its problem is open for answers.
func _open(index: int) -> void:
	_mine.wall().rock(index).pressed.emit()
	await _wait_state(DigFlow.State.AWAIT_ANSWER)


func _answer(correct: bool) -> void:
	var answer: Dictionary = _mine.current_problem().answer
	if correct:
		_build(answer["tens"], answer["ones"])
	else:
		_build(answer["tens"] + 1, answer["ones"]) # one ten too many is never right
	_mine.board().done_button().pressed.emit()


## Opens a rock, answers correctly, and waits until the gem has landed.
func _solve(index: int) -> void:
	await _open(index)
	_answer(true)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK or _mine.flow.state == DigFlow.State.WALL_CLEAR)


# --- Starting -------------------------------------------------------------------------


func test_a_wall_of_six_to_nine_rocks_waits_for_a_pick() -> void:
	assert_int(_mine.wall().rock_count()).is_between(RockWall.MIN_ROCKS, RockWall.MAX_ROCKS)
	assert_int(_mine.flow.state).is_equal(DigFlow.State.PICK_ROCK)
	assert_str(_mine.bolt().current_line_id()).is_equal("bolt.mine.pick_rock")
	assert_int(_mine.cart().coins_shown()).is_equal(0)
	assert_bool(_mine.board() == null).is_true()
	for index: int in _mine.wall().rock_count():
		assert_bool(_mine.wall().rock(index).disabled).is_false()


func test_the_same_seed_gives_the_same_wall_and_problems() -> void:
	assert_object(_mine.problem_for(0)).is_null() # chosen when the rock is picked, not before
	var first: MineScreen = _mine
	await _open(0)
	var other: MineScreen = _make_mine(12345)
	_mine = other
	await _open(0)
	assert_int(other.wall().rock_count()).is_equal(first.wall().rock_count())
	assert_dict(other.problem_for(0).to_json()).is_equal(first.problem_for(0).to_json())


# --- Picking and answering -----------------------------------------------------------


func test_picking_a_rock_opens_its_problem_with_the_number_in_the_prompt() -> void:
	await _open(2)
	var problem: Problem = _mine.current_problem()
	var n: int = problem.prompt_params["n"]
	assert_str(_mine.bolt().spoken_text()).is_equal("Build %d with ten-bars and one-gems." % n)
	assert_object(_mine.board()).is_not_null()
	assert_int(_mine.wall().rock(2).rock_state).is_equal(Rock.RockState.SELECTED)
	for index: int in _mine.wall().rock_count():
		assert_bool(_mine.wall().rock(index).disabled).override_failure_message("rock %d should be locked" % index).is_true()


func test_a_correct_answer_cracks_the_rock_and_pays_coins_and_a_gem() -> void:
	await _solve(0)
	assert_bool(_mine.flow.is_cracked(0)).is_true()
	assert_int(_mine.wall().rock(0).rock_state).is_equal(Rock.RockState.CRACKED)
	assert_int(_mine.cart().coins_shown()).is_equal(DigFlow.COINS_FIRST_TRY)
	assert_int(_mine.cart().gems_shown()).is_equal(1)
	assert_bool(_mine.wall().rock(0).gem_is_visible()).is_false() # it flew to the cart
	assert_bool(_mine.wall().rock(0).disabled).is_true() # an open rock cannot be picked again
	assert_bool(_mine.board() == null).is_true()


func test_a_first_try_success_gets_the_plain_praise_line() -> void:
	await _open(0)
	_answer(true)
	await _wait_state(DigFlow.State.GEM_DROP)
	assert_str(_mine.bolt().note_text()).is_equal("That's it! Nice work.")


func test_the_praise_stays_up_after_a_rock_and_clears_when_the_next_one_opens() -> void:
	await _solve(0)
	assert_str(_mine.bolt().current_line_id()).is_equal("bolt.mine.pick_rock")
	assert_str(_mine.bolt().note_text()).is_equal("That's it! Nice work.") # still readable
	await _open(1)
	assert_str(_mine.bolt().note_text()).is_empty()


func test_the_game_saves_after_every_rock() -> void:
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_false()
	await _solve(1)
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_true()


func test_a_not_quite_answer_wobbles_costs_nothing_and_allows_another_try() -> void:
	await _open(3)
	_answer(false)
	await _wait_state(DigFlow.State.WOBBLE)
	await _wait_state(DigFlow.State.AWAIT_ANSWER) # wobble, then the hint, then back to answering
	assert_str(_mine.bolt().note_text()).is_equal("Not quite. Let's look again.\nHere it is again. Look at these words.")
	# The problem stays on screen under the feedback: the child must still see the number.
	assert_str(_mine.bolt().spoken_text()).is_equal("Build %d with ten-bars and one-gems." % _mine.current_problem().prompt_params["n"])
	assert_bool(_mine.flow.is_cracked(3)).is_false()
	assert_int(_mine.cart().coins_shown()).is_equal(0)
	assert_int(_mine.wall().rock(3).rock_state).is_equal(Rock.RockState.SELECTED)
	assert_dict(_mine.board().answer()).is_not_equal({"tens": 0, "ones": 0}) # the child's build is kept to adjust
	_answer(true)
	await _until(func() -> bool: return _mine.flow.is_cracked(3) and _mine.flow.state == DigFlow.State.PICK_ROCK)
	assert_int(_mine.cart().coins_shown()).is_equal(DigFlow.COINS_AFTER_HINT) # a hint-assisted rock still pays
	assert_str(_mine.bolt().current_note_id()).is_equal("bolt.feedback.correct_hint")


func test_many_not_quite_answers_cost_nothing_and_never_end_the_game() -> void:
	await _solve(0)
	var coins: int = _mine.cart().coins_shown()
	var gems: int = _mine.cart().gems_shown()
	await _open(1)
	for attempt: int in 8:
		_answer(false)
		await _wait_state(DigFlow.State.WOBBLE)
		await _wait_state(DigFlow.State.AWAIT_ANSWER)
	assert_int(_mine.cart().coins_shown()).is_equal(coins)
	assert_int(_mine.cart().gems_shown()).is_equal(gems)
	assert_int(_mine.flow.rocks_left()).is_equal(_mine.wall().rock_count() - 1)
	assert_bool(_mine.get_tree().paused).is_false()


func test_an_empty_tray_is_just_a_not_quite_answer() -> void:
	await _open(0)
	_build(0, 0)
	_mine.board().done_button().pressed.emit()
	await _wait_state(DigFlow.State.WOBBLE)
	assert_bool(_mine.flow.is_cracked(0)).is_false()


# --- A whole wall ---------------------------------------------------------------------


func test_clearing_the_wall_offers_head_up_or_dig_more() -> void:
	var cleared: Array[bool] = [false]
	_mine.wall_cleared.connect(func() -> void: cleared[0] = true)
	var count: int = _mine.wall().rock_count()
	for index: int in count:
		await _solve(index)
	assert_int(_mine.flow.state).is_equal(DigFlow.State.WALL_CLEAR)
	assert_bool(cleared[0]).is_true()
	assert_str(_mine.bolt().current_line_id()).is_equal("bolt.mine.wall_clear")
	assert_bool(_mine.find_child("WallClear", true, false).visible).is_true()
	assert_int(_mine.cart().coins_shown()).is_equal(count * DigFlow.COINS_FIRST_TRY)
	assert_int(_mine.cart().gems_shown()).is_equal(count)


func test_dig_more_builds_a_fresh_wall_and_keeps_the_cart_total() -> void:
	for index: int in _mine.wall().rock_count():
		await _solve(index)
	var coins: int = _mine.cart().coins_shown()
	_mine.find_child("DigMoreButton", true, false).pressed.emit()
	assert_int(_mine.flow.state).is_equal(DigFlow.State.PICK_ROCK)
	assert_int(_mine.flow.rocks_left()).is_equal(_mine.wall().rock_count())
	assert_bool(_mine.find_child("WallClear", true, false).visible).is_false()
	assert_int(_mine.cart().coins_shown()).is_equal(coins)
	assert_bool(_mine.wall().rock(0).disabled).is_false()


func test_head_up_asks_the_shell_for_the_hub() -> void:
	for index: int in _mine.wall().rock_count():
		await _solve(index)
	var requested: Array[StringName] = []
	_mine.request_screen.connect(func(id: StringName, _args: Dictionary) -> void: requested.append(id))
	_mine.find_child("HeadUpButton", true, false).pressed.emit()
	assert_array(requested).contains_exactly([&"hub"])


func test_the_pause_button_asks_the_shell_to_pause() -> void:
	monitor_signals(_mine, false)
	_mine.find_child("PauseButton", true, false).pressed.emit()
	await assert_signal(_mine).is_emitted("pause_requested")


func test_rocks_can_be_cracked_in_any_order() -> void:
	var count: int = _mine.wall().rock_count()
	for index: int in [count - 1, 0, 2]:
		await _solve(index)
	assert_int(_mine.flow.rocks_left()).is_equal(count - 3)


# --- Sound, text and input ------------------------------------------------------------


func test_every_action_in_a_rock_makes_a_sound() -> void:
	await _open(0) # select
	_build(1, 0)
	_answer(false) # place sounds came from the tray; Done, wobble and the soft miss follow
	await _wait_state(DigFlow.State.WOBBLE)
	await _wait_state(DigFlow.State.AWAIT_ANSWER)
	_answer(true)
	await _until(func() -> bool: return _mine.flow.is_cracked(0) and _mine.flow.state == DigFlow.State.PICK_ROCK)
	for expected: StringName in [&"select", &"tap", &"wobble", &"soft_miss", &"crack", &"gem", &"coin"]:
		assert_bool(_sounds.has(expected)).override_failure_message("no '%s' sound; heard %s" % [expected, _sounds]).is_true()


func test_clearing_the_wall_plays_the_fanfare() -> void:
	for index: int in _mine.wall().rock_count():
		await _solve(index)
	assert_bool(_sounds.has(&"fanfare")).is_true()


func test_placing_and_removing_pieces_make_sounds() -> void:
	await _open(0)
	var board: BuildBoard = _mine.board()
	board.item_placed.emit(DragItem.ONE)
	board.item_removed.emit(DragItem.ONE)
	assert_bool(_sounds.has(&"place")).is_true()
	assert_bool(_sounds.has(&"tap")).is_true()


func test_every_visible_word_comes_from_the_text_table() -> void:
	await _open(0)
	for node: Node in _mine.find_children("*", "", true, false):
		var shown: String = ""
		if node is Label:
			shown = (node as Label).text
		elif node is Button:
			shown = (node as Button).text
		if shown == "":
			continue
		assert_bool(shown.begins_with("[") and shown.ends_with("]")).override_failure_message("%s shows a missing line: %s" % [node.name, shown]).is_false()
		assert_bool(shown.contains("{")).override_failure_message("%s has an unfilled placeholder: %s" % [node.name, shown]).is_false()


func test_every_button_is_a_full_size_touch_target_and_there_is_no_text_field() -> void:
	await _open(0)
	for node: Node in _mine.find_children("*", "Button", true, false):
		var button: Button = node
		assert_float(button.custom_minimum_size.x).override_failure_message(button.name + " too small").is_greater_equal(float(UI.min_target_px()))
		assert_float(button.custom_minimum_size.y).override_failure_message(button.name + " too small").is_greater_equal(float(UI.min_target_px()))
	for forbidden: String in ["LineEdit", "TextEdit", "SpinBox"]:
		assert_array(_mine.find_children("*", forbidden, true, false)).is_empty()


func test_a_rock_can_be_solved_by_dragging_pieces_with_synthetic_touch() -> void:
	# The real thing a child does: tap a rock, then drag pieces from the piles into the tray
	# with a finger. Events go through the global InputRouter, as they do in the game.
	await _open(0)
	var answer: Dictionary = _mine.current_problem().answer
	await get_tree().process_frame
	await get_tree().process_frame
	var board: BuildBoard = _mine.board()
	for i: int in answer["tens"]:
		InputSim.drag_path(InputRouter, board.source(DragItem.TEN).get_global_rect().get_center(), board.tray().get_global_rect().get_center(), 5)
	for i: int in answer["ones"]:
		InputSim.drag_path(InputRouter, board.source(DragItem.ONE).get_global_rect().get_center(), board.tray().get_global_rect().get_center(), 5)
	assert_dict(board.answer()).is_equal({"tens": answer["tens"], "ones": answer["ones"]})
	board.done_button().pressed.emit()
	await _until(func() -> bool: return _mine.flow.is_cracked(0))
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	assert_int(_mine.cart().coins_shown()).is_equal(DigFlow.COINS_FIRST_TRY)


# --- Mixed Zone 1 walls (Sprint 5): every skill, answered through its own widget -------------


## Opens a rock and gives `correct` or a named-wrong answer through the widget the problem got.
func _answer_through_the_panel(index: int, correct: bool) -> void:
	await _open(index)
	var problem: Problem = _mine.current_problem()
	var target: Variant = problem.answer if correct else PanelDriver.wrong_value(problem)
	assert_bool(PanelDriver.give(_mine.answer_panel(), target)).override_failure_message("%s: could not give %s" % [problem.skill_id, target]).is_true()


func test_mixed_walls_of_every_zone_1_skill_can_be_cleared() -> void:
	var seen: Dictionary = {}
	for seed_value: int in [11, 12, 13, 14, 15]:
		var mine: MineScreen = _make_mine(seed_value, true)
		_mine = mine
		for index: int in mine.wall().rock_count():
			await _answer_through_the_panel(index, true)
			seen[mine.problem_for(index).skill_id] = true
			await _until(func() -> bool: return mine.flow.is_cracked(index) and (mine.flow.state == DigFlow.State.PICK_ROCK or mine.flow.state == DigFlow.State.WALL_CLEAR))
		assert_int(mine.flow.state).is_equal(DigFlow.State.WALL_CLEAR)
		assert_int(mine.cart().gems_shown()).is_equal(mine.wall().rock_count())
		mine.queue_free()
	assert_int(seen.size()).is_greater(8) # a good spread of the 17 skills turned up


func test_a_wrong_answer_on_any_skill_wobbles_costs_nothing_and_keeps_the_problem_visible() -> void:
	var skills: Dictionary = {}
	for seed_value: int in range(21, 41):
		var mine: MineScreen = _make_mine(seed_value, true)
		_mine = mine
		await _answer_through_the_panel(0, false)
		var problem: Problem = mine.current_problem()
		skills[problem.skill_id] = true
		await _wait_state(DigFlow.State.WOBBLE)
		await _wait_state(DigFlow.State.AWAIT_ANSWER)
		assert_bool(mine.flow.is_cracked(0)).override_failure_message(problem.skill_id).is_false()
		assert_int(mine.cart().coins_shown()).is_equal(0)
		assert_int(mine.cart().gems_shown()).is_equal(0)
		assert_str(mine.bolt().note_text()).starts_with("Not quite. Let's look again.")
		assert_str(mine.bolt().spoken_text()).is_equal(Text.get_line(problem.prompt_line_id, problem.prompt_params)) # still readable
		mine.queue_free()
	assert_int(skills.size()).is_greater(5)


# --- The adaptive engine and the hint ladder (Sprint 6) --------------------------------------


func test_every_answer_is_logged_with_its_hint_count() -> void:
	await _open(0)
	_answer(false)
	await _wait_state(DigFlow.State.AWAIT_ANSWER)
	_answer(true)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	var entries: Array = SaveSystem.read_attempts()["entries"]
	assert_int(entries.size()).is_equal(2)
	assert_str(entries[0]["skill_id"]).is_equal("pv.tens_ones.build")
	assert_bool(entries[0]["correct"]).is_false()
	assert_int(entries[0]["hints_used"]).is_equal(0)
	assert_bool(entries[1]["correct"]).is_true()
	assert_int(entries[1]["hints_used"]).is_equal(1)
	assert_str(entries[1]["answer_mode"]).is_equal("drag")
	assert_str(entries[1]["session_id"]).is_equal(entries[0]["session_id"])
	assert_float(SaveSystem.data()["skills"]["pv.tens_ones.build"]["p_learned"]).is_greater(0.0)


func test_rung_1_repeats_the_problem_with_its_numbers_highlighted() -> void:
	await _open(0)
	_answer(false)
	await _wait_state(DigFlow.State.AWAIT_ANSWER)
	assert_array(_mine.bolt().highlighted_params()).contains_exactly(["n"])
	var n: int = _mine.current_problem().prompt_params["n"]
	assert_str(_mine.bolt().spoken_bbcode()).contains("[color=%s]%d[/color]" % [Text.HIGHLIGHT_COLOR, n])
	assert_object(_mine.answer_panel().hint_visual()).is_null() # the picture waits for rung 2


func test_rung_2_shows_the_picture_model() -> void:
	await _open(0)
	for miss: int in 2:
		_answer(false)
		await _wait_state(DigFlow.State.WOBBLE)
		await _wait_state(DigFlow.State.AWAIT_ANSWER)
	var model: VisualModel = _mine.answer_panel().hint_visual()
	assert_object(model).is_not_null()
	assert_dict(model.visual).is_equal(_mine.current_problem().hint_steps[1]["visual"])
	assert_str(_mine.bolt().note_text()).contains(Text.get_line(&"bolt.hint.show_model"))


func test_a_dig_with_no_skill_limit_starts_where_the_engine_says() -> void:
	var mine: MineScreen = load(MINE_SCENE).instantiate()
	mine.animation_speed = 25.0
	mine.seed_value = 7
	add_child(mine)
	auto_free(mine)
	_mine = mine
	await _open(0)
	assert_str(mine.current_problem().skill_id).is_equal("count.to_20.objects") # a new miner starts at the root


func test_a_problem_shows_its_word_gems_and_a_tap_opens_the_card() -> void:
	await _open(0)
	var chips: Array[Button] = _mine.bolt().term_chips()
	assert_int(chips.size()).is_equal(_mine.current_problem().skill_id.length() * 0 + Adaptive.catalog().skill(&"pv.tens_ones.build").terms.size())
	chips[0].pressed.emit()
	assert_bool(_mine.word_gem_card().visible).is_true()
	assert_bool(_sounds.has(&"select")).is_true()
	_mine.word_gem_card().ok_button().pressed.emit()
	assert_int(_mine.flow.state).is_equal(DigFlow.State.AWAIT_ANSWER) # nothing about the rock changed


func test_a_named_mistake_gets_bolts_targeted_hint() -> void:
	await _open(0)
	var problem: Problem = _mine.current_problem()
	var swapped: Dictionary = {}
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == &"digit_swap":
			swapped = entry["value"]
	assert_dict(swapped).override_failure_message("seed 12345's first rock should have a digit swap").is_not_empty()
	_build(swapped["tens"], swapped["ones"])
	_mine.board().done_button().pressed.emit()
	await _wait_state(DigFlow.State.AWAIT_ANSWER)
	assert_str(_mine.bolt().note_text()).is_equal("Not quite. Let's look again.\nCheck the order of your digits.\nHere it is again. Look at these words.")


func test_misconception_of_finds_the_distractor_that_was_given() -> void:
	var problem: Problem = Problem.new()
	problem.answer = 34
	problem.distractors = [{"value": 43, "misconception": &"digit_swap"}, {"value": 35, "misconception": &"off_by_one"}]
	assert_str(MineScreen.misconception_of(problem, 43)).is_equal("digit_swap")
	assert_str(MineScreen.misconception_of(problem, 99)).is_empty()
	assert_str(MineScreen.misconception_of(problem, true)).is_empty() # a different kind of value is never a match


func test_rung_3_shows_a_solved_friend_of_the_problem() -> void:
	await _open(0)
	for miss: int in 3:
		_answer(false)
		await _wait_state(DigFlow.State.WOBBLE)
		await _wait_state(DigFlow.State.AWAIT_ANSWER)
	var card: PanelContainer = _mine.answer_panel().example_card()
	assert_object(card).is_not_null()
	var example: Dictionary = _mine.current_problem().hint_steps[2]["example"]
	var texts: Array[String] = []
	for label: Node in card.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_array(texts).contains([Text.get_line(StringName(example["prompt_line_id"]), example["prompt_params"]), Text.get_line(StringName(example["answer_line_id"]), example["answer_params"])])
	assert_str(_mine.bolt().note_text()).contains(Text.get_line(&"bolt.hint.worked_example"))


func test_rung_4_swaps_in_an_easier_problem_once_and_flags_the_skill() -> void:
	await _open(0)
	var first: Problem = _mine.current_problem()
	for miss: int in 4:
		_answer(false)
		await _wait_state(DigFlow.State.WOBBLE)
		await _wait_state(DigFlow.State.AWAIT_ANSWER)
	var easier: Problem = _mine.current_problem()
	assert_bool(easier == first).is_false()
	assert_str(easier.skill_id).is_equal(first.skill_id)
	assert_int(easier.params["difficulty"]).is_equal(-1)
	assert_bool(SaveSystem.data()["skills"]["pv.tens_ones.build"]["flagged_for_review"]).is_true()
	assert_str(_mine.bolt().spoken_text()).is_equal(Text.get_line(easier.prompt_line_id, easier.prompt_params))
	assert_str(_mine.bolt().note_text()).contains(Text.get_line(&"bolt.hint.easier"))
	_answer(false) # a fifth miss keeps the easier problem and its help
	await _wait_state(DigFlow.State.WOBBLE)
	await _wait_state(DigFlow.State.AWAIT_ANSWER)
	assert_bool(_mine.current_problem() == easier).is_true()
	_answer(true)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	assert_int(_mine.cart().coins_shown()).is_equal(DigFlow.COINS_AFTER_HINT) # still paid, never less


func test_a_cracked_rock_pays_the_zone_gem_into_the_save_and_lights_todays_lantern() -> void:
	await _solve(0)
	assert_int(SaveSystem.data()["rewards"]["coins"]).is_equal(DigFlow.COINS_FIRST_TRY)
	assert_int(SaveSystem.data()["rewards"]["gems"]["quartz"]).is_equal(1)
	assert_bool(Rewards.lit_today()).is_true()
	assert_bool(_mine.celebration().visible).is_true() # the first rock of the day lights the lantern
	assert_array(_mine.celebration().line_ids()).contains_exactly([&"bolt.celebrate.lantern"])
	_mine.celebration().continue_button().pressed.emit()
	assert_bool(_mine.celebration().visible).is_false()
	await _solve(1)
	assert_bool(_mine.celebration().visible).is_false() # once a day


func test_mastering_a_skill_is_celebrated_with_an_amethyst() -> void:
	Adaptive.skill_mastered.emit(&"pv.tens_ones.build", true)
	await _solve(0)
	assert_array(_mine.celebration().line_ids()).contains([&"bolt.celebrate.mastery"])
	assert_int(SaveSystem.data()["rewards"]["gems"]["amethyst"]).is_equal(1)


func test_after_the_soft_limit_the_wind_down_waits_for_the_rock_to_finish() -> void:
	var clock: FakeClock = FakeClock.new()
	Adaptive.use_clock(clock)
	Adaptive.start_session()
	await _open(0)
	clock.advance(21 * 60) # past the 20-minute default, mid-rock
	assert_bool(Adaptive.wind_down_due()).is_true()
	assert_bool(_mine.wind_down().visible).is_false() # never in the middle of a rock
	_answer(true)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	if _mine.celebration().visible:
		_mine.celebration().continue_button().pressed.emit() # today's lantern comes first
	assert_bool(_mine.wind_down().visible).is_true()
	var lines: Array[String] = _mine.wind_down().recap_lines()
	assert_array(lines).contains([Text.get_line(&"ui.recap.rocks", {"n": 1}), Text.get_line(&"ui.recap.coins", {"n": DigFlow.COINS_FIRST_TRY})])
	for line: String in lines:
		assert_bool(line.contains(":") and line.split(":")[1].strip_edges().is_valid_int()).is_true() # counts, never a clock
	var requested: Array[StringName] = []
	_mine.request_screen.connect(func(id: StringName, _args: Dictionary) -> void: requested.append(id))
	_mine.wind_down().head_up_button().pressed.emit()
	assert_array(requested).contains_exactly([&"hub"])
	assert_bool(Adaptive.has_session()).is_false()
	Adaptive.use_clock(GameClock.new())
