# Mirrors autoload/save_system.gd. Uses a fresh SaveSystem instance on a temp folder,
# never the global autoload, so the real save is untouched.
class_name SaveSystemTest
extends GdUnitTestSuite

const SYSTEM_SCRIPT: String = "res://autoload/save_system.gd"

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("save_system_" + str(Time.get_ticks_usec()))


func _system() -> Node:
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.use_directory(_dir)
	return system


func test_a_first_start_makes_a_new_profile_without_complaint() -> void:
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_not_emitted("load_failed")
	assert_int(system.data()["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_str(system.last_load_report["error"]).is_equal("none")


func test_save_now_writes_the_file_and_announces_it() -> void:
	var system: Node = _system()
	monitor_signals(system)
	system.data()["rewards"]["coins"] = 55
	system.save_now()
	await assert_signal(system).is_emitted("saved")
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_true()
	var reloaded: Node = _system()
	assert_int(reloaded.data()["rewards"]["coins"]).is_equal(55)


func test_saving_updates_the_updated_at_stamp() -> void:
	var system: Node = _system()
	system.data()["updated_at"] = "2000-01-01T00:00:00Z"
	system.save_now()
	assert_str(system.data()["updated_at"]).is_not_equal("2000-01-01T00:00:00Z")
	assert_str(system.data()["updated_at"]).ends_with("Z")


func test_loading_a_recovered_save_is_reported_for_the_parent_dashboard() -> void:
	var system: Node = _system()
	system.data()["rewards"]["coins"] = 1
	system.save_now()
	system.data()["rewards"]["coins"] = 2
	system.save_now()
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("corrupted!")
	file.close()
	var recovered: Node = _system()
	assert_bool(recovered.last_load_report["recovered"]).is_true()
	assert_str(recovered.last_load_report["source"]).is_equal("backup")
	assert_int(recovered.data()["rewards"]["coins"]).is_equal(1)


func test_when_nothing_is_readable_it_starts_fresh_and_says_why() -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("corrupted!")
	file.close()
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_emitted("load_failed", ["corrupt"])
	assert_int(system.data()["rewards"]["coins"]).is_equal(0)


func test_a_save_from_a_newer_build_is_kept_and_never_overwritten() -> void:
	var newer: Dictionary = SaveSchema.new_profile("t")
	newer["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	newer["rewards"]["coins"] = 999
	assert_int(SaveStore.new(_dir).write_profile(newer)).is_equal(OK)
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_emitted("load_failed", ["newer_version"])
	system.save_now() # must be refused
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_int(on_disk["rewards"]["coins"]).is_equal(999)
	assert_int(on_disk["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION + 1)


func test_the_v1_fixture_loads_through_the_whole_system() -> void:
	var fixture: String = FileAccess.get_file_as_string("res://tests/save/fixtures/v1.json")
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string(fixture)
	file.close()
	var system: Node = _system()
	assert_str(system.data()["child"]["nickname"]).is_equal("Charlie")
	assert_int(system.data()["rewards"]["coins"]).is_equal(120)
	assert_bool(system.last_load_report["recovered"]).is_false()
	assert_bool(system.last_load_report["migrated"]).is_true() # version 1 is migrated to version 2
	assert_int(system.last_load_report["from_version"]).is_equal(1)
	assert_int(system.data()["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_dict(system.data()["workshop"]["builds"]).is_empty()


func test_missing_keys_in_an_old_save_are_filled_with_defaults() -> void:
	var sparse: Dictionary = {"schema_version": 1, "settings": {"session_minutes": 30}}
	SaveStore.new(_dir).write_profile(sparse)
	var system: Node = _system()
	assert_int(system.data()["settings"]["session_minutes"]).is_equal(30)
	assert_array(SaveSchema.validate(system.data())).is_empty()


func test_attempts_are_logged_through_the_system() -> void:
	var system: Node = _system()
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = &"count.to_20.objects"
	attempt.correct = true
	system.append_attempt(attempt)
	system.append_attempt(attempt)
	assert_array(system.read_attempts()["entries"]).has_size(2)
	assert_str(system.read_attempts()["entries"][0]["skill_id"]).is_equal("count.to_20.objects")


func test_the_app_pausing_or_closing_saves() -> void:
	for notification: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		var dir: String = create_temp_dir("notify_" + str(notification))
		var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
		system.use_directory(dir)
		system.data()["rewards"]["coins"] = notification
		system._notification(notification)
		var on_disk: Dictionary = SaveStore.new(dir).read_profile()["data"]
		assert_int(on_disk["rewards"]["coins"]).override_failure_message("notification %d did not save" % notification).is_equal(notification)


func test_other_notifications_do_not_save() -> void:
	var system: Node = _system()
	system._notification(Node.NOTIFICATION_READY)
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_false()


# --- Export and import (P1-S09-05) ---------------------------------------------------------


func _attempt(skill: StringName, ts: String) -> Attempt:
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = skill
	attempt.ts = ts
	attempt.session_id = "s1"
	attempt.correct = true
	return attempt


func test_a_bundle_round_trips_between_two_devices() -> void:
	var tablet: Node = _system()
	tablet.data()["rewards"]["coins"] = 77
	tablet.data()["child"]["nickname"] = "Charlie"
	tablet.append_attempt(_attempt(&"count.to_20.objects", "2026-12-07T10:00:00Z"))
	var bundle_path: String = _dir.path_join("bundle.json")
	assert_int(tablet.export_bundle(bundle_path)).is_equal(OK)
	var chromebook_dir: String = create_temp_dir("chromebook_" + str(Time.get_ticks_usec()))
	var chromebook: Node = auto_free(load(SYSTEM_SCRIPT).new())
	chromebook.use_directory(chromebook_dir)
	chromebook.append_attempt(_attempt(&"cmp.to_20.more_less", "2026-12-06T09:00:00Z"))
	chromebook.data()["updated_at"] = "2026-01-01T00:00:00Z" # older than the tablet's
	assert_int(chromebook.import_bundle(bundle_path)).is_equal(OK)
	assert_bool(chromebook.last_import_report["replaced"]).is_true()
	assert_int(chromebook.data()["rewards"]["coins"]).is_equal(77)
	assert_str(chromebook.data()["child"]["nickname"]).is_equal("Charlie")
	var log_entries: Array = chromebook.read_attempts()["entries"]
	assert_int(log_entries.size()).is_equal(2) # both devices' answers, oldest first
	assert_str(log_entries[0]["skill_id"]).is_equal("cmp.to_20.more_less")
	# Importing the same bundle again adds nothing twice.
	chromebook.import_bundle(bundle_path)
	assert_int(chromebook.read_attempts()["entries"].size()).is_equal(2)


func test_an_older_bundle_never_replaces_newer_progress_but_its_answers_are_kept() -> void:
	var old_device: Node = _system()
	old_device.data()["rewards"]["coins"] = 5
	old_device.append_attempt(_attempt(&"count.to_20.objects", "2026-12-01T10:00:00Z"))
	var bundle_path: String = _dir.path_join("old.json")
	old_device.export_bundle(bundle_path)
	var other: Node = auto_free(load(SYSTEM_SCRIPT).new())
	other.use_directory(create_temp_dir("newer_" + str(Time.get_ticks_usec())))
	other.data()["rewards"]["coins"] = 99
	other.data()["updated_at"] = "2099-01-01T00:00:00Z"
	assert_int(other.import_bundle(bundle_path)).is_equal(OK)
	assert_bool(other.last_import_report["replaced"]).is_false()
	assert_int(other.data()["rewards"]["coins"]).is_equal(99)
	assert_int(other.read_attempts()["entries"].size()).is_equal(1)


func test_the_replaced_save_is_kept_as_the_backup() -> void:
	var source: Node = _system()
	source.data()["rewards"]["coins"] = 1
	var bundle_path: String = _dir.path_join("b.json")
	source.export_bundle(bundle_path)
	var target_dir: String = create_temp_dir("target_" + str(Time.get_ticks_usec()))
	var target: Node = auto_free(load(SYSTEM_SCRIPT).new())
	target.use_directory(target_dir)
	target.data()["rewards"]["coins"] = 42
	target.data()["updated_at"] = "2000-01-01T00:00:00Z"
	SaveStore.new(target_dir).write_profile(target.data())
	target.import_bundle(bundle_path)
	var backup: Dictionary = JsonUtil.parse_file(target_dir.path_join("profile.json.bak"))
	assert_int(backup["rewards"]["coins"]).is_equal(42)


func test_a_file_that_is_not_a_bundle_changes_nothing() -> void:
	var system: Node = _system()
	system.data()["rewards"]["coins"] = 3
	var path: String = _dir.path_join("nope.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"hello\": 1}")
	file.close()
	assert_int(system.import_bundle(path)).is_equal(ERR_INVALID_DATA)
	assert_str(system.last_import_report["error"]).is_equal(ProgressBundle.ERR_NOT_A_BUNDLE)
	assert_int(system.data()["rewards"]["coins"]).is_equal(3)


func test_a_bundle_from_a_newer_game_is_refused() -> void:
	var system: Node = _system()
	var bundle: Dictionary = ProgressBundle.make(SaveSchema.new_profile("t"), [], "t")
	bundle["profile"]["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	bundle["checksum"] = ProgressBundle.checksum_of(bundle) # a real export from that newer game
	var path: String = _dir.path_join("future.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bundle))
	file.close()
	assert_int(system.import_bundle(path)).is_equal(ERR_INVALID_DATA)
	assert_str(system.last_import_report["error"]).is_equal(SaveMigrator.ERR_NEWER_VERSION)


func test_importing_over_a_save_from_a_newer_build_is_refused() -> void:
	var newer: Dictionary = SaveSchema.new_profile("t")
	newer["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	newer["rewards"]["coins"] = 999
	assert_int(SaveStore.new(_dir).write_profile(newer)).is_equal(OK)
	var bundle: Dictionary = ProgressBundle.make(SaveSchema.new_profile("t"), [], "t")
	bundle["profile"]["updated_at"] = "2099-01-01T00:00:00Z" # newer by date, but from this (older) build
	bundle["checksum"] = ProgressBundle.checksum_of(bundle)
	var path: String = _dir.path_join("older_game.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bundle))
	file.close()
	var system: Node = _system()
	assert_str(system.last_load_report["error"]).is_equal(SaveMigrator.ERR_NEWER_VERSION)
	assert_int(system.import_bundle(path)).is_not_equal(OK)
	assert_bool(system.last_import_report["ok"]).is_false()
	assert_str(system.last_import_report["error"]).is_equal(SaveMigrator.ERR_NEWER_VERSION)
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_int(on_disk["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION + 1)
	assert_int(on_disk["rewards"]["coins"]).is_equal(999)
	assert_bool(FileAccess.file_exists(_dir.path_join("attempts.jsonl"))).is_false() # nothing merged either
