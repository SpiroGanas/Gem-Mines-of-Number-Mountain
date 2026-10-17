# MVP hardening (P1-S11-01 and P1-S11-02): the things a real session goes through, end to end.
#   - a posture change in the middle of a rock (the 2-in-1 folding into tablet posture);
#   - the app closing mid-dig and starting again from the disk;
#   - an update installed over a save from an older build (the Sprint 3 fixture);
#   - a long dig across every MVP skill, through every hint rung, with no missing text.
# What still needs the devices (stylus, a real restart, airplane mode) is in docs/decisions.md.
class_name HardeningTest
extends GdUnitTestSuite

const SHELL_SCENE: String = "res://scenes/shell/shell.tscn"
const MINE_SCENE: String = "res://scenes/mine/mine.tscn"
const V1_FIXTURE: String = "res://tests/save/fixtures/v1.json"

var _shell: Shell
var _dir: String
var _missing: Array[StringName] = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("hardening_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))
	_missing.clear()
	Text.missing_line.connect(_on_missing_line)


func after_test() -> void:
	Text.missing_line.disconnect(_on_missing_line)
	DeviceSettings.use_shared(null)
	TestWindow.restore(get_window())
	get_tree().paused = false
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func _on_missing_line(id: StringName) -> void:
	_missing.append(id)


## A miner who has met Bolt and finished the placement quest, saved in the temp folder.
func _returning_miner() -> void:
	SaveSystem.use_directory(_dir)
	SaveSystem.data()["child"]["nickname"] = "Charlie"
	SaveSystem.data()["placement"]["done"] = true
	SaveSystem.save_now()


func _start_shell() -> void:
	_shell = load(SHELL_SCENE).instantiate()
	_shell.fade_seconds = 0.0
	add_child(_shell)
	auto_free(_shell)


func _until(condition: Callable, what: String, max_frames: int = 900) -> void:
	var frames: int = 0
	while not condition.call() and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	assert_bool(condition.call()).override_failure_message("timed out waiting for " + what).is_true()


func _open_mine() -> MineScreen:
	_shell.change_screen(&"mine")
	await _until(func() -> bool: return _shell.current_screen() is MineScreen, "the mine")
	return _shell.current_screen()


func _open_rock(mine: MineScreen, index: int) -> void:
	mine.wall().rock(index).pressed.emit()
	await _until(func() -> bool: return mine.flow.state == DigFlow.State.AWAIT_ANSWER, "rock %d to open" % index)


## Answers the rock in hand through its own widget, waits for the gem, and closes any celebration.
func _solve_open_rock(mine: MineScreen) -> void:
	var problem: Problem = mine.current_problem()
	assert_bool(PanelDriver.give(mine.answer_panel(), problem.answer)).override_failure_message("could not answer " + problem.skill_id).is_true()
	await _until(func() -> bool: return mine.flow.state == DigFlow.State.PICK_ROCK or mine.flow.state == DigFlow.State.WALL_CLEAR, "the gem to land")
	if mine.celebration().visible:
		mine.celebration().continue_button().pressed.emit()


# --- Posture -----------------------------------------------------------------------------


func test_a_posture_change_mid_rock_keeps_the_rock_and_saves() -> void:
	_returning_miner()
	_start_shell()
	var mine: MineScreen = await _open_mine()
	await _open_rock(mine, 0)
	var problem: Problem = mine.current_problem()
	var saves: Array[bool] = []
	var on_saved: Callable = func() -> void: saves.append(true)
	SaveSystem.saved.connect(on_saved)
	get_window().size = Vector2i(1440, 1080) # folded into tablet posture: 4:3
	await get_tree().process_frame
	await get_tree().process_frame
	get_window().size = TestWindow.DESIGN_SIZE # and back to laptop posture
	await get_tree().process_frame
	SaveSystem.saved.disconnect(on_saved)
	assert_bool(saves.is_empty()).override_failure_message("a posture change must save").is_false()
	assert_int(mine.flow.state).is_equal(DigFlow.State.AWAIT_ANSWER)
	assert_object(mine.current_problem()).is_same(problem) # the same rock, the same problem
	await _solve_open_rock(mine)
	assert_bool(mine.flow.is_cracked(0)).is_true()
	assert_array(_missing).is_empty()


func test_the_mine_fits_every_supported_aspect_ratio() -> void:
	_returning_miner()
	_start_shell()
	var mine: MineScreen = await _open_mine()
	await _open_rock(mine, 0)
	for window_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(1800, 1200), Vector2i(1440, 1080)]:
		get_window().size = window_size
		await get_tree().process_frame
		await get_tree().process_frame
		var visible_area: Rect2 = mine.get_viewport().get_visible_rect()
		for control: Control in [mine.answer_panel(), mine.bolt(), mine.wall()]:
			assert_bool(visible_area.grow(1.0).encloses(control.get_global_rect())).override_failure_message("%s leaves the screen at %s" % [control.name, window_size]).is_true()
	get_window().size = TestWindow.DESIGN_SIZE


# --- Closing and starting again ------------------------------------------------------------


