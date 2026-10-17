# Mirrors scripts/save/save_store.gd: atomic writes, crash recovery, the attempt log.
class_name SaveStoreTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("save_store_" + str(Time.get_ticks_usec()))


func _profile(coins: int) -> Dictionary:
	var profile: Dictionary = SaveSchema.new_profile("2026-11-20T15:04:05Z")
	profile["rewards"]["coins"] = coins
	return profile


func _store() -> SaveStore:
	return SaveStore.new(_dir)


func _write(coins: int, crash: StringName = &"") -> Error:
	var store: SaveStore = _store()
	store.crash_after = crash
	return store.write_profile(_profile(coins))


func _write_raw(file_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _coins_on_disk() -> int:
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).override_failure_message("no valid save on disk: " + str(read["error"])).is_true()
	return read["data"]["rewards"]["coins"]


# --- Basic round trips ----------------------------------------------------------------


func test_a_fresh_folder_reports_no_save() -> void:
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).is_false()
	assert_str(read["error"]).is_equal("none")


func test_write_then_read_round_trips_and_keeps_integers() -> void:
	assert_int(_write(42)).is_equal(OK)
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).is_true()
	assert_bool(read["recovered"]).is_false()
	assert_bool(read["data"]["rewards"]["coins"] is int).is_true()
	assert_int(read["data"]["rewards"]["coins"]).is_equal(42)
	assert_int(read["data"]["schema_version"]).is_equal(1)


func test_a_second_write_keeps_the_first_as_backup() -> void:
	_write(1)
	_write(2)
	assert_int(_coins_on_disk()).is_equal(2)
	var backup: Variant = JsonUtil.parse_file(_dir.path_join(SaveStore.BAK_FILE))
	assert_int(backup["rewards"]["coins"]).is_equal(1)


func test_a_successful_write_leaves_no_temp_file() -> void:
	_write(1)
	_write(2)
	assert_bool(FileAccess.file_exists(_dir.path_join(SaveStore.TMP_FILE))).is_false()


# --- Killing the app mid-write (P1-S03-06: "recovery passes") ------------------------


func test_killed_while_writing_the_temp_file_keeps_the_old_save() -> void:
	_write(10)
	assert_int(_write(20, SaveStore.CRASH_TMP_PARTIAL)).is_not_equal(OK)
	# The temp file is half a JSON document; it must never be mistaken for a save.
	assert_int(_coins_on_disk()).is_equal(10)
	assert_bool(_store().read_profile()["recovered"]).is_false()


func test_killed_after_the_temp_file_is_complete_keeps_the_old_save() -> void:
	_write(10)
	_write(20, SaveStore.CRASH_AFTER_TMP)
	assert_int(_coins_on_disk()).is_equal(10)


func test_killed_after_the_backup_copy_keeps_the_old_save() -> void:
	_write(10)
	_write(20, SaveStore.CRASH_AFTER_BAK)
	assert_int(_coins_on_disk()).is_equal(10)


func test_killed_between_remove_and_rename_recovers_the_new_save_from_temp() -> void:
	_write(10)
	_write(20, SaveStore.CRASH_MID_RENAME)
	assert_bool(FileAccess.file_exists(_dir.path_join(SaveStore.PROFILE_FILE))).is_false()
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).is_true()
	assert_int(read["data"]["rewards"]["coins"]).is_equal(20)
	assert_bool(read["recovered"]).is_true()
	assert_str(read["source"]).is_equal(SaveStore.SOURCE_TMP)


func test_a_normal_write_after_any_crash_heals_the_folder() -> void:
	for crash: StringName in [SaveStore.CRASH_TMP_PARTIAL, SaveStore.CRASH_AFTER_TMP, SaveStore.CRASH_AFTER_BAK, SaveStore.CRASH_MID_RENAME]:
		_write(10)
		_write(20, crash)
		assert_int(_write(30)).is_equal(OK)
		var read: Dictionary = _store().read_profile()
		assert_int(read["data"]["rewards"]["coins"]).override_failure_message("after " + crash).is_equal(30)
		assert_str(read["source"]).override_failure_message("after " + crash).is_equal(SaveStore.SOURCE_PROFILE)
		assert_bool(FileAccess.file_exists(_dir.path_join(SaveStore.TMP_FILE))).override_failure_message("tmp left after " + crash).is_false()


func test_a_crash_on_the_very_first_write_leaves_no_valid_save_but_does_not_throw() -> void:
	_write(10, SaveStore.CRASH_TMP_PARTIAL)
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).is_false()
	assert_str(read["error"]).is_equal("corrupt") # a half-written temp file exists, but is unusable


# --- Corruption and the backup -------------------------------------------------------


func test_a_corrupt_profile_falls_back_to_the_backup() -> void:
	_write(1)
	_write(2)
	_write_raw(SaveStore.PROFILE_FILE, "{ this is not json")
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).is_true()
	assert_bool(read["recovered"]).is_true()
	assert_str(read["source"]).is_equal(SaveStore.SOURCE_BACKUP)
	assert_int(read["data"]["rewards"]["coins"]).is_equal(1)


func test_an_empty_or_versionless_profile_counts_as_corrupt() -> void:
	_write(1)
	_write(2)
	_write_raw(SaveStore.PROFILE_FILE, "")
	assert_str(_store().read_profile()["source"]).is_equal(SaveStore.SOURCE_BACKUP)
	_write_raw(SaveStore.PROFILE_FILE, '{"rewards": {}}')
	assert_str(_store().read_profile()["source"]).is_equal(SaveStore.SOURCE_BACKUP)


func test_writing_never_copies_a_corrupt_profile_over_the_good_backup() -> void:
	_write(1)
	_write(2) # backup holds 1
	_write_raw(SaveStore.PROFILE_FILE, "garbage")
	assert_int(_write(3)).is_equal(OK)
	var backup: Variant = JsonUtil.parse_file(_dir.path_join(SaveStore.BAK_FILE))
	assert_int(backup["rewards"]["coins"]).is_equal(1) # still the last good save, not "garbage"
	assert_int(_coins_on_disk()).is_equal(3)


func test_when_every_file_is_corrupt_the_result_says_corrupt() -> void:
	_write_raw(SaveStore.PROFILE_FILE, "nope")
	_write_raw(SaveStore.BAK_FILE, "also nope")
	var read: Dictionary = _store().read_profile()
	assert_bool(read["ok"]).is_false()
	assert_str(read["error"]).is_equal("corrupt")


# --- Attempt log ----------------------------------------------------------------------


func test_attempts_append_and_read_back_in_order() -> void:
	var store: SaveStore = _store()
	for i: int in 3:
		assert_int(store.append_attempt({"n": i, "skill_id": "pv.tens_ones.build"})).is_equal(OK)
	var result: Dictionary = store.read_attempts()
	assert_int(result["skipped"]).is_equal(0)
	assert_array(result["entries"]).has_size(3)
	assert_int(result["entries"][2]["n"]).is_equal(2)
	assert_bool(result["entries"][0]["n"] is int).is_true()


func test_reading_attempts_with_no_log_is_empty() -> void:
	var result: Dictionary = _store().read_attempts()
	assert_array(result["entries"]).is_empty()
	assert_int(result["skipped"]).is_equal(0)


func test_a_half_written_last_line_is_skipped_and_the_next_append_starts_a_new_line() -> void:
	var store: SaveStore = _store()
	store.append_attempt({"n": 1})
	var file: FileAccess = FileAccess.open(_dir.path_join(SaveStore.ATTEMPTS_FILE), FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"n": 2, "skil') # the app died here
	file.close()
	var damaged: Dictionary = store.read_attempts()
	assert_array(damaged["entries"]).has_size(1)
	assert_int(damaged["skipped"]).is_equal(1)
	store.append_attempt({"n": 3})
	var healed: Dictionary = store.read_attempts()
	assert_array(healed["entries"]).has_size(2) # n=1 and n=3; the cut-off line is isolated
	assert_int(healed["entries"][1]["n"]).is_equal(3)
	assert_int(healed["skipped"]).is_equal(1)


func test_an_attempt_object_round_trips_through_the_log() -> void:
	var attempt: Attempt = Attempt.new()
	attempt.ts = "2026-12-03T21:10:00Z"
	attempt.session_id = "s1"
	attempt.skill_id = &"pv.tens_ones.build"
	attempt.problem_seed = 12345
	attempt.representation = &"concrete"
	attempt.answer_mode = &"drag"
	attempt.correct = true
	attempt.hints_used = 1
	attempt.latency_ms = 4200
	var store: SaveStore = _store()
	store.append_attempt(attempt.to_json())
	var back: Attempt = Attempt.from_json(store.read_attempts()["entries"][0])
	assert_str(back.ts).is_equal(attempt.ts)
	assert_str(String(back.skill_id)).is_equal("pv.tens_ones.build")
	assert_int(back.problem_seed).is_equal(12345)
	assert_bool(back.correct).is_true()
	assert_int(back.hints_used).is_equal(1)
	assert_int(back.latency_ms).is_equal(4200)
	assert_bool(back.low_confidence_rejected).is_false()


func test_attempt_json_has_exactly_the_documented_fields() -> void:
	var keys: Array = Attempt.new().to_json().keys()
	keys.sort()
	assert_array(keys).contains_exactly(["answer_mode", "correct", "hints_used", "latency_ms", "low_confidence_rejected", "problem_seed", "representation", "session_id", "skill_id", "ts"])