func test_closing_mid_dig_and_starting_again_keeps_every_finished_rock() -> void:
	_returning_miner()
	_start_shell()
	var mine: MineScreen = await _open_mine()
	await _open_rock(mine, 0)
	var first_skill: StringName = mine.current_problem().skill_id
	await _solve_open_rock(mine)
	await _open_rock(mine, 1) # a second rock is in hand when the app closes
	var coins: int = Rewards.coins()
	SaveSystem.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_shell.queue_free()
	await get_tree().process_frame
	# A fresh start reads everything back from the disk.
	SaveSystem.use_directory(_dir)
	assert_int(Rewards.coins()).is_equal(coins)
	assert_int(coins).is_equal(DigFlow.COINS_FIRST_TRY)
	assert_bool(SaveSystem.data()["skills"].has(String(first_skill))).is_true()
	assert_array(SaveSystem.read_attempts()["entries"]).has_size(1)
	assert_bool(Rewards.lit_today()).is_true()
	_start_shell()
	assert_str(_shell.current_screen_id()).is_equal(&"title")
	mine = await _open_mine()
	await _open_rock(mine, 0)
	await _solve_open_rock(mine)
	assert_int(Rewards.coins()).is_equal(coins + DigFlow.COINS_FIRST_TRY)
	assert_array(_missing).is_empty()


func test_the_app_pausing_saves_mid_rock_without_losing_the_rock() -> void:
	_returning_miner()
	_start_shell()
	var mine: MineScreen = await _open_mine()
	await _open_rock(mine, 0)
	var problem: Problem = mine.current_problem()
	SaveSystem.data()["rewards"]["coins"] = 7 # something only the pause save can have written
	SaveSystem.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(SaveStore.new(_dir).read_profile()["data"]["rewards"]["coins"]).is_equal(7)
	SaveSystem.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await get_tree().process_frame
	assert_object(mine.current_problem()).is_same(problem)
	assert_int(mine.flow.state).is_equal(DigFlow.State.AWAIT_ANSWER)


# --- An update over an older save ------------------------------------------------------------


func test_an_update_over_a_sprint_3_save_keeps_everything_and_plays() -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V1_FIXTURE))
	file.close()
	SaveSystem.use_directory(_dir)
	assert_bool(SaveSystem.last_load_report["recovered"]).is_false()
	assert_int(Rewards.coins()).is_equal(120)
	assert_bool(Rewards.museum_open(&"quartz")).is_true()
	assert_str(Rewards.headlamp()).is_equal("blue")
	assert_array(Adaptive.mastered()).contains([&"count.to_120.read"])
	_start_shell()
	# Every screen opens on the old save.
	for screen_id: StringName in Shell.SCREEN_PATHS:
		_shell.change_screen(screen_id)
		await _until(func() -> bool: return _shell.current_screen_id() == screen_id, String(screen_id))
		await get_tree().process_frame
	assert_array(_missing).is_empty()
	var mine: MineScreen = await _open_mine()
	await _open_rock(mine, 0)
	await _solve_open_rock(mine)
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_array(SaveSchema.validate(on_disk)).is_empty()
	assert_int(on_disk["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_int(on_disk["rewards"]["coins"]).is_equal(120 + DigFlow.COINS_FIRST_TRY)
	assert_int(on_disk["rewards"]["gems"]["quartz"]).is_greater_equal(4)
	assert_array(on_disk["rewards"]["lantern"]["lit_days"]).contains(["2026-12-01", "2026-12-02", Adaptive.clock.today()])
	assert_str(on_disk["skills"]["count.to_120.read"]["mastered_at"]).is_equal("2026-12-01T20:00:00Z")
	assert_str(on_disk["child"]["nickname"]).is_equal("Charlie")


# --- The bug-bash dig ----------------------------------------------------------------------


## Digs whole walls of every MVP skill. Each rock takes `misses` not-quite answers first, so the
## dig climbs the hint ladder (highlight, picture, worked example, an easier problem) on the
## real mine with every kind of problem, and nothing ever goes missing or gets stuck.
func test_a_long_dig_through_every_skill_and_every_hint_rung() -> void:
	SaveSystem.use_directory(_dir)
	var skill_ids: Array[StringName] = []
	for zone: int in [1, 2, 3]:
		for skill: Skill in SkillCatalog.load_all().skills_in_zone(zone):
			skill_ids.append(skill.id)
	var skills_seen: Dictionary = {}
	var rungs_seen: Dictionary = {}
	for seed_value: int in range(1, 9):
		var mine: MineScreen = load(MINE_SCENE).instantiate()
		mine.animation_speed = 25.0
		mine.seed_value = seed_value
		mine.skill_ids = skill_ids
		add_child(mine)
		auto_free(mine)
		for index: int in mine.wall().rock_count():
			await _open_rock(mine, index)
			var misses: int = (seed_value + index) % 5
			for miss: int in misses:
				var problem: Problem = mine.current_problem()
				var before: int = mine.flow.wrong_count()
				assert_bool(PanelDriver.give(mine.answer_panel(), PanelDriver.wrong_value(problem))).override_failure_message("could not give a wrong answer to " + problem.skill_id).is_true()
				await _until(func() -> bool: return mine.flow.wrong_count() > before and mine.flow.state == DigFlow.State.AWAIT_ANSWER, "the next try on " + problem.skill_id)
				rungs_seen[HintLadder.next_rung(mine.flow.wrong_count())] = true
			skills_seen[mine.current_problem().skill_id] = true
			await _solve_open_rock(mine)
			assert_int(Rewards.coins()).is_greater(0)
		assert_int(mine.flow.state).is_equal(DigFlow.State.WALL_CLEAR)
		mine.queue_free()
		await get_tree().process_frame
	assert_array(_missing).is_empty()
	assert_array(rungs_seen.keys()).contains([HintLadder.Rung.REPEAT_HIGHLIGHT, HintLadder.Rung.VISUAL_MODEL, HintLadder.Rung.WORKED_EXAMPLE, HintLadder.Rung.EASIER_PROBLEM])
	assert_int(skills_seen.size()).is_greater(20)
